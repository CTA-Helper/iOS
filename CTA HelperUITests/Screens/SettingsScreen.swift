import XCTest
import XCUITestKit

/// The settings sheet: the correction preferences, the imported cycle, and the About screen.
struct SettingsScreen {
  let app: XCUIApplication

  /// The element whose presence means the sheet is up, and whose absence means it is gone.
  var landing: XCUIElement { app.descendant(id: "settingsScreen") }

  /// The bar belonging to the sheet, not to the split view pane still visible behind it on iPad.
  private var sheetNavigationBar: XCUIElement { app.navigationBar(above: landing) }

  @discardableResult
  func assertIsShowing() -> Self {
    landing.assertExists("Settings did not appear")
    return self
  }

  @discardableResult
  func selectRounding(_ rounding: Rounding) -> Self {
    let option = app.descendant(id: "roundingOption-\(rounding.rawValue)")
    app.descendant(id: "roundingPicker")
      .assertExists("No rounding picker in Settings")
      .tap(untilExists: option, using: XCUIElement.TapStrategy.escalating)
    option.assertExists("\(rounding.rawValue) is not offered").forceTap()
    return self
  }

  /**
   Flip the extrapolation switch, and prove it flipped.

   A `Toggle` in a `Form` publishes the whole row as one switch element, so a tap at its centre
   lands on the label and changes nothing — silently, leaving the test that follows to read two
   identical altitudes and blame the correction engine. The control itself sits at the trailing
   edge, and reading `value` back is what turns a tap that missed into a failure here rather
   than a puzzle three screens later.
   */
  @discardableResult
  func toggleExtrapolation() -> Self {
    let toggle = app.switches["extrapolateToggle"]
      .assertExists("No extrapolation toggle in Settings")
    let before = toggle.value as? String

    toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
    XCTAssertTrue(
      toggle.waitFor(NSPredicate(format: "value != %@", before ?? "")),
      "Tapping the extrapolation toggle left it \(before ?? "unset")"
    )
    return self
  }

  /// The AIRAC cycle the imported nav data came from, as the row reports it.
  @discardableResult
  func assertReportsCycle(_ airacCycle: String) -> Self {
    let row = app.descendant(id: "airacCycle").assertExists("Settings names no imported cycle")
    XCTAssertEqual(row.value as? String, airacCycle, "Settings reports another cycle")
    return self
  }

  /// Settings goes on saying the data is out of date, which is what a deferred update leaves.
  @discardableResult
  func assertReportsAnExpiredCycle() -> Self {
    app.descendant(id: "cycleExpired")
      .assertExists("Settings does not say the imported cycle has expired")
    return self
  }

  func openAbout() -> AboutScreen {
    let about = AboutScreen(app: app)
    app.descendant(id: "aboutLink")
      .assertExists("No way through to About")
      .tap(untilExists: about.landing, using: XCUIElement.TapStrategy.escalating)
    return about
  }

  /**
   Dismiss the sheet by dragging its navigation bar down, which is the only way off it: a
   settings sheet the pilot pulls down has no button of its own to close it.
   */
  @discardableResult
  func close() -> AirportListScreen {
    landing.assertExists("Settings is not showing to be closed")
    sheetNavigationBar
      .assertExists("Settings has no navigation bar to drag")
      .swipeDown(velocity: .fast)
    if landing.exists { tapBehindTheSheet() }

    landing.assertHidden("Settings stayed up after being pulled down")
    return AirportListScreen(app: app)
  }

  /**
   Dismiss an iPad form sheet by tapping the dimmed app behind it.

   On iPad the sheet is a card floating over the split view, and a drag on its bar does not
   always carry it off; tapping outside always does. On iPhone the sheet covers the screen, so
   there is no outside to tap and the drag above has already done the job — hence the guard.
   */
  private func tapBehindTheSheet() {
    let sheet = landing.frame
    guard sheet.minY > app.frame.minY + 1 else { return }

    app.coordinate(withNormalizedOffset: .zero)
      .withOffset(CGVector(dx: sheet.midX, dy: sheet.minY / 2))
      .tap()
  }

  /// One of the rounding conventions ENR 1.8 5.e permits, by the app's name for it.
  enum Rounding: String {
    case nearestHundred, roundUp
  }
}

/// What the app is, pushed from Settings.
struct AboutScreen {
  let app: XCUIApplication

  /// The element whose presence means this screen is up.
  var landing: XCUIElement { app.descendant(id: "aboutScreen") }

  @discardableResult
  func assertNamesItsVersion() -> Self {
    landing.assertExists("About screen did not appear")
    let version = app.descendant(id: "appVersion").assertExists("About names no version")
    XCTAssertFalse(version.label.isEmpty, "About shows an empty version")
    return self
  }

  /**
   Pop back to Settings with the interactive back-swipe.

   Hunting for a back button does not survive both layouts: several navigation bars coexist
   behind the sheet, and tapping the wrong one's first button silently does something else —
   which is exactly what the shared `popNavigationStack()` did here, unnoticed until `close()`
   began asserting Settings was still there to close. Dragging from the screen's own leading
   edge pops whichever stack the screen belongs to, wherever that stack is drawn.
   */
  @discardableResult
  func goBack() -> SettingsScreen {
    let bounds = landing.assertExists("About is not showing to leave").frame
    let origin = app.coordinate(withNormalizedOffset: .zero)
    origin
      .withOffset(CGVector(dx: bounds.minX + 2, dy: bounds.midY))
      .press(
        forDuration: 0.05,
        thenDragTo: origin.withOffset(CGVector(dx: bounds.maxX - 2, dy: bounds.midY))
      )

    let settings = SettingsScreen(app: app)
    settings.landing.assertExists("Settings did not come back after leaving About")
    return settings
  }
}
