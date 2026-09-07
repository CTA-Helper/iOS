import UIKit
import XCTest

/**
 Captures the App Store screenshot set with fastlane's `snapshot`, walking the app's showcase
 screens against the same seeded, offline store the flow tests use.

 These are not assertion tests. Every `assert…` below is there to synchronise a capture with the
 screen it means to photograph — a shot taken mid-push or before a correction has been computed
 is a wasted one — and the screen objects already own that waiting, so the flow reuses them
 rather than sleeping.

 The journeys never navigate backwards. On iPad the airport list, its approaches and the fix
 list are laid out across two panes at once, where "the back button" is ambiguous; running each
 chapter forwards from its own launch keeps one flow serving both device families. What the
 shots are named decides the order they appear in on the product page, which is why the capture
 order and the numbering disagree.
 */
nonisolated final class GenerateScreenshots: XCTestCase {
  /**
   Whether the app is laid out as two panes at once.

   The airport list and the approach list each fill only the leading one, leaving the detail pane
   showing the prompt to select an approach — a screenshot mostly of empty space, so those two
   are captured on iPhone alone.
   */
  @MainActor private static var isSplitViewLayout: Bool {
    UIDevice.current.userInterfaceIdiom == .pad
  }

  /**
   Hands the app to fastlane's screenshot bridge in the moment before it launches.

   `setupSnapshot(_:)` appends launch arguments of its own — the language and locale the run is
   capturing, and the flag naming the directory the helper writes to — so it has to run after the
   test's own arguments are in place and before the process starts.

   A closure capturing nothing rather than a method on this class: a main actor-isolated function
   type is implicitly `@Sendable`, which a reference to a method of a non-`Sendable` `XCTestCase`
   is not.
   */
  private static let wireUpSnapshot: LaunchPreparation = { setupSnapshot($0) }

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  /// The corrected approach the app exists for, and the METAR its temperature was filled from.
  @MainActor
  func testCapturesTheCorrectedApproach() throws {
    let fixes = launchSeededApp(preparedBy: Self.wireUpSnapshot)
      .openAirport("KMSO")
      .openApproach("R12-Y")
      .reportColdTemperature()

    fixes.assertCorrectsCodedFixes()
    snapshot("01-Corrections")

    fixes.openWeather().assertReportsStation("KMSO")
    snapshot("03-Weather")
  }

  /**
   The approach plate with the corrected altitudes down its trailing edge — the one thing no chart
   app can show, and what this release is for.

   The plate is fetched rather than served from `-uiTestChartsBundled`: the fixture draws the words
   "UI TEST PLATE" on a blank page, which is not something to publish on a product page. So this is
   the one capture that touches the network, and it fails rather than photographing a placeholder.
   */
  @MainActor
  func testCapturesTheApproachPlate() throws {
    let fixes = launchSeededApp(preparedBy: Self.wireUpSnapshot)
      .openAirport("KMSO")
      .openApproach("R12-Y")

    fixes.reportColdTemperature()
    fixes.assertCorrectsCodedFixes()
    fixes.openChart().assertIsShowing()
    snapshot("02-Chart")
  }

  /// An airport's approaches, grouped by the runway they serve.
  @MainActor
  func testCapturesTheApproachList() throws {
    try XCTSkipIf(Self.isSplitViewLayout, "Fills only the leading pane on iPad")

    launchSeededApp(preparedBy: Self.wireUpSnapshot)
      .openAirport("KMSO")
      .assertListsApproach("R12-Y")
    snapshot("04-Approaches")
  }

  /**
   The airports a pilot has starred.

   KSFO is starred first so the list has more than the one airport the store seeds a favorite
   with, which is what makes it read as a picker rather than as an empty screen.
   */
  @MainActor
  func testCapturesTheAirportPicker() throws {
    try XCTSkipIf(Self.isSplitViewLayout, "Fills only the leading pane on iPad")

    let airports = launchSeededApp(preparedBy: Self.wireUpSnapshot)
    airports
      .selectTab(.search)
      .search(for: "KSFO")
      .assertListsAirport("KSFO")
      .toggleFavorite("KSFO")
      .dismissKeyboard()

    airports.selectTab(.favorites).assertListsAirport("KMSO").assertListsAirport("KSFO")
    snapshot("05-Airports")
  }

  /// The correction preferences ENR 1.8 leaves to the operator.
  @MainActor
  func testCapturesSettings() throws {
    launchSeededApp(preparedBy: Self.wireUpSnapshot).openSettings().assertIsShowing()
    snapshot("06-Settings")
  }
}
