import XCTest

/**
 Drives the whole airport → approach → fixes flow against a seeded, offline store, and
 confirms the fixes screen corrects an approach once the temperature calls for it, listing
 whichever transition of the initial segment the pilot selects.
 */
nonisolated final class CTA_HelperUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testCorrectsAnApproachFromTheAirportList() throws {
    let fixes = launchSeededApp()
      .openAirport("KMSO")
      .openApproach("R12-Y")

    // The seeded temperature (0 °C) is warmer than KMSO's −11 °C restriction, so there is
    // nothing to correct until the pilot reports a colder temperature.
    fixes.assertNoCorrectionNecessary()
    attach(fixes.app.screenshot(), named: "NoCorrectionNecessary")

    fixes.reportColdTemperature()
    fixes.assertCorrectsCodedFixes()

    fixes.selectTransition("JENKI")
    fixes.assertListsFix("LANNY", butNot: "CHARL")
    fixes.selectTransition("CHARL")
    fixes.assertListsFix("CHARL", butNot: "LANNY")

    fixes.enterMinimums("4520")
    fixes.assertCorrectsMinimums(enteredFt: "4520")
    attach(fixes.app.screenshot(), named: "FixListScreen")

    fixes.assertRetypingReplacesMinimums("3200")
  }

  /**
   The weather screen pushes on top of the fix list rather than replacing it, and popping it
   unwinds the stack a screen at a time with every later selection still navigating.

   Each pane needs a navigation stack of its own for that to hold: a link in a bare split view
   column has nothing to push onto, and once it overwrites the column instead, the selection is
   out of step with what is on screen and no further approach opens.
   */
  @MainActor
  func testWeatherPushesOverTheFixListWithoutUnsettlingTheStack() throws {
    let approaches = launchSeededApp().openAirport("KMSO")
    let fixes = approaches.openApproach("R12-Y")

    let weather = fixes.openWeather()
    weather.assertReportsStation("KMSO")
    weather.goBack().assertIsShowing("RNAV (GPS) Y RWY 12")

    fixes.goBack().openApproach("R30").assertIsShowing("RNAV (GPS) RWY 30")
  }

  /// Keep a screenshot of one of the fix list's two modes with the test results.
  @MainActor
  private func attach(_ screenshot: XCUIScreenshot, named name: String) {
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
