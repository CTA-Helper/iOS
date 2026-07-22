import XCTest

/**
 The four ways an approach plate is reached: the airports the pilot has starred, the ones they
 last opened, the ones around them, and the one they can name.

 Each tab sources its airports differently, and only the list that results is the pilot's way
 in — so each is driven to the point of opening an airport rather than merely rendering one.
 */
nonisolated final class AirportPickerUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  /// Search reaches an airport that was never starred — the only way to a cold field far away.
  @MainActor
  func testSearchesForAnAirportByIdentifier() throws {
    let airports = launchSeededApp()
      .selectTab(.search)
      .search(for: "KSFO")

    airports.assertListsAirport("KSFO")
    airports.assertDoesNotListAirport("KMSO")

    airports.openAirport("KSFO")
  }

  /// A query too short to search on leaves the prompt standing rather than listing everything.
  @MainActor
  func testWaitsForEnoughOfAQueryToSearchOn() throws {
    launchSeededApp()
      .selectTab(.search)
      .search(for: "K")
      .assertDoesNotListAirport("KSFO")
      .assertDoesNotListAirport("KMSO")
  }

  /// Opening an airport files it under Recents, which is what makes the tab worth having.
  @MainActor
  func testRecordsAnOpenedAirportAsRecent() throws {
    let airports = launchSeededApp()

    airports.selectTab(.recents).assertDoesNotListAirport("KMSO")

    airports.selectTab(.favorites).openAirport("KMSO").goBack()

    airports.selectTab(.recents).assertListsAirport("KMSO").openAirport("KMSO")
  }

  /// Starring an airport puts it on the Favorites tab, and clearing the star takes it off again.
  @MainActor
  func testFavoritingAnAirportAddsItToFavorites() throws {
    let airports = launchSeededApp()

    airports.selectTab(.favorites).assertDoesNotListAirport("KSFO")

    airports
      .selectTab(.search)
      .search(for: "KSFO")
      .assertListsAirport("KSFO")
      .toggleFavorite("KSFO")

    airports.selectTab(.favorites).assertListsAirport("KSFO").toggleFavorite("KSFO")

    airports.selectTab(.search).selectTab(.favorites).assertDoesNotListAirport("KSFO")
  }

  /**
   With location authorized, Nearest lists the field the device is beside and leaves out the one
   700 NM away.
   */
  @MainActor
  func testListsTheAirportsAroundTheDevice() throws {
    let airports = launchSeededApp(LaunchArgument.authorizedLocation).selectTab(.nearest)

    airports.assertListsAirport("KMSO")
    airports.assertDoesNotListAirport("KSFO")

    airports.openAirport("KMSO")
  }

  /// Refused location, the tab says why it is empty rather than reading as an airport-free world.
  @MainActor
  func testExplainsAnEmptyNearestTabWithoutLocation() throws {
    launchSeededApp(LaunchArgument.deniedLocation)
      .selectTab(.nearest)
      .assertExplainsLocationIsOff()
  }
}
