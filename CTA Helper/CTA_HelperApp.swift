import NavDataSchema
import Sentry
import SwiftData
import SwiftUI
import os

@main
struct CTA_HelperApp: App {
  private static let logger = Logger(subsystem: "codes.tim.CTA-Helper", category: "Store")

  #if DEBUG
    /**
     The weather a UI test is served, keyed by station ID.

     The reading sits above KMSO's −11 °C restriction, so the airport list draws the badge in the
     state that says a station is reporting and no correction is called for — the state the
     marketing screenshots show. The fix list auto-fills its reported temperature from this, so
     it is what the seeded approach is corrected at.
     */
    private static let uiTestObservations = [
      "KMSO": METARObservation(
        stationID: "KMSO",
        temperature: .celsius(-5),
        date: Date(timeIntervalSince1970: 1_700_000_000),
        rawText: "METAR KMSO 141953Z 28008KT 10SM FEW070 SCT090 M05/M12 A2996 RMK AO2"
      )
    ]
  #endif

  /// The weather source: the live one, or under UI tests a loader serving a fixed observation.
  let metarLoader: METARLoader?
  /**
   The location source a UI test asked for, or `nil` to leave the device's own in place.

   Only a test ever names one. Left `nil`, the environment resolves its own default the first
   time a view reads it — which is when the pilot opens the Nearest tab, so nothing asks Core
   Location for anything on behalf of a screen they may never open.
   */
  let locationStreamer: FixedLocationStreamer?
  /// The approach plates held on disk, and the only thing that fetches one.
  let chartStore: ChartStore

  /// The store the app runs against, or `nil` when it could not be opened even once rebuilt.
  @State private var modelContainer: ModelContainer?
  /**
   The generation ``modelContainer`` reads, which identifies the window's contents: a new
   generation rebuilds them, so nothing drawn keeps a model from the store it replaced.
   */
  @State private var navDataGeneration: Int
  @State private var loaderViewModel: NavDataLoaderViewModel?
  @State private var networkMonitor: NetworkMonitor

  /// The generation an update most recently installed, which the window follows.
  @AppStorage(SettingsKey.activeNavDataGeneration)
  private var activeNavDataGeneration = NavDataStore.emptyGeneration

  @Environment(\.scenePhase)
  private var scenePhase

  var body: some Scene {
    WindowGroup {
      Group {
        if let modelContainer, let loaderViewModel {
          AppContent(
            loaderViewModel: loaderViewModel,
            metarLoader: metarLoader,
            networkMonitor: networkMonitor,
            locationStreamer: locationStreamer,
            chartStore: chartStore
          )
          .modelContainer(modelContainer)
          .id(navDataGeneration)
        } else {
          StoreUnavailableView()
        }
      }
      .onChange(of: activeNavDataGeneration) { adoptActiveNavDataGeneration() }
    }
    .backgroundTask(.processingTask(BackgroundRefreshScheduler.navDataRefreshIdentifier)) {
      await BackgroundRefreshScheduler.shared.handleNavDataRefresh()
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active || phase == .background { scheduleBackgroundWork() }
    }
  }

  init() {
    Self.startCrashReporting()
    // Registered while launching: the permitted identifiers are read once, and a handler offered
    // afterwards is not matched against them.
    NavDataDownloadTask.shared.registerHandler()

    let isUITest = UITestConfiguration.isRunning
    metarLoader = Self.makeMETARLoader(isUITest: isUITest)
    _networkMonitor = State(
      initialValue: isUITest ? NetworkMonitor(reporting: !UITestConfiguration.isOffline) : .init()
    )
    locationStreamer = UITestConfiguration.locationStreamer
    chartStore = .makeDefault()
    NavDataUpdater.shared.chartStore = chartStore
    if isUITest { Self.discardSettings() }
    // The app reads its store read-only, so a UI test's airports go in before it is opened.
    Self.seedIfRequested()

    _navDataGeneration = State(initialValue: NavDataStore.activeGeneration)
    do {
      let container = try NavDataStore.shared.get()
      _modelContainer = State(initialValue: container)
      _loaderViewModel = State(initialValue: NavDataLoaderViewModel(container: container))
    } catch {
      Self.logger.error("Could not open the nav data store: \(error)")
      SentrySDK.capture(error: error) { scope in
        scope.setFingerprint(["store", "open"])
      }
      _modelContainer = State(initialValue: nil)
      _loaderViewModel = State(initialValue: nil)
    }
  }

