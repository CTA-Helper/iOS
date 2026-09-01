import XCTest
import XCUITestKit

/**
 The screen that stands between the pilot and their data: the one-time first-run download, the
 replacement an expired cycle asks for, and whatever came of asking.
 */
struct LoadingScreen {
  /// The element whose presence means this screen is up.
  static let landingID = "downloadNavDataButton"

  /// How long the whole download and import may take before the airport list appears.
  private static let importTimeout = ScaledTimeouts.scaled(60)

  let app: XCUIApplication

  private var downloadButton: XCUIElement { app.descendant(id: Self.landingID) }
  private var deferButton: XCUIElement { app.descendant(id: "deferNavDataButton") }

  @discardableResult
  func assertOffersTheDownload() -> Self {
    downloadButton.assertExists(
      "First run offers no way to download the navigation data",
      timeout: ScaledTimeouts.launch
    )
    return self
  }

  /// An expired cycle offers the same download, plus the choice to fly the stored one for now.
  @discardableResult
  func assertOffersToUpdate() -> Self {
    downloadButton.assertExists(
      "An expired cycle offers no way to download its replacement",
      timeout: ScaledTimeouts.launch
    )
    deferButton.assertExists("An expired cycle offers no way to defer the update")
    return self
  }

  /// The airport picker the pilot reaches by flying the expired cycle for now.
  func deferUpdate() -> AirportListScreen {
    let airports = app.descendant(id: AirportListScreen.landingID)
    deferButton.tap(untilExists: airports, using: XCUIElement.TapStrategy.escalating)
    airports.assertExists("Deferring the update did not reach the stored airports")
    return AirportListScreen(app: app)
  }

  @discardableResult
  func startDownload() -> Self {
    downloadButton.forceTap()
    return self
  }

  /// The airport picker the loading screen gives way to once a cycle has been imported.
  func awaitAirportList() -> AirportListScreen {
    app.descendant(id: AirportListScreen.landingID)
      .assertExists(
        "The loading screen stayed up after the navigation data was imported",
        timeout: Self.importTimeout
      )
    return AirportListScreen(app: app)
  }

  /// A failed download blocks: the pilot has no data, and nothing to do but read why and retry.
  @discardableResult
  func assertReportsAFailure() -> Self {
    let description = app.descendant(id: "errorDescription")
      .assertExists("A failed download reported nothing", timeout: Self.importTimeout)
    XCTAssertFalse(description.label.isEmpty, "The error sheet is blank")
    return self
  }

  @discardableResult
  func dismissFailure() -> Self {
    app.descendant(id: "errorDismissButton")
      .assertExists("No way to dismiss the error")
      .forceTap()
    return self
  }
}
