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

     The observation reports no temperature on purpose: the fix list auto-fills the reported
     temperature from the METAR, and a seeded reading would displace the 0 °C the seeded data is
     corrected at. Reporting none leaves that default standing while still giving the fix list a
     station to link its weather screen to.
     */
    private static let uiTestObservations = [
      "KMSO": METARObservation(
        stationID: "KMSO",
        temperature: nil,
        date: Date(timeIntervalSince1970: 1_700_000_000),
        rawText: "METAR KMSO 141953Z 28008KT 10SM FEW070 SCT090 A2996 RMK AO2"
      )
    ]
  #endif

  /// The store the app runs against, or `nil` when it could not be opened even once rebuilt.
  let modelContainer: ModelContainer?
  /// The weather source: the live one, or under UI tests a loader serving a fixed observation.
  let metarLoader: METARLoader?
  /**
   The location source a UI test asked for, or `nil` to leave the device's own in place.

   Only a test ever replaces it, and only a test ever reads it before the pilot opens the
   Nearest tab — building a ``CoreLocationStreamer`` raises the permission alert, so the
   environment's own default stays untouched until then.
   */
  let locationStreamer: FixedLocationStreamer?
  /// The approach plates held on disk, and the only thing that fetches one.
  let chartStore: ChartStore

  @State private var loaderViewModel: NavDataLoaderViewModel?
  @State private var networkMonitor: NetworkMonitor

  var body: some Scene {
    WindowGroup {
      if let modelContainer, let loaderViewModel {
        AppContent(
          loaderViewModel: loaderViewModel,
          metarLoader: metarLoader,
          networkMonitor: networkMonitor,
          locationStreamer: locationStreamer,
          chartStore: chartStore
        )
        .modelContainer(modelContainer)
      } else {
        StoreUnavailableView()
      }
    }
  }

  init() {
    Self.startCrashReporting()

    let isUITest = UITestConfiguration.isRunning
    metarLoader = Self.makeMETARLoader(isUITest: isUITest)
    _networkMonitor = State(
      initialValue: isUITest ? NetworkMonitor(reporting: !UITestConfiguration.isOffline) : .init()
    )
    locationStreamer = UITestConfiguration.locationStreamer
    chartStore = .makeDefault()
    if isUITest { Self.discardSettings() }

    do {
      let container = try NavDataStore.shared.get()
      Self.seedIfRequested(container)
      modelContainer = container
      _loaderViewModel = State(
        initialValue: NavDataLoaderViewModel(container: container, chartStore: chartStore)
      )
    } catch {
      Self.logger.error("Could not open the nav data store: \(error)")
      SentrySDK.capture(error: error) { scope in
        scope.setFingerprint(["store", "open"])
      }
      modelContainer = nil
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

   The store a UI test opens is in memory and goes with the process, but the settings beside it
   are the app's own and outlive it. One test starring an airport or choosing a rounding
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
     Seed an in-memory store with sample airports and a favorite, so a UI test can drive the
     airport → approach → fixes flow without a network download.
     */
    @MainActor
    private static func seedIfRequested(_ container: ModelContainer) {
      guard UITestConfiguration.seedsStore else { return }

      let missoula = PreviewData.missoula()
      container.mainContext.insert(missoula)
      container.mainContext.insert(PreviewData.sanFrancisco())
      // Seeded airports with no cycle beside them read as a half-written import, and the app
      // would offer the download rather than show them.
      container.mainContext.insert(
        PreviewData.navDataCycle(expired: UITestConfiguration.seedsExpiredCycle)
      )
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
    private static func seedIfRequested(_: ModelContainer) {}
  #endif
}

/**
 The window's contents with the sources the app was built around in the environment.

 The location source is the one source that is set only when there is one to set: its default
 is a ``CoreLocationStreamer``, and building one asks the pilot for permission, which is a
 question to raise when they open the Nearest tab rather than when the app launches.
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