  /**
   Start Sentry, which reports crashes, app hangs, and performance traces.

   The privacy manifest and the published privacy policy both promise diagnostics that are
   not linked to identity, so `sendDefaultPii` stays off: no IP address, no device name, no
   username rides along with an event.
   */
  private static func startCrashReporting() {
    SentrySDK.start { options in
      options.dsn =
        "https://39ee28977ce0467ef5c6da61b33e6665@o4510156629475328.ingest.us.sentry.io/4511805712498688"

      // Keep the SDK quiet in release: its diagnostics belong in development, not a shipped console.
      options.debug = false

      options.sendDefaultPii = false

      options.tracesSampleRate = 0.2
      options.configureProfiling = {
        $0.sessionSampleRate = 0.2
        $0.lifecycle = .trace
      }

      options.enableLogs = true

      // Discard events from the simulator and from debug builds: the former is noise, the latter
      // reports debugger-induced app hangs — a paused main thread trips the watchdog — that never
      // reflect production behavior.
      options.beforeSend = { event in
        #if DEBUG || targetEnvironment(simulator)
          return nil
        #else
          return event
        #endif
      }
    }
  }

  /**
   Discard every persisted setting before a UI test runs.

   The stores a UI test opens are its own and go with the run, but the settings beside them are
   the app's own and outlive it. One test starring an airport or choosing a rounding
   convention would otherwise decide the next test's outcome, in whatever order they happened
   to run.
   */
  private static func discardSettings() {
    guard let domain = Bundle.main.bundleIdentifier else { return }
    UserDefaults.standard.removePersistentDomain(forName: domain)
  }

  #if DEBUG
    /// The weather source: the live one, or under UI tests a loader serving a fixed observation.
    private static func makeMETARLoader(isUITest: Bool) -> METARLoader? {
      isUITest ? METARLoader(serving: uiTestObservations) : METARLoader()
    }

    /**
     Install a generation holding sample airports, and favorite one, so a UI test can drive the
     airport → approach → fixes flow without a network download.

     It is installed the way an update installs one, into the test's own store directory, so
     the app opens it exactly as it opens a downloaded cycle.
     */
    @MainActor
    private static func seedIfRequested() {
      guard UITestConfiguration.seedsStore, let layout = UITestConfiguration.storeLayout else {
        return
      }

      let missoula = PreviewData.missoula()
      do {
        let installer = NavDataStoreInstaller(layout: layout)
        let generation = installer.reserveGeneration()
        let context = ModelContext(
          try NavDataStore.makeWritableContainer(layout: layout, generation: generation)
        )
        context.insert(missoula)
        context.insert(PreviewData.sanFrancisco())
        // Seeded airports with no cycle beside them read as a half-written import, and the app
        // would offer the download rather than show them.
        context.insert(PreviewData.navDataCycle(expired: UITestConfiguration.seedsExpiredCycle))
        try context.save()
        try installer.install(generation: generation)
      } catch {
        preconditionFailure("Could not seed the UI test store: \(error)")
      }

      UserDefaults.standard.set(
        AirportIDList([missoula.siteNumber]),
        forKey: SettingsKey.favoriteAirports
      )
    }
  #else
    /// A release build has no fixtures to serve, so the weather always comes off the wire.
    private static func makeMETARLoader(isUITest _: Bool) -> METARLoader? { METARLoader() }

    /// A release build never seeds: ``PreviewData`` is not compiled into it.
    @MainActor
    private static func seedIfRequested() {}
  #endif

  /**
   Submits the app's background work to the system.

   Submission is asynchronous, and a request made only as the app leaves the screen can be cut
   short when the app is suspended. Submitting on becoming active too, when there is time to
   finish, keeps a request in place; leaving the screen then renews it.
   */
  private func scheduleBackgroundWork() {
    Task { await BackgroundRefreshScheduler.shared.scheduleNavDataRefresh() }
  }

  /**
   Reopens the store on the generation an update has just installed.

   The container holds an open handle on one generation's file, so a new one only reaches the
   app by opening it. The generation it was reading is left on disk until the next launch, when
   nothing holds it — which is what makes switching safe while the app is running.
   */
  private func adoptActiveNavDataGeneration() {
    NavDataStore.reopen()
    modelContainer = NavDataStore.container
    if let modelContainer { loaderViewModel?.container = modelContainer }
    navDataGeneration = activeNavDataGeneration
  }
}

/**
 The window's contents with the sources the app was built around in the environment.

 The location source is the one source that is set only when there is one to set: leaving the
 key alone lets the environment build its own ``CoreLocationStreamer`` when the Nearest tab first
 reads it, rather than at launch on behalf of a screen the pilot may never open.
 */
private struct AppContent: View {
  let loaderViewModel: NavDataLoaderViewModel
  let metarLoader: METARLoader?
  let networkMonitor: NetworkMonitor
  let locationStreamer: FixedLocationStreamer?
  let chartStore: ChartStore

  var body: some View {
    let content =
      ContentView()
      .environment(loaderViewModel)
      .environment(\.metarLoader, metarLoader)
      .environment(\.networkMonitor, networkMonitor)
      .environment(\.chartStore, chartStore)

    if let locationStreamer {
      content.environment(\.locationStreamer, locationStreamer)
    } else {
      content
    }
  }
}
