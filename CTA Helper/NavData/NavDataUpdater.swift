import Foundation
import NavDataSchema
import Observation
import Sentry
import SwiftData
import os

/**
 Downloads the current nav data cycle and switches the app to it, one update at a time.

 Three paths start an update: the pilot, from the loading screen or from Settings, and the
 system, in a background processing task once the installed cycle has lapsed. All of them run the
 same work — a store built ahead of time where one is published, the JSON import where it is not
 — and they must never run it twice at once, since each reserves and installs a generation of the
 store. A caller that arrives while an update is running joins it instead of starting a second,
 so a pilot who opens the app partway through a background update watches that update finish.

 Every update writes a generation nothing is reading and switches to it only once it is whole, so
 one that fails or is stopped costs a file the next launch reclaims, and nothing else.
 */
@MainActor
@Observable
final class NavDataUpdater {
  /// The one updater, shared by every path that starts an update.
  static let shared = NavDataUpdater()

  private static let logger = Logger(subsystem: "codes.tim.CTA-Helper", category: "NavDataUpdater")

  /// The progress of the update in flight, or where the last one left off.
  private(set) var state: NavDataLoader.State = .idle

  /**
   The plate cache to clear of superseded cycles once an install commits, or `nil` to leave it
   alone.
   */
  @ObservationIgnored var chartStore: ChartStore?

  @ObservationIgnored private var inFlight: Task<Outcome, any Error>?

  private var layout: StoreLayout { NavDataStore.layout }
  private var installer: NavDataStoreInstaller { .init(layout: layout) }

  private init() {}

  /**
   Builds the importer's loader away from the main actor.

   Opening the importer's container brings up a persistent store coordinator of its own, which
   touches the filesystem, so it runs on the concurrent pool rather than on the main thread. Its
   bulk transactions then queue on that coordinator, never in front of the reads the views make.
   */
  @concurrent
  nonisolated private static func makeImportLoader(
    layout: StoreLayout,
    generation: Int,
    networkAccess: NavDataNetworkAccess
  ) async throws -> NavDataLoader {
    NavDataLoader(
      modelContainer: try NavDataStore.makeWritableContainer(
        layout: layout,
        generation: generation
      ),
      networkAccess: networkAccess
    )
  }

  /**
   The release the active generation was built from, or `nil` when there is none worth keeping.

   Read from the active generation on disk rather than from the container the views hold, which
   can still be reading a generation an earlier update replaced. A generation installed under an
   older schema version counts as none, so a build that raises the version replaces it even when
   the cycle has not changed.
   */
  @concurrent
  nonisolated private static func installedRelease(layout: StoreLayout) async -> InstalledRelease? {
    let defaults = UserDefaults.standard
    guard defaults.navDataSchemaVersion == NavDataSchema.version,
      let container = try? NavDataStore.makeContainerForExistingGeneration(
        layout: layout,
        generation: defaults.activeNavDataGeneration
      ),
      let cycle = try? ModelContext(container).fetch(FetchDescriptor<NavDataCycle>()).first
    else { return nil }

    return InstalledRelease(
      cycle: NavDataStoreManifest.cycleName(effective: cycle.effectiveDate),
      sha256: cycle.sha256
    )
  }

  /**
   The whole of what an error says.

   `localizedDescription` renders only a `LocalizedError`'s category, which is the same sentence
   for every case in it; the specifics are its reason.
   */
  private static func wholeOf(_ error: any Error) -> String {
    [error.localizedDescription, (error as? any LocalizedError)?.failureReason]
      .compactMap(\.self)
      .joined(separator: " ")
  }

  /**
   Sends an import failure to crash reporting, under one fingerprint so every nav data failure
   groups into a single issue rather than one per underlying cause.

   A failure the pilot's own environment caused — a full disk, most obviously — is not a defect
   and is filtered out here, so it does not bury the failures that are.
   */
  private static func report(_ error: any Error) {
    guard (error as? NavDataError)?.isReportable ?? true else { return }
    SentrySDK.capture(error: error) { scope in
      scope.setFingerprint(["navData", "load"])
    }
  }

  /**
   Runs an update, or waits for the one already running to finish.

   A caller that joins a running update does not choose its network policy: the update keeps the
   one it started with.

   - Parameter networkAccess: The networks the update's downloads may use.
   - Returns: Whether a new cycle was installed, or the one installed was already the newest.
   - Throws: `CancellationError` when the update was stopped before it finished, and otherwise
     whatever stopped the import. A store built ahead of time that cannot be installed is not an
     error: the import runs in its place.
   */
  @discardableResult
  func update(networkAccess: NavDataNetworkAccess) async throws -> Outcome {
    if let inFlight { return try await inFlight.value }

    let update = Task { try await perform(networkAccess: networkAccess) }
    inFlight = update
    defer { inFlight = nil }
    return try await withTaskCancellationHandler {
      try await update.value
    } onCancel: {
      update.cancel()
    }
  }

