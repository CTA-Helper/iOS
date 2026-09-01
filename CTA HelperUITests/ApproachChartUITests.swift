import XCTest
import XCUITestKit

/**
 The approach plate, and the corrected altitudes laid over it.

 Drawing a PDF is PDFKit's business and is not tested here. What is tested is the claim the
 screen exists to make — that the column over the plate carries the same corrections the fix
 list computed — and the promise the app makes about having no network.
 */
nonisolated final class ApproachChartUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  /**
   The overlay shows the fix list's own corrections, over the plate.

   The reading is taken from the fix list first and compared against the overlay's, because a
   column that merely lists altitudes would pass an assertion that only checked it was populated
   — and would still be wrong if it showed published values, or values from another transition,
   or the correction for a temperature the pilot has since moved off.
   */
  @MainActor
  func testLaysTheFixListsCorrectionsOverThePlate() {
    let fixes = launchSeededApp(LaunchArgument.bundledCharts)
      .openAirport("KMSO")
      .openApproach("R12-Y")

    fixes.reportColdTemperature()
    fixes.assertCorrectsCodedFixes()
    let onTheFixList = fixes.reading(of: "CHARL")

    let chart = fixes.openChart().assertIsShowing()

    XCTAssertEqual(
      chart.reading(of: "CHARL"),
      onTheFixList,
      "The overlay reads out a different correction for CHARL than the fix list does"
    )
  }

  /**
   What the pilot set survives a trip to the plate and back.

   The entries belong to the approach being flown rather than to one appearance of the screen,
   and pushing the chart makes the fix list disappear and appear again. Reading the same fix
   before and after is what catches the reported temperature being pulled back to the station's
   METAR, or the typed minimums being blanked, the moment the plate is dismissed — leaving the
   pilot looking at a correction for a temperature they never reported.
   */
  @MainActor
  func testKeepsWhatThePilotSetAfterTheChartIsDismissed() {
    let fixes = launchSeededApp(LaunchArgument.bundledCharts)
      .openAirport("KMSO")
      .openApproach("R12-Y")

    fixes.reportColdTemperature()
    fixes.assertCorrectsCodedFixes()
    fixes.enterMinimums("4520")

    let correctionBefore = fixes.reading(of: "CHARL")
    let minimumsBefore = fixes.correctedMinimumsLabel

    let backOnTheFixList = fixes.openChart().assertIsShowing().goBack()
    backOnTheFixList.assertIsShowing("RNAV (GPS) Y RWY 12")

    XCTAssertEqual(
      backOnTheFixList.reading(of: "CHARL"),
      correctionBefore,
      "CHARL is corrected differently after the plate was dismissed, so the reported "
        + "temperature did not survive the trip"
    )
    XCTAssertEqual(
      backOnTheFixList.correctedMinimumsLabel,
      minimumsBefore,
      "Dismissing the plate cleared the minimums the pilot had entered"
    )
  }

  /// A plate is dense, so whatever the panel covers has to be reachable.
  @MainActor
  func testTheAltitudesCanBeHiddenToUncoverThePlate() {
    launchSeededApp(LaunchArgument.bundledCharts)
      .openAirport("KMSO")
      .openApproach("R12-Y")
      .openChart()
      .assertIsShowing()
      .assertAltitudesCanBeHidden()
  }

  /**
   With no network and nothing cached, the button says so before it is pressed and the screen
   explains once it is.

   This is the promise the whole chart cache exists to keep: a control that looked the same
   whether or not it could produce a chart would be making one the app cannot honor.
   */
  @MainActor
  func testSaysAChartIsNotDownloadedBeforeItIsTapped() {
    let fixes = launchSeededApp(LaunchArgument.bundledCharts, LaunchArgument.offline)
      .openAirport("KMSO")
      .openApproach("R12-Y")

    XCTAssertTrue(
      fixes.chartButtonLabel().contains("Not Downloaded"),
      "The chart button gives no sign it has no chart to open: “\(fixes.chartButtonLabel())”"
    )

    fixes.openChart().assertExplainsWhyThereIsNoChart()
  }
}
