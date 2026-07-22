import XCTest
import XCUITestKit

/**
 The leading pane: the Favorites / Recents / Nearest / Search tabs over the airports each of
 them lists, and the way through to Settings.
 */
struct AirportListScreen {
  /// The element whose presence means this screen is up.
  static let landingID = "airportTabPicker"

  /// How long a debounced search may take to put its results on screen.
  private static let searchTimeout = ScaledTimeouts.slowElement

  let app: XCUIApplication

  @discardableResult
  func selectTab(_ tab: Tab) -> Self {
    app.descendant(id: "airportTab-\(tab.rawValue)")
      .assertExists("No \(tab.rawValue) tab in the picker")
      .forceTap()
    return self
  }

  /// Type into the Search tab's field. Results arrive debounced, so nothing waits here.
  @discardableResult
  func search(for query: String) -> Self {
    let field = app.searchFields.firstMatch
      .assertExists("No search field on the Search tab")
    field.forceTap()
    field.typeText(query)
    return self
  }

  /// Put the soft keyboard away, so it neither covers the list nor swallows the next tap.
  @discardableResult
  func dismissKeyboard() -> Self {
    app.dismissKeyboardStable()
    return self
  }

  @discardableResult
  func openAirport(_ identifier: String) -> ApproachListScreen {
    airportRow(identifier)
      .assertExists("Airport \(identifier) not found")
      .forceTap()
    return ApproachListScreen(app: app)
  }

  func openSettings() -> SettingsScreen {
    let settings = SettingsScreen(app: app)
    app.descendant(id: "settingsButton")
      .assertExists("No way through to Settings")
      .tap(untilExists: settings.landing, using: XCUIElement.TapStrategy.escalating)
    return settings
  }

  /// Tap an airport's star, favoriting it or dropping it from the favorites.
  @discardableResult
  func toggleFavorite(_ identifier: String) -> Self {
    app.descendant(id: "favoriteButton-\(identifier)")
      .assertExists("No favorite star on \(identifier)'s row")
      .forceTap()
    return self
  }

  @discardableResult
  func assertListsAirport(_ identifier: String) -> Self {
    airportRow(identifier).assertExists("\(identifier) is not listed", timeout: Self.searchTimeout)
    return self
  }

  /**
   Waits out the debounced search before deciding an airport is absent, so a list still on its
   way cannot read as one that left the airport out.
   */
  @discardableResult
  func assertDoesNotListAirport(_ identifier: String) -> Self {
    airportRow(identifier).assertNeverAppears("\(identifier) is listed where it should not be")
    return self
  }

  /// The Nearest tab's account of itself where the pilot has refused location.
  @discardableResult
  func assertExplainsLocationIsOff() -> Self {
    app.descendant(id: "locationOffNotice")
      .assertExists("Nearest offers no explanation with location refused")
    return self
  }

  private func airportRow(_ identifier: String) -> XCUIElement {
    app.descendant(id: "airportRow-\(identifier)")
  }

  /// One of the picker's tabs, by the name the app identifies it with.
  enum Tab: String {
    case favorites, recents, nearest, search
  }
}
