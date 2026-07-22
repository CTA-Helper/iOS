import XCTest
import XCUITestKit

/// The station's METAR, pushed on top of the fix list.
struct WeatherScreen {
  let app: XCUIApplication

  func assertReportsStation(_ stationID: String) {
    app.descendant(id: "weatherScreen").assertExists("Weather screen did not appear")

    let station = app.descendant(id: "weatherStation")
      .assertExists("Weather screen names no station")
    // The station row carries the identifier it filed under as its accessibility value.
    XCTAssertEqual(
      station.value as? String,
      stationID,
      "Weather screen reports a station other than \(stationID)"
    )
  }

  @discardableResult
  func goBack() -> FixListScreen {
    app.popNavigationStack()
    return FixListScreen(app: app)
  }
}
