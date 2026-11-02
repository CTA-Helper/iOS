import XCTest
import XCUITestKit

/**
 The launch arguments `CTA_HelperApp` reads to settle what a test finds when it starts.

 A UI test drives the app from another process, so none of this can be set through the UI:
 the store's contents, where the nav data comes from and what Core Location reports all have
 to be decided before the first screen draws.
 */
enum LaunchArgument {
  /// Install a generation holding KMSO — favorited — and KSFO in the test's own store directory.
  static let seedStore = "-uiTestSeed"
  /// Expire the cycle standing over the seeded airports, so the app opens offering the update.
  static let expiredCycle = "-uiTestSeedExpiredCycle"
  /// Serve the bundled sample cycle when the nav data is fetched, as a prebuilt store.
  static let bundledNavData = "-uiTestNavDataBundled"
  /// Serve nothing, so the fetch fails and the loading screen has an error to report.
  static let unreachableNavData = "-uiTestNavDataUnreachable"
  /// Report location as authorized, a few miles north of KMSO.
  static let authorizedLocation = "-uiTestLocationAuthorized"
  /// Report location as refused, so the Nearest tab has to explain itself.
  static let deniedLocation = "-uiTestLocationDenied"
  /// Serve a synthesized one-page plate when a chart is fetched, so no test touches the network.
  static let bundledCharts = "-uiTestChartsBundled"

  /// Paces the fixture's plates so a bulk download outlasts the controls it finishes over.
  static let pacedCharts = "-uiTestChartsPaced"
  /// Report the device as offline, so the states that depend on having no network can be driven.
  static let offline = "-uiTestOffline"
  /// Serve weather colder than the seeded restriction, which the fix list corrects for at once.
  static let coldWeather = "-uiTestWeatherCold"
}

/**
 Launches the app against the seeded store and returns the airport picker it lands on.

 - Parameter arguments: anything the test wants settled beyond the seeded store — a location to
   report, say.
 */
@discardableResult
func launchSeededApp(_ arguments: String...) -> AirportListScreen {
  let app = launchApp([LaunchArgument.seedStore] + arguments) {
    $0.descendant(id: AirportListScreen.landingID)
  }
  return AirportListScreen(app: app)
}

/**
 Launches the app against the seeded store with an expired cycle over it, and returns the loading
 screen it opens on offering the update.

 - Parameter arguments: anything the test wants settled beyond the expired store — where the
   update is served from, say.
 */
func launchExpiredCycleApp(_ arguments: String...) -> LoadingScreen {
  let app = launchApp([LaunchArgument.seedStore, LaunchArgument.expiredCycle] + arguments) {
    $0.descendant(id: LoadingScreen.landingID)
  }
  return LoadingScreen(app: app)
}

/**
 Launches the app with an empty store, as a pilot's first run, and returns the loading screen
 it opens on.

 - Parameter navData: where the download is served from — ``LaunchArgument/bundledNavData`` or
   ``LaunchArgument/unreachableNavData``.
 */
func launchFirstRunApp(navData: String) -> LoadingScreen {
  let app = launchApp([navData]) { $0.descendant(id: LoadingScreen.landingID) }
  return LoadingScreen(app: app)
}

/**
 Launch and wait for the first screen to be queryable.

 `readyElement` is what the launch is finished when it can see: waiting for it rather than for
 `launch()` to return keeps the first query of every test off a simulator that has foregrounded
 the app but not yet drawn it.
 */
private func launchApp(
  _ arguments: [String],
  readyElement: (XCUIApplication) -> XCUIElement
) -> XCUIApplication {
  let app = XCUIApplication()
  app.launchArguments = arguments
  app.launchAndWaitUntilReady(readyElement: readyElement)
  return app
}

extension XCUIApplication {
  /// The identifiers UIKit gives the back button it synthesizes for a pushed screen.
  private static let backButtonIDs = ["back-nav-button", "BackButton"]

  /**
   Where the leading pane ends, where two sit side by side: the trailing edge of a navigation bar
   that starts at the window's leading edge and stops short of its trailing one. `nil` where a
   single stack fills the window, its bar spanning it.
   */
  private var paneEdge: CGFloat? {
    let window = windows.firstMatch.frame
    return navigationBars.allElementsBoundByIndex
      .filter(\.exists)
      .map(\.frame)
      .first { abs($0.minX - window.minX) < 1 && $0.maxX < window.maxX - 1 }?
      .maxX
  }

  /**
   Tap the back button of `pane`'s navigation stack, popping one screen.

   The button is picked out by identifier rather than taken to be the first in a bar, because a
   bar carries its screen's own toolbar items beside the back button, and it is looked for across
   the whole window rather than in a navigation bar: where the bar is vertical — iPhone Duo's
   outer display — the back button sits in a toolbar down the trailing edge, and the navigation
   bar holds the title alone.

   On iPad both panes can hold a pushed screen at once and so both carry a back button — the
   sidebar's comes first in the hierarchy, which is how popping the weather screen came to unwind
   the leading pane instead and leave the detail pane on its placeholder. Where two panes sit side
   by side, the button has to stand on the named side of the edge between them, which holds
   whichever way the bars run; a pane with no back button of its own fails the assertion rather
   than popping the other. Geometry relative to the screen being left cannot tell the panes apart,
   since a pushed detail screen reports the whole window as its frame.
   */
  func popNavigationStack(in pane: Pane) {
    backButton(in: pane)
      .assertExists("No back button to pop the \(pane) pane")
      .tap()
  }

  /**
   The back button of `pane`: on its side of the edge between the panes where there are two, and
   the only one there is where a single stack fills the window.
   */
  private func backButton(in pane: Pane) -> XCUIElement {
    let backButtons = buttons.matching(NSPredicate(format: "identifier IN %@", Self.backButtonIDs))
    _ = backButtons.firstMatch.waitForExistence(timeout: ScaledTimeouts.element)
    let onScreen = backButtons.allElementsBoundByIndex.filter { $0.exists && $0.isHittable }

    guard let edge = paneEdge else { return onScreen.first ?? backButtons.firstMatch }
    let inPane = onScreen.first {
      switch pane {
        case .leading: $0.frame.midX < edge
        case .trailing: $0.frame.midX > edge
      }
    }
    return inPane ?? buttons.matching(identifier: "no back button in the \(pane) pane").firstMatch
  }

  /**
   The navigation bar belonging to `screen` rather than to whatever else is on screen.

   Several bars coexist: on iPad each split view pane has one, and a sheet presented over them
   adds another while the ones behind it stay in the hierarchy. Neither the first bar nor the
   last is reliably the one wanted — which is what made `popNavigationStack()` reach for the
   airport list's buttons from inside the settings sheet. Matching by geometry instead tells them
   apart without depending on the layout or on localized titles: the bar lies within the screen's
   width, and of those, its top is the nearest the screen's own. The screen's content can start
   above its bar as well as below it — iPhone Duo's outer display runs a sheet's form up under
   its title — so the bar is not required to sit above it.
   */
  func navigationBar(of screen: XCUIElement) -> XCUIElement {
    guard screen.exists else { return navigationBars.firstMatch }

    let bounds = screen.frame
    let bar = navigationBars.allElementsBoundByIndex
      .filter { $0.exists && $0.frame.minX >= bounds.minX - 1 && $0.frame.maxX <= bounds.maxX + 1 }
      .min { abs($0.frame.minY - bounds.minY) < abs($1.frame.minY - bounds.minY) }
    return bar ?? navigationBars.firstMatch
  }

  /// Which of the split view's two stacks a pop belongs to; on iPhone both name the only one.
  enum Pane {
    case leading, trailing
  }
}