  /// Stops the update in flight, if there is one.
  func cancel() {
    inFlight?.cancel()
  }

  private func perform(networkAccess: NavDataNetworkAccess) async throws -> Outcome {
    state = .downloading(progress: nil)
    let installed = await Self.installedRelease(layout: layout)
    let generation = installer.reserveGeneration()

    do {
      // A store built ahead of time turns minutes of writing the database into a download. It is
      // an optimization, not a dependency: anything that goes wrong falls back to importing the
      // JSON release, which is still published and still works.
      if let outcome = await installPrebuiltStore(
        generation: generation,
        replacing: installed,
        networkAccess: networkAccess
      ) {
        return outcome
      }

      // The prebuilt path reports a cancellation the same way it reports a cycle that was never
      // published, so ask directly.
      try Task.checkCancellation()

      return try await importRelease(
        generation: generation,
        replacing: installed,
        networkAccess: networkAccess
      )
    } catch {
      state = .idle
      throw error
    }
  }

  /**
   Downloads and installs a store that was built ahead of time.

   - Returns: How the update ended, or `nil` when no prebuilt store could be installed and the
     import should run instead.
   */
  private func installPrebuiltStore(
    generation: Int,
    replacing installed: InstalledRelease?,
    networkAccess: NavDataNetworkAccess
  ) async -> Outcome? {
    let (updates, continuation) = AsyncStream<NavDataLoader.State>.makeStream(
      of: NavDataLoader.State.self,
      bufferingPolicy: .bufferingNewest(1)
    )
    let mirror = Task { [weak self] in
      for await update in updates {
        if Task.isCancelled { break }
        self?.state = update
      }
    }
    defer { mirror.cancel() }

    do {
      let store = PrebuiltNavDataStore(
        baseURL: await PrebuiltNavDataStore.baseURL,
        networkAccess: networkAccess
      )
      let cycle = try await store.newestInstallableCycle()
      if cycle.manifest.cycle == installed?.cycle {
        continuation.finish()
        state = .finished
        Self.logger.notice("Cycle \(cycle.manifest.cycle, privacy: .public) is already installed")
        return .alreadyCurrent
      }

      try await store.download(
        cycle,
        to: layout.navStoreURL(generation: generation),
        reportingTo: continuation
      )
      continuation.finish()
      try await install(generation: generation)
      state = .finished
      Self.logger.notice(
        "Installed the prebuilt store for cycle \(cycle.manifest.cycle, privacy: .public)"
      )
      return .installed
    } catch {
      continuation.finish()
      // What happens next is the caller's to decide: a cancelled update imports nothing.
      Self.logger.notice("Passed over the prebuilt store: \(Self.wholeOf(error), privacy: .public)")
      StoreLayout.removeStore(at: layout.navStoreURL(generation: generation))
      return nil
    }
  }

  /// Downloads the JSON release and writes it into `generation`, then installs it.
  private func importRelease(
    generation: Int,
    replacing installed: InstalledRelease?,
    networkAccess: NavDataNetworkAccess
  ) async throws -> Outcome {
    do {
      let manifest = try await NavDataLoader.fetchManifest(networkAccess: networkAccess)
      if manifest.data.sha256 == installed?.sha256 {
        state = .finished
        Self.logger.notice("Release \(manifest.airacCycle, privacy: .public) is already installed")
        return .alreadyCurrent
      }

      let loader = try await Self.makeImportLoader(
        layout: layout,
        generation: generation,
        networkAccess: networkAccess
      )
      let progress = await mirrorProgress(of: loader)
      defer { progress.cancel() }

      try await loader.load(manifest)
      try await install(generation: generation)
      state = .finished
      return .installed
    } catch {
      // A transfer the system stopped fails the same way a broken one does, and so does one this
      // update's network policy refused. Neither the pilot nor crash reporting needs to hear
      // about either.
      if Task.isCancelled || error.isCancellation { throw CancellationError() }
      if NavDataNetworkAccess.isRefusal(error) { throw error }

      // Log the whole error, including any wrapped `underlying`, which the pilot-facing message
      // deliberately leaves out.
      Self.logger.error("Nav data import failed: \(error)")
      Self.report(error)
      throw error
    }
  }

  /**
   Mirrors the loader's pushed state onto the main actor.

   The loader yields into an `AsyncStream`, so following its progress never waits on the loader's
   executor, nor on the writer's behind it.
   */
  private func mirrorProgress(of loader: NavDataLoader) async -> Task<Void, Never> {
    let updates = await loader.stateUpdates()
    return Task { [weak self] in
      for await loaderState in updates {
        if Task.isCancelled { break }

        // The loader hasn't begun; don't regress the update to idle.
        if case .idle = loaderState { continue }
        self?.state = loaderState
      }
    }
  }

