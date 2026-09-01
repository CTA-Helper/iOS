import XCTest

/**
 The preferences that decide what the correction comes to, driven the only way that proves they
 are wired to anything: by changing one and reading the altitude off the fix list again.

 Each is worth a whole flow because each is a number the pilot flies. A setting that is written
 but never read, or read from a stale copy, would be invisible on the settings screen and wrong
 only on the plate.
 */
nonisolated final class CorrectionSettingsUITests: XCTestCase {
  /**
   The DA/MDA the seeded approach is corrected from.

   Chosen so the two rounding conventions part company: 794 ft above the field, the raw
   correction lands near 180 ft across the whole cold end of the slider — which rounds to the
   nearest 10 ft one way and up to the next 100 ft the other. A DA/MDA whose raw correction
   happened to be a multiple of 100 would round identically and prove nothing.
   */
  private static let enteredMinimumsFt = "4000"

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  /// The final segment is never rounded down, but how far up it goes is the pilot's to choose.
  @MainActor
  func testRoundingConventionChangesTheCorrectedMinimums() throws {
    let airports = launchSeededApp()

    airports.openSettings().selectRounding(.nearestHundred).close()
    let toNearestHundred = correctedMinimums(from: airports)

    airports.openSettings().selectRounding(.roundUp).close()
    let roundedUp = correctedMinimums(from: airports)

    XCTAssertNotEqual(
      toNearestHundred,
      roundedUp,
      "Rounding always up gave the same DA/MDA as rounding to the nearest 100 ft"
    )
  }

  /**
   Above the table's 5,000 ft ceiling the correction is either capped there or evaluated at the
   true height, and CHARL's initial segment is where the two part company.

   The height that decides this is the segment's *reference* altitude above the field, not
   CHARL's own published one. Under the All Segments Method every segment corrects off the FAF
   at 6,200 ft — 2,994 ft above KMSO — which is inside the table, and extrapolating would change
   nothing. The Individual Segments Method gives the initial segment its own reference of
   9,400 ft, 6,194 ft up, and only there does the ceiling bind.
   */
  @MainActor
  func testExtrapolationChangesACorrectionAboveTheTable() throws {
    let airports = launchSeededApp()

    let capped = correctedAltitude(of: "CHARL", from: airports, method: .individualSegments)

    airports.openSettings().toggleExtrapolation().close()
    let extrapolated = correctedAltitude(of: "CHARL", from: airports, method: .individualSegments)

    XCTAssertNotEqual(
      capped,
      extrapolated,
      "Extrapolating above the table left CHARL’s correction at its capped value"
    )
  }

  /**
   KMSO's restriction marks the initial, intermediate and final segments and not the missed one,
   so correcting individual segments leaves the missed approach holding altitude as published —
   where correcting all segments carries it down to the holding fix.
   */
  @MainActor
  func testCorrectionMethodDecidesWhichSegmentsAreCorrected() throws {
    let fixes = launchSeededApp()
      .openAirport("KMSO")
      .openApproach("R12-Y")
      .reportColdTemperature()

    // SUPPY is the FAF, in the intermediate segment the restriction does mark. It is the control:
    // a corrector that simply stopped correcting would move JENKI too, and prove nothing.
    fixes.selectCorrectionMethod(.allSegments)
    let (missed, marked) = (fixes.reading(of: "JENKI"), fixes.reading(of: "SUPPY"))

    fixes.selectCorrectionMethod(.individualSegments)
    XCTAssertNotEqual(
      missed,
      fixes.reading(of: "JENKI"),
      "Correcting individual segments still corrected the missed approach"
    )
    XCTAssertEqual(
      marked,
      fixes.reading(of: "SUPPY"),
      "Correcting individual segments changed a segment the restriction marks"
    )
    fixes.assertExplains(.missed)
  }

  /// The advisory-use disclaimer and the build the pilot is flying are both reachable.
  @MainActor
  func testAboutNamesTheAppVersion() throws {
    let settings = launchSeededApp().openSettings().assertIsShowing()

    settings.openAbout().assertNamesItsVersion().goBack().close()
  }

  /// Correct the seeded approach with the settings as they stand, and report the DA/MDA it gives.
  @MainActor
  private func correctedMinimums(from airports: AirportListScreen) -> String {
    let fixes = openSeededApproach(from: airports)
    fixes.enterMinimums(Self.enteredMinimumsFt)
    let corrected = fixes.correctedMinimumsLabel
    leave(fixes)
    return corrected
  }

  /// Correct the seeded approach under a given method, and report what a fix's row reads out.
  @MainActor
  private func correctedAltitude(
    of identifier: String,
    from airports: AirportListScreen,
    method: FixListScreen.Method
  ) -> String {
    let fixes = openSeededApproach(from: airports)
    fixes.selectCorrectionMethod(method)
    let altitude = fixes.reading(of: identifier)
    leave(fixes)
    return altitude
  }

  @MainActor
  private func openSeededApproach(from airports: AirportListScreen) -> FixListScreen {
    airports.openAirport("KMSO").openApproach("R12-Y").reportColdTemperature()
  }

  /// Unwind to the airport picker, which is where Settings is reached from.
  @MainActor
  private func leave(_ fixes: FixListScreen) {
    fixes.goBack().goBack()
  }
}
