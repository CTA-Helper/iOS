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
  /// Serve the bundled sample cycle when the nav data is fetched.
  static let bundledNavData = "-uiTestNavDataBundled"
  /// Serve nothing, so the fetch fails and the loading screen has an error to report.
  static let unreachableNavData = "-uiTestNavDataUnreachable"
  /// Report location as authorized, a few miles north of KMSO.
  static let authorizedLocation = "-uiTestLocationAuthorized"
  /// Report location as refused, so the Nearest tab has to explain itself.
  static let deniedLocation = "-uiTestLocationDenied"
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
  /// Tap the back button of whichever pane is frontmost, popping one screen.
  func popNavigationStack() {
    navigationBars.buttons.firstMatch
      .assertExists("No back button to pop the screen")
      .forceTap()
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
}
