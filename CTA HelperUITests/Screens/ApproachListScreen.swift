import XCTest
import XCUITestKit

/// The airport's approaches, pushed alongside the airport list in the leading pane.
struct ApproachListScreen {
  let app: XCUIApplication

  /**
   Whether the approach list is on screen.

   On iPad it still is while the fixes show: the approaches head the leading pane and the fix
   list fills the trailing one, so both are visible at once.
   */
  var isShowing: Bool {
    app.descendants(matching: .any)
      .matching(NSPredicate(format: "identifier BEGINSWITH %@", "approachRow-"))
      .firstMatch
      .exists
  }

  @discardableResult
  func openApproach(_ identifier: String) -> FixListScreen {
    approachRow(identifier)
      .assertExists("Approach \(identifier) not found")
      .tap()
    return FixListScreen(app: app)
  }

  @discardableResult
  func assertListsApproach(_ identifier: String) -> Self {
    approachRow(identifier).assertExists("Approach \(identifier) is not listed")
    return self
  }

  /// Ask for every plate the airport publishes, and say yes to the confirmation.
  @discardableResult
  func downloadCharts() -> Self {
    app.descendant(id: "downloadChartsButton")
      .assertExists("The approach list offers no way to download the charts")
      .tap()
    app.descendant(id: "confirmDownloadCharts")
      .assertExists("The download was never offered for confirmation")
      .tap()
    return self
  }

  /**
   The finished run says what it fetched, and the summary stays to be read.

   Both halves matter. The summary is raised as the confirmation dialog is leaving, and a
   presentation arriving while another goes is dropped rather than queued — so a run quick
   enough to beat the animation flashes the summary and loses it, which asserting only that it
   appeared would not catch.
   */
  @discardableResult
  func assertReportsWhatItFetched() -> Self {
    let summary = app.alerts.firstMatch
    summary.assertExists(
      "The download finished without saying what it fetched",
      timeout: ScaledTimeouts.slowElement
    )
    XCTAssertFalse(
      summary.waitForNonExistence(timeout: ScaledTimeouts.short),
      "The summary left on its own before it could be read"
    )
    summary.buttons["OK"].tap()
    return self
  }

  /// The download is not on offer, there being nothing left to fetch.
  @discardableResult
  func assertChartsNeedNoDownload() -> Self {
    let button = app.descendant(id: "downloadChartsButton")
      .assertExists("The approach list dropped the download control altogether")
    XCTAssertFalse(
      button.isEnabled,
      "The download is still offered with every plate already on the device"
    )
    return self
  }

  @discardableResult
  func goBack() -> AirportListScreen {
    app.popNavigationStack(in: .leading)
    return AirportListScreen(app: app)
  }

  private func approachRow(_ identifier: String) -> XCUIElement {
    app.descendant(id: "approachRow-\(identifier)")
  }
}
