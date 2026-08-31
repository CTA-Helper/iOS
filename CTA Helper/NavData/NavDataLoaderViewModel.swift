import Foundation
import Observation
import Sentry
import SwiftData
import os

/**
 Coordinates nav data loading and the loading UI's state.

 On launch it reads what the store holds. With no airports, or with a cycle that has expired over
 them, the app shows the loading screen, whose ``load(force:)`` downloads and imports the
 published cycle. A pilot who already has usable data can defer that update with ``loadLater()``
 and fly the stored cycle for the rest of the launch. Nothing else touches the network.
 */
@Observable
@MainActor
final class NavDataLoaderViewModel {
  /// How often the loader's state is read while a load is running, to drive the loading UI.
  private static let statePollInterval = Duration.milliseconds(200)

  private static let logger = Logger(
    subsystem: "codes.tim.CTA-Helper",
    category: "NavDataLoaderViewModel"
  )

  private(set) var state: NavDataLoader.State = .idle
  private(set) var hasData = false
  private(set) var cycleHasExpired = false
  var error: (any Error)?

  private let container: ModelContainer
  private let importContainer: ModelContainer
  private var isLoading = false
  /**
   Whether the expired cycle's update has been settled for this launch — the pilot deferred it,
   or the download it was offering has already been made.
   */
  private var updateSettled = false

  /**
   Whether the blocking loading screen should be shown: the store is empty, or the cycle standing
   over it has expired and the pilot has not deferred the update.
   */
  var showLoader: Bool { (!hasData || cycleHasExpired) && !updateSettled }

  /// Whether the pilot may defer an update, which they may only when a usable cycle is imported.
  var canSkip: Bool { hasData }

  init(container: ModelContainer) {
    self.container = container
    importContainer = Self.makeImportContainer(matching: container)
  }

  /**
   A standalone container over the same store, for the importer to write through.

   The import's bulk transactions then queue on their own persistent store coordinator, so
   main-context work — `@Query` fetches, model faults — never waits behind them. Under WAL
   journaling a reader on another coordinator is not blocked by an in-flight write.
   */
  private static func makeImportContainer(matching container: ModelContainer) -> ModelContainer {
    // An in-memory store, which is what UI tests and previews open, cannot be shared between
    // containers: a second one over the same configuration would be a second, empty store.
    guard !container.configurations.contains(where: \.isStoredInMemoryOnly) else {
      return container
    }

    do {
      return try ModelContainer(
        for: container.schema,
        configurations: Array(container.configurations)
      )
    } catch {
      // Importing through the live container is slower under load, not wrong; a failure to open
      // a second one is no reason to refuse to update the nav data at all.
      logger.warning("Falling back to the live container for imports: \(error)")
      return container
    }
  }

  #if DEBUG
    /**
     Builds an instance pinned to a given `state`, `error` and store contents, for SwiftUI
     previews that need a stage other than the initial `.idle` first-run prompt.
     */
    static func previewing(
      state: NavDataLoader.State,
      error: (any Error)? = nil,
      hasData: Bool = false
    ) -> NavDataLoaderViewModel {
      let viewModel = NavDataLoaderViewModel(container: .preview)
      viewModel.state = state
      viewModel.error = error
      viewModel.hasData = hasData
      return viewModel
    }
  #endif

  /**
   Resolve what the store holds. When it is empty, or the cycle over it has expired, the loading
   screen shows the consent prompt and the pilot starts the download with ``load(force:)``.
   */
  func start() async {
    await refreshState()
  }

  /**
   Dismiss the update prompt for the rest of this launch, leaving the imported cycle in place.

   Deferring is deliberately not persisted: a pilot who puts off an expired cycle is asked again
   the next time they open the app, rather than never.
   */
  func loadLater() {
    if canSkip { updateSettled = true }
  }

  /**
   Download and import the newest cycle, replacing what is stored.

   - Parameter force: re-import even when the stored cycle already matches the manifest.
   */
  func load(force: Bool = false) {
    guard !isLoading else { return }
    isLoading = true
    error = nil

    let loader = NavDataLoader(modelContainer: importContainer)
    Task {
      let outcome = await importCycle(with: loader, force: force)
      await publish(outcome)
      isLoading = false
    }
  }