  /// How an update ended.
  enum Outcome: Sendable {
    /// A new cycle was installed.
    case installed
    /// The newest published cycle was the one already installed, so nothing was downloaded.
    case alreadyCurrent
  }

  /// What the active generation was built from, for telling whether a published one is newer.
  private struct InstalledRelease {
    /// The cycle's published name, its effective date as `YYYY-MM-DD`.
    let cycle: String
    /// The SHA-256 of the JSON release the store was written from.
    let sha256: String
  }
}

// MARK: - Installing a generation

extension NavDataUpdater {
  /// The lists of airports the pilot has chosen, each keyed by site number.
  private static let airportListKeys = [
    SettingsKey.favoriteAirports,
    SettingsKey.recentAirports,
    SettingsKey.chartAirports
  ]

  /**
   Forgets the airports in the pilot's lists that the incoming dataset no longer carries.

   The FAA retires airports between cycles, and occasionally corrects the site number that
   identifies one, so a list made under an earlier dataset can name a record the new one does not
   hold. Left in place it resolves to nothing — a favorite that never appears, a Shortcuts
   suggestion that opens nothing.

   Internal so a test can run the check against a generation on disk without downloading one.

   - Parameters:
     - generation: The generation being installed.
     - layout: Where the stores live.
     - defaults: Where the lists are kept.
   */
  static func pruneAirportLists(
    missingFromGeneration generation: Int,
    layout: StoreLayout,
    defaults: UserDefaults = .standard
  ) {
    guard let context = context(forGeneration: generation, layout: layout) else { return }
    for key in airportListKeys {
      let list = defaults.airportIDList(forKey: key)
      guard !list.ids.isEmpty, let carried = carriedSiteNumbers(of: list, in: context) else {
        continue
      }

      let kept = list.ids.filter(carried.contains)
      guard kept != list.ids else { continue }
      defaults.set(AirportIDList(kept), forKey: key)
      logger.notice(
        "Dropped \(list.ids.count - kept.count) airports absent from the new dataset from \(key, privacy: .public)"
      )
    }
  }

  /**
   Which of a list's site numbers the dataset carries. A failed fetch reads as `nil`, so nothing
   is dropped on the strength of an error.
   */
  private static func carriedSiteNumbers(
    of list: AirportIDList,
    in context: ModelContext
  ) -> Set<String>? {
    let ids = list.ids
    let descriptor = FetchDescriptor<Airport>(predicate: #Predicate { ids.contains($0.siteNumber) })
    return (try? context.fetch(descriptor)).map { Set($0.map(\.siteNumber)) }
  }

  /// The AIRAC cycle a generation holds, or `nil` when it cannot be read.
  private static func airacCycle(ofGeneration generation: Int, layout: StoreLayout) -> String? {
    guard let context = context(forGeneration: generation, layout: layout) else { return nil }
    return (try? context.fetch(FetchDescriptor<NavDataCycle>()))?.first?.airacCycle
  }

  /**
   A context on a generation, or `nil` when that generation cannot be read.

   The container the views hold still reads the previous generation here, so this opens the new
   one itself — and opens it as a generation that must already be on disk, since one bootstrapped
   empty in its place would answer that it carries no airports and cost the pilot every list.
   */
  private static func context(forGeneration generation: Int, layout: StoreLayout) -> ModelContext? {
    do {
      return ModelContext(
        try NavDataStore.makeContainerForExistingGeneration(layout: layout, generation: generation)
      )
    } catch {
      logger.error(
        """
        Couldn’t read generation \(generation, privacy: .public): \
        \(wholeOf(error), privacy: .public)
        """
      )
      return nil
    }
  }

  /**
   Switches to the generation just written, then brings what the pilot keeps outside the store
   into line with it.

   The switch is a single recorded number, made only after the new store has been opened and
   found to hold airports. Until that point the dataset in use has not been touched, so a failure
   here — or a process killed mid-update — costs the pilot nothing. The app watches the active
   generation and reopens its own store; doing it here as well would race that.
   */
  private func install(generation: Int) async throws {
    try installer.install(generation: generation)
    Self.pruneAirportLists(missingFromGeneration: generation, layout: layout)

    // Only once the new cycle is installed. An update that failed partway leaves the old plates
    // standing, which the next successful one clears — the safe direction to fail in.
    if let cycle = Self.airacCycle(ofGeneration: generation, layout: layout) {
      await chartStore?.removeCharts(outside: cycle)
    }
  }
}
