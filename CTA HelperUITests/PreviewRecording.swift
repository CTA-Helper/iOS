import XCTest
import XCUIPromoKit

/**
 Plays the App Store preview's script while `promokit record cold-approach` films the simulator.

 The take keeps each stretch worth showing — a held shot, a tap and what it changes — and files
 it under the scene `promo/storyboard.json` frames. Outside `promokit record`, the test skips.

 It opens on the favorites, drills into KMSO's RNAV (GPS) Y RWY 12 at a temperature warmer than
 the airport's −11 °C restriction, drags the temperature down to about −25 °C so the corrected
 fixes appear, and opens the plate with them beside it. The plate is fetched off camera first, so
 the recording never shows it loading.
 */
nonisolated final class PreviewRecording: XCTestCase {
  /// How long before an action first changes the screen the take keeps of it.
  private static let tapLanding: TimeInterval = 0.3

  /**
   Where the take opens on the slider's −50…+10 °C range: −2 °C, warm enough above KMSO's
   −11 °C restriction that the slider's imprecision can't carry it below.
   */
  private static let warmPosition: CGFloat = 0.8

  /// Where the take aims the temperature: −30 °C, which the drag lands a few degrees short of.
  private static let coldPosition: CGFloat = 1 / 3

  /// How long the drag down to the cold takes, so a viewer sees each row climb.
  private static let dragSeconds: TimeInterval = 2.4

  /// How long the finger rests on the thumb before it moves, and after it stops.
  private static let pressSeconds: TimeInterval = 0.15
  private static let liftSeconds: TimeInterval = 0.3

  /// Half the width of the slider's thumb, which the track is inset by at either end.
  private static let thumbRadius: CGFloat = 14

  private static let openingSeconds: TimeInterval = 2
  private static let pushSettle: TimeInterval = 1.2

  /// How long a screen the take only passes through stays up, so a viewer can take it in.
  private static let passingSettle: TimeInterval = 0.6
  private static let dragSettle: TimeInterval = 1
  private static let correctedSeconds: TimeInterval = 3.5
  private static let plateSettle: TimeInterval = 1.5
  private static let plateSeconds: TimeInterval = 4

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testRecordPreview() throws {
    let airports = launchSeededApp()
    let take = try PromoTake(app: airports.app, tapLanding: Self.tapLanding)
    setUpOpeningShot(from: airports)
    try take.startRolling()

    let app = airports.app
    let fixes = FixListScreen(app: app)
    take.scene("airports") { take.hold(Self.openingSeconds) }
    take.scene("approach") {
      take.tap(airports.airportRow("KMSO"), settle: Self.passingSettle)
      take.tap(ApproachListScreen(app: app).approachRow("R12-Y"), settle: Self.pushSettle)
      fixes.assertNoCorrectionNecessary()
    }
    take.scene("cold") { drag(fixes.temperatureSlider, to: Self.coldPosition, in: take) }
    take.scene("corrected") {
      fixes.assertCorrectsCodedFixes()
      take.hold(Self.correctedSeconds)
    }
    take.scene("plate") {
      take.tap(fixes.chartButton, settle: Self.plateSettle)
      ChartScreen(app: app).assertIsShowing()
      take.hold(Self.plateSeconds)
    }

    try take.finish()
  }

  /**
   Fetch the plate, star KSFO beside the seeded KMSO, and come back to the favorites with the
   approach left warmer than the restriction — all off camera.
   */
  @MainActor
  private func setUpOpeningShot(from airports: AirportListScreen) {
    airports
      .openAirport("KMSO")
      .openApproach("R12-Y")
      .reportColdTemperature()
      .openChart()
      .assertIsShowing()
      .goBack()
      .reportTemperature(atNormalizedPosition: Self.warmPosition)
      .assertNoCorrectionNecessary()
    airports.app.popNavigationStack(in: .leading)
    airports.app.popNavigationStack(in: .leading)

    airports
      .selectTab(.search)
      .search(for: "KSFO")
      .assertListsAirport("KSFO")
      .toggleFavorite("KSFO")
      .dismissKeyboard()
      .selectTab(.favorites)
      .assertListsAirport("KMSO")
      .assertListsAirport("KSFO")
  }

  /**
   Drag `slider`'s thumb from wherever it sits to `position`, slowly enough that every row it
   corrects can be seen climbing.
   */
  @MainActor
  private func drag(_ slider: XCUIElement, to position: CGFloat, in take: PromoTake) {
    take.drag(
      slider,
      from: thumb(of: slider, at: slider.normalizedSliderPosition),
      to: thumb(of: slider, at: position),
      press: Self.pressSeconds,
      duration: Self.dragSeconds,
      hold: Self.liftSeconds,
      settle: Self.dragSettle
    )
  }

  /// Where the thumb of `slider` sits at `position` of its range, as an offset within it.
  @MainActor
  private func thumb(of slider: XCUIElement, at position: CGFloat) -> CGVector {
    let width = slider.frame.width
    let x = (Self.thumbRadius + position * (width - 2 * Self.thumbRadius)) / width
    return CGVector(dx: x, dy: 0.5)
  }
}