  /**
   Run the load, mirroring the loader's stages onto ``state`` while it runs, and report how it
   ended.

   The mirroring task is cancelled *and joined* before this returns, so the stage it is midway
   through reading can never land after the outcome does — which would leave the loading screen
   showing a stage of a load that has already failed.
   */
  private func importCycle(with loader: NavDataLoader, force: Bool) async -> LoadOutcome {
    await withTaskGroup(of: Void.self, returning: LoadOutcome.self) { group in
      group.addTask { await self.pollState(of: loader) }
      let outcome = await outcome(of: loader, force: force)
      group.cancelAll()
      await group.waitForAll()
      return outcome
    }
  }

  /// How one download and import ended, having published nothing.
  private func outcome(of loader: NavDataLoader, force: Bool) async -> LoadOutcome {
    do {
      try await loader.load(force: force)
      return .finished(await loader.state)
    } catch is CancellationError {
      return .cancelled
    } catch {
      return .failed(error)
    }
  }

  /// Show how the load ended. A cancelled load shows nothing: another load has taken over.
  private func publish(_ outcome: LoadOutcome) async {
    switch outcome {
      case .finished(let loaderState):
        state = loaderState
        await refreshState()
        // A cycle still out of date once imported is the newest one published, so there is
        // nothing further to offer: prompting again would ask the pilot to repeat the download
        // they have just finished.
        if cycleHasExpired { updateSettled = true }
      case .failed(let error):
        // Log the whole error, including any wrapped `underlying`, which the pilot-facing
        // message deliberately leaves out.
        Self.logger.error("Nav data load failed: \(error)")
        report(error)
        self.error = error
        state = .idle
        // An import that failed partway through has emptied the store, so read it again: the
        // prompt the pilot lands back on has to be the one their store actually calls for.
        await refreshState()
      case .cancelled:
        break
    }
  }

  /**
   Send a load failure to crash reporting, under one fingerprint so every nav data failure
   groups into a single issue rather than one per underlying cause.

   A failure the pilot's own environment caused — a full disk, most obviously — is not a defect
   and is filtered out here, so it does not bury the failures that are.
   */
  private func report(_ error: any Error) {
    guard (error as? NavDataError)?.isReportable ?? true else { return }

    SentrySDK.capture(error: error) { scope in
      scope.setFingerprint(["navData", "load"])
    }
  }

  /**
   Mirror the loader's state onto the view model for as long as the load runs, so the loading
   screen follows the stages the loader passes through.
   */
  private func pollState(of loader: NavDataLoader) async {
    while !Task.isCancelled {
      state = await loader.state
      try? await Task.sleep(for: Self.statePollInterval)
    }
  }

  private func refreshState() async {
    let stored = await storedState()
    hasData = stored.hasData
    cycleHasExpired = stored.cycleHasExpired
  }

  /// What the store holds, read on a context of its own so launch does no main-actor fetching.
  @concurrent
  private func storedState() async -> StoredState {
    let context = ModelContext(container)
    var cycleDescriptor = FetchDescriptor<NavDataCycle>()
    cycleDescriptor.fetchLimit = 1
    let cycle = (try? context.fetch(cycleDescriptor))?.first
    let airportCount = (try? context.fetchCount(FetchDescriptor<Airport>())) ?? 0

    return StoredState(
      hasData: airportCount > 0,
      // Airports with no cycle standing over them are a half-written import, which is exactly
      // when the published cycle should be fetched again.
      cycleHasExpired: cycle?.hasExpired ?? true
    )
  }

  /// What the store holds, resolved away from the main actor and applied on it.
  private struct StoredState {
    let hasData: Bool
    let cycleHasExpired: Bool
  }

  /// How a load ended, held until the stage mirroring has stopped and it can be published.
  private enum LoadOutcome {
    case finished(NavDataLoader.State)
    case failed(any Error)
    case cancelled
  }
}
