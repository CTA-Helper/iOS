import XCTest
import XCUIPromoKit

/**
 Captures the stills `promo/storyboard.json` sets as App Store screenshots, walking the app's
 showcase screens against the same seeded, offline store the flow tests use. `promokit stills`
 runs it; anywhere else, the test skips.

 These are not assertion tests. Every `assert…` below is there to synchronise a capture with the
 screen it means to photograph — a shot taken mid-push or before a correction has been computed
 is a wasted one — and the screen objects already own that waiting, so the flow reuses them
 rather than sleeping.

 The journeys never navigate backwards. On a two-pane layout — iPad, or iPhone Duo's inner display
 — the airport list, its approaches and the fix list are on screen at once, where "the back
 button" is ambiguous; each chapter runs forwards from its own launch, so one flow serves every
 layout.
 */
nonisolated final class StoreScreenshots: XCTestCase {
  @MainActor
  override func setUp() async throws {
    continueAfterFailure = false
    try XCTSkipUnless(
      ProcessInfo.processInfo.environment[PromoStill.directoryVariable] != nil,
      "Only `promokit stills` captures the App Store stills."
    )
  }

  @MainActor
  func testCaptureStills() throws {
    try captureApproachPlate()
    try captureCorrectedApproach()
    try captureApproachList()
    try captureAirportPicker()
    try captureSettings()
  }

  /**
   The approach plate with the corrected altitudes down its trailing edge — the one thing no chart
   app can show.

   The plate is fetched rather than served from `-uiTestChartsBundled`: the fixture draws the words
   "UI TEST PLATE" on a blank page, which is not something to publish on a product page. So this is
   the one capture that touches the network, and it fails rather than photographing a placeholder.
   */
  @MainActor
  private func captureApproachPlate() throws {
    let fixes = launchSeededApp(LaunchArgument.coldWeather)
      .openAirport("KMSO")
      .openApproach("R12-Y")

    fixes.assertCorrectsCodedFixes()
    fixes.openChart().assertIsShowing()
    try capture(.chart)
  }

  /// The corrected approach the app exists for, fix by fix.
  @MainActor
  private func captureCorrectedApproach() throws {
    let fixes = launchSeededApp(LaunchArgument.coldWeather)
      .openAirport("KMSO")
      .openApproach("R12-Y")

    fixes.assertCorrectsCodedFixes()
    try capture(.corrections)
  }

  /// An airport's approaches, grouped by the runway they serve.
  @MainActor
  private func captureApproachList() throws {
    let airports = launchSeededApp()
    guard !airports.isBesideDetailPane else { return }

    airports
      .openAirport("KMSO")
      .assertListsApproach("R12-Y")
    try capture(.approaches)
  }

  /**
   The airports a pilot has starred.

   KSFO is starred first so the list has more than the one airport the store seeds a favorite
   with, which is what makes it read as a picker rather than as an empty screen.
   */
  @MainActor
  private func captureAirportPicker() throws {
    let airports = launchSeededApp()
    guard !airports.isBesideDetailPane else { return }

    airports
      .selectTab(.search)
      .search(for: "KSFO")
      .assertListsAirport("KSFO")
      .toggleFavorite("KSFO")
      .dismissKeyboard()

    airports.selectTab(.favorites).assertListsAirport("KMSO").assertListsAirport("KSFO")
    try capture(.airports)
  }

  /// The correction preferences ENR 1.8 leaves to the operator.
  @MainActor
  private func captureSettings() throws {
    launchSeededApp().openSettings().assertIsShowing()
    try capture(.settings)
  }

  @MainActor
  private func capture(_ shot: Shot) throws {
    try PromoStill.capture(shot.rawValue, in: self)
  }

  /**
   The stills the storyboard names. The approach list and the airport picker fill only the
   leading pane, so a two-pane layout leaves them out: beside them the detail pane shows only the
   prompt to select an approach.
   */
  private enum Shot: String {
    case chart, corrections, approaches, airports, settings
  }
}
