import XCTest
import XCUITestKit

/**
 The launch arguments `CTA_HelperApp` reads to settle what a test finds when it starts.

 A UI test drives the app from another process, so none of this can be set through the UI:
 the store's contents, where the nav data comes from and what Core Location reports all have
 to be decided before the first screen draws.
 */
enum LaunchArgument {
  /// Open an in-memory store holding KMSO — favorited — and KSFO, so nothing is downloaded.
  static let seedStore = "-uiTestSeed"
  /// Expire the cycle standing over the seeded airports, so the app opens offering the update.
  static let expiredCycle = "-uiTestSeedExpiredCycle"
  /// Serve the bundled sample cycle when the nav data is fetched.
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
}

/**
 Something to settle on the `XCUIApplication` itself in the moment between its creation and its
 launch.

 Everything the app reads is already on the command line, so an ordinary test has nothing to do
 here; the screenshot run uses it to wire up fastlane's `setupSnapshot(_:)`, which appends launch
 arguments of its own and so has to run after the test's are in place but before the process
 starts.
 */
typealias LaunchPreparation = @MainActor (XCUIApplication) -> Void

/**
 Launches the app against the seeded store and returns the airport picker it lands on.

 - Parameters:
   - arguments: anything the test wants settled beyond the seeded store — a location to report,
     say.
   - prepare: what to do to the app before it launches, if anything.
 */
@discardableResult
func launchSeededApp(
  _ arguments: String...,
  preparedBy prepare: LaunchPreparation? = nil
) -> AirportListScreen {
  let app = launchApp([LaunchArgument.seedStore] + arguments, preparedBy: prepare) {
    $0.descendant(id: AirportListScreen.landingID)
  }
  return AirportListScreen(app: app)
}

/**
 Launches the app against the seeded store with an expired cycle over it, and returns the loading
 screen it opens on offering the update.
 */
func launchExpiredCycleApp() -> LoadingScreen {
  let app = launchApp([LaunchArgument.seedStore, LaunchArgument.expiredCycle]) {
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
  preparedBy prepare: LaunchPreparation? = nil,
  readyElement: (XCUIApplication) -> XCUIElement
) -> XCUIApplication {
  let app = XCUIApplication()
  app.launchArguments = arguments
  prepare?(app)
  app.launchAndWaitUntilReady(readyElement: readyElement)
  return app
}

extension XCUIApplication {
  /// The identifiers UIKit gives the back button it synthesizes for a pushed screen.
  private static let backButtonIDs = ["back-nav-button", "BackButton"]

  /**
   Tap the back button of `pane`'s navigation stack, popping one screen.

   Two things have to be right for a pop to land where the caller meant it to. The button is
   picked out by identifier rather than taken to be the first in a bar, because a bar carries
   its screen's own toolbar items beside the back button. And the bar is picked out by pane,
   because on iPad both panes can hold a pushed screen at once and so both carry a back button
   — the sidebar's comes first in the hierarchy, which is how popping the weather screen came
   to unwind the leading pane instead and leave the detail pane on its placeholder.

   The panes are told apart by width: the trailing one spans the window and the leading one is
   the sidebar. Geometry relative to the screen being left cannot tell them apart, since a
   pushed detail screen reports the whole window as its frame, sitting behind the very bar that
   titles it.
   */
  func popNavigationStack(in pane: Pane) {
    backButton(in: pane)
      .assertExists("No back button to pop the \(pane) pane")
      .tap()
  }

  /// The back button in `pane`'s bar, or the first one found if the panes can't be told apart.
  private func backButton(in pane: Pane) -> XCUIElement {
    let bars = navigationBars.allElementsBoundByIndex.filter(\.exists)
    let bar =
      switch pane {
        case .leading: bars.min { $0.frame.width < $1.frame.width }
        case .trailing: bars.max { $0.frame.width < $1.frame.width }
      }

    return (bar ?? navigationBars.firstMatch).buttons
      .matching(NSPredicate(format: "identifier IN %@", Self.backButtonIDs))
      .firstMatch
  }

  /**
   The navigation bar belonging to `screen` rather than to whatever else is on screen.

   Several bars coexist: on iPad each split view pane has one, and a sheet presented over them
   adds another while the ones behind it stay in the hierarchy. Neither the first bar nor the
   last is reliably the one wanted — which is what made `popNavigationStack()` reach for the
   airport list's buttons from inside the settings sheet. Matching by geometry instead, the bar
   sitting directly above the screen and spanning its width, tells them apart without depending
   on the layout or on localized titles.
   */
  func navigationBar(above screen: XCUIElement) -> XCUIElement {
    guard screen.exists else { return navigationBars.firstMatch }

    let bounds = screen.frame
    let bar = navigationBars.allElementsBoundByIndex.first {
      $0.exists && $0.frame.minX >= bounds.minX - 1 && $0.frame.maxX <= bounds.maxX + 1
        && $0.frame.minY <= bounds.minY
    }
    return bar ?? navigationBars.firstMatch
  }

  /// Which of the split view's two stacks a pop belongs to; on iPhone both name the only one.
  enum Pane {
    case leading, trailing
  }
}
