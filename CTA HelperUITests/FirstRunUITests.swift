import XCTest

/**
 The screen that stands between the pilot and their data, driven end to end: an app with an empty
 store can do nothing until a cycle has been downloaded, and one whose cycle has expired asks
 before it replaces it.
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

  /**
   An expired cycle asks before it spends a download, and a pilot who would rather fly the data
   they already have can — with Settings left saying that data is out of date.
   */
  @MainActor
  func testDefersAnExpiredCycleOntoTheStoredData() throws {
    launchExpiredCycleApp()
      .assertOffersToUpdate()
      .deferUpdate()
      .openSettings()
      .assertReportsAnExpiredCycle()
  }
}
