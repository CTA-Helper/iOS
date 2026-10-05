import BackgroundTasks
import Foundation
import Observation
import Sentry
import SwiftData

/**
 Decides when the loading screen stands between the pilot and their data, and starts or follows
 an update through ``NavDataUpdater``.

 The screen shows while the store is empty, or while what it holds is out of date — a cycle not
 in force, or a schema this build has moved past — and the pilot has not deferred the update. A
 pilot who already has usable data can defer with ``loadLater()`` and fly the stored cycle for
 the rest of the launch.
 */
@Observable
@MainActor
final class NavDataLoaderViewModel {
  /// The scale the update's 0…1 progress is reported to the system on.
  private static let progressUnits: Int64 = 100

  /// How often the store is read again while the loading screen is up.
  private static let refreshInterval = Duration.milliseconds(500)

  var error: (any Error)?

  private(set) var noData = false
  private(set) var needsLoad = true
  private(set) var canSkip = false
  private(set) var deferred = false

  /// The store the app reads, replaced when an update installs a new generation.
  var container: ModelContainer

  /// The load the pilot started, from the tap until it settles.
  private var loadTask: Task<Void, Never>?

  /**
   The progress of the update, as the loading screen shows it.

   A load the pilot has just asked for reads as downloading from the tap, before the system has
   let the work begin; an update the system started in the background reads as whatever it is
   doing, so a pilot who opens the app partway through one watches it finish. An update that
   finished with the screen still up left the data out of date, so outside a load of the
   pilot's own it reads as idle, and the screen offers the choice again.
   */
  var state: NavDataLoader.State {
    switch (loadTask, NavDataUpdater.shared.state) {
      case (.some, .idle): .downloading(progress: nil)
      case (nil, .finished): .idle
      case (_, let state): state
    }
  }

  /// Whether the loading screen should be shown.
  var showLoader: Bool { (noData || needsLoad) && !deferred }

  /**
   Whether a load may start: not while one is already under way, from this screen or from the
   background.
   */
  private var canStartLoad: Bool {
    guard loadTask == nil else { return false }
    switch state {
      case .idle, .finished: return true
      default: return false
    }
  }

  /// - Parameter container: The store the app reads.
  init(container: ModelContainer) {
    self.container = container
  }

  /// What a store holds, read on a context of its own so the main actor does no fetching.
  @concurrent
  nonisolated private static func storedState(of container: ModelContainer) async throws
    -> NavDataState
  {
    try NavDataState.fetch(context: ModelContext(container))
  }

  #if DEBUG
    /**
     Builds an instance pinned to a given `error` and store state, for SwiftUI previews of the
     consent prompt.
     */
    static func previewing(
      error: (any Error)? = nil,
      noData: Bool = true,
      canSkip: Bool = false
    ) -> NavDataLoaderViewModel {
      let viewModel = NavDataLoaderViewModel(container: .preview)
      viewModel.error = error
      viewModel.noData = noData
      viewModel.canSkip = canSkip
      return viewModel
    }
  #endif

  /**
   Reads what the store holds, then keeps reading it for as long as the loading screen is up.

   Once the data is present and current the screen is dismissed and the reads stop, so they never
   contend with the views' own store access for the life of the app.
   */
  func start() async {
    while !Task.isCancelled {
      await refreshState()
      guard showLoader else { return }
      try? await Task.sleep(for: Self.refreshInterval)
    }
  }

  /**
   Dismiss the update prompt for the rest of this launch, leaving the stored cycle in place.

   Deferring is deliberately not persisted: a pilot who puts off an expired cycle is asked again
   the next time they open the app, rather than never.
   */
  func loadLater() {
    if canSkip { deferred = true }
  }

  /// Download and install the newest published cycle.
  func load() {
    guard canStartLoad else { return }
    loadTask = Task { [weak self] in
      await self?.runLoad()
      self?.loadTask = nil
    }
  }

