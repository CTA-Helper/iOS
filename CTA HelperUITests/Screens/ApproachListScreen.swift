import XCTest
import XCUITestKit

/// The airport's approaches, pushed alongside the airport list in the leading pane.
struct ApproachListScreen {
  let app: XCUIApplication

  /**
   Whether the approach list is on screen.

   On iPad it still is while the fixes show: the approaches head the leading pane and the fix
   list fills the trailing one, so both are visible at once.
   */
  var isShowing: Bool {
    app.descendants(matching: .any)
      .matching(NSPredicate(format: "identifier BEGINSWITH %@", "approachRow-"))
      .firstMatch
      .exists
  }

  @discardableResult
  func openApproach(_ identifier: String) -> FixListScreen {
    approachRow(identifier)
      .assertExists("Approach \(identifier) not found")
      .forceTap()
    return FixListScreen(app: app)
  }

  @discardableResult
  func assertListsApproach(_ identifier: String) -> Self {
    approachRow(identifier).assertExists("Approach \(identifier) is not listed")
    return self
  }

  @discardableResult
  func goBack() -> AirportListScreen {
    app.popNavigationStack()
    return AirportListScreen(app: app)
  }

  private func approachRow(_ identifier: String) -> XCUIElement {
    app.descendant(id: "approachRow-\(identifier)")
  }
}
