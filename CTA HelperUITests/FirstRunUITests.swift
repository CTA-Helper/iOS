import XCTest

/**
 The one screen every pilot sees before any other: an app with an empty store can do nothing
 until a cycle has been downloaded, so the first run is driven end to end — through the
 download, into the data it produced, and through a download that fails.
 */
nonisolated final class FirstRunUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  /// The download the app cannot start without, and the approach plate it makes reachable.
  @MainActor
  func testDownloadsAndImportsNavigationDataOnFirstRun() throws {
    let airports = launchFirstRunApp(navData: LaunchArgument.bundledNavData)
      .assertOffersTheDownload()
      .startDownload()
      .awaitAirportList()

    // Nothing is favorited on a first run, so the imported airport is reached the way a pilot
    // reaches one they have never opened.
    let fixes = airports.selectTab(.search)
      .search(for: "KMSO")
      .assertListsAirport("KMSO")
      .openAirport("KMSO")
      .openApproach("R12-Y")

    fixes.reportColdTemperature().assertCorrects("CHARL")

    // Off the Search tab before reaching for Settings: an open search field takes the bar the
    // settings button sits in.
    fixes
      .goBack()
      .goBack()
      .selectTab(.favorites)
      .openSettings()
      .assertReportsCycle("2607")
  }

  /**
   A first-run download that fails leaves the pilot with no data and nothing to do but read why
   and try again, so it blocks — and it has to let go of the screen again afterwards.
   */
  @MainActor
  func testReportsAFailedFirstRunDownload() throws {
    launchFirstRunApp(navData: LaunchArgument.unreachableNavData)
      .assertOffersTheDownload()
      .startDownload()
      .assertReportsAFailure()
      .dismissFailure()
      .assertOffersTheDownload()
  }
}