  /**
   Download and install the newest published cycle, reporting how it went rather than presenting
   it — for Settings, which says so in place.

   - Returns: Whether a new cycle was installed, or the one installed was already the newest.
   - Throws: Whatever stopped the update, `CancellationError` included.
   */
  func checkForUpdate() async throws -> NavDataUpdater.Outcome {
    try await updateInBackgroundTask()
  }

  private func runLoad() async {
    error = nil
    do {
      try await updateInBackgroundTask()
      // A cycle still out of date once the update has finished is the newest one published, so
      // there is nothing further to offer: prompting again would ask the pilot to repeat the
      // download they have just made.
      deferred = true
    } catch is CancellationError {
      // A load the system stopped finished nothing, and there is nothing to tell the pilot: the
      // dataset in use is the one they already had.
    } catch {
      self.error = error
    }
    await refreshState()
  }

  /**
   Runs an update the pilot asked for, under a continued-processing task where the system grants
   one so it survives the pilot leaving the app.

   Safe because an update writes a generation nothing reads: a task the system cancels costs a
   file, not a database.
   */
  @discardableResult
  private func updateInBackgroundTask() async throws -> NavDataUpdater.Outcome {
    let backgroundTask = await NavDataDownloadTask.shared.begin(
      title: String(localized: "Updating Navigation Data"),
      subtitle: String(localized: "Downloading")
    )
    backgroundTask?.expirationHandler = {
      MainActor.assumeIsolated { NavDataUpdater.shared.cancel() }
    }
    let reporting = backgroundTask.map(reportProgress(to:))
    defer { reporting?.cancel() }

    do {
      let outcome = try await NavDataUpdater.shared.update(networkAccess: .any)
      report(.finished, to: backgroundTask)
      backgroundTask?.setTaskCompleted(success: true)
      return outcome
    } catch {
      backgroundTask?.setTaskCompleted(success: false)
      throw error
    }
  }

  /**
   Follows the update's phase and progress onto the system's own display of the work, for as long
   as it runs.
   */
  private func reportProgress(to backgroundTask: BGContinuedProcessingTask) -> Task<Void, Never> {
    backgroundTask.progress.totalUnitCount = Self.progressUnits
    return Task { [weak self] in
      for await state in Observations({ NavDataUpdater.shared.state }) {
        if Task.isCancelled { break }
        self?.report(state, to: backgroundTask)
      }
    }
  }

  /**
   Mirrors the update's phase and progress onto the system's own display of the work.

   A continued-processing task must report progress: one the system reads as stalled is expired
   to reclaim its resources.
   */
  private func report(_ state: NavDataLoader.State, to backgroundTask: BGContinuedProcessingTask?) {
    guard let backgroundTask else { return }

    let (subtitle, fraction): (String, Float?) =
      switch state {
        case .idle: (String(localized: "Starting"), 0)
        case .downloading(let progress): (String(localized: "Downloading"), progress)
        case .decompressing(let progress): (String(localized: "Decompressing"), progress)
        case .processing(let progress): (String(localized: "Processing"), progress)
        case .finished: (String(localized: "Finished"), 1)
      }

    backgroundTask.updateTitle(String(localized: "Updating Navigation Data"), subtitle: subtitle)
    guard let fraction else { return }
    backgroundTask.progress.completedUnitCount = Int64(fraction * Float(Self.progressUnits))
  }

  /// Reads what the store holds, and applies it.
  private func refreshState() async {
    do {
      apply(try await Self.storedState(of: container))
    } catch {
      SentrySDK.capture(error: error) { scope in
        scope.setFingerprint(["navData", "state"])
      }
      self.error = error
    }
  }

  private func apply(_ state: NavDataState) {
    if noData != state.noData { noData = state.noData }
    if needsLoad != state.needsLoad { needsLoad = state.needsLoad }
    if canSkip != state.canSkip { canSkip = state.canSkip }
  }

  isolated deinit {
    loadTask?.cancel()
  }
}
