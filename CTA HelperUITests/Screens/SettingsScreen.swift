import XCTest
import XCUITestKit

/// The settings sheet: the correction preferences, the imported cycle, and the About screen.
struct SettingsScreen {
  /// How many swipes it may take to reach the foot of the settings form on the smallest screen.
  private static let maximumScrolls: UInt = 6

  /// How many pulls the sheet may need: a fling short of the threshold leaves it where it was.
  private static let maximumCloseAttempts = 3

  let app: XCUIApplication

  /// The element whose presence means the sheet is up, and whose absence means it is gone.
  var landing: XCUIElement { app.descendant(id: "settingsScreen") }

  /// The bar belonging to the sheet, not to the split view pane still visible behind it on iPad.
  private var sheetNavigationBar: XCUIElement { app.navigationBar(above: landing) }

  /// Whether the sheet has gone, giving the dismissal it may still be animating time to finish.
  private var hasLeft: Bool {
    landing.waitForNonExistence(timeout: ScaledTimeouts.short)
  }

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

  /**
   Open About, scrolling the form down to reach it.

   About is the last section of a form that has grown past a phone screen — the correction
   preferences, the imported cycle, and what the downloaded charts occupy all sit above it — so
   the link is routinely below the fold and a tap aimed at where it used to be lands on nothing.
   */
  func openAbout() -> AboutScreen {
    let about = AboutScreen(app: app)
    let link = app.descendant(id: "aboutLink")
    app.scrollToElement(link, direction: .up, maxSwipes: Self.maximumScrolls)
    link
      .assertExists("No way through to About")
      .tap(untilExists: about.landing, using: XCUIElement.TapStrategy.escalating)
    return about
  }

  /**
   Dismiss the sheet by dragging its navigation bar down, which is the only way off it: a
   settings sheet the pilot pulls down has no button of its own to close it.

   A pull that falls short of the dismissal threshold slides the sheet back to where it was
   rather than carrying it off, so the drag is repeated, and where the sheet floats as a card
   the app behind it is tapped between tries. Which layout is showing is read before the first
   drag: a sheet caught part-way down is inset from the top on either device, so a frame taken
   after a pull that failed would call an iPhone's full-screen sheet a card and tap a point
   that is still inside it.
   */
  @discardableResult
  func close() -> AirportListScreen {
    let sheet = landing.assertExists("Settings is not showing to be closed").frame
    let behindTheSheet = pointBehind(sheet)

    for _ in 1...Self.maximumCloseAttempts {
      pullDown()
      if hasLeft { break }
      behindTheSheet?.tap()
      if hasLeft { break }
    }

    landing.assertHidden("Settings stayed up after being pulled down")
    return AirportListScreen(app: app)
  }

  /// Drag the sheet's own navigation bar downwards, which is how the pilot puts it away.
  private func pullDown() {
    sheetNavigationBar
      .assertExists("Settings has no navigation bar to drag")
      .swipeDown(velocity: .fast)
  }

  /**
   Where to tap to dismiss a sheet that floats as a card, or `nil` for one that fills the screen.

   On iPad the sheet is a card over the split view, and tapping the dimmed app behind it carries
   it off when a drag on its bar does not. On iPhone it covers the screen, so there is no
   outside to tap and the drag is the whole story.
   */
  private func pointBehind(_ sheet: CGRect) -> XCUICoordinate? {
    guard sheet.minY > app.frame.minY + 1 else { return nil }

    return app.coordinate(withNormalizedOffset: .zero)
      .withOffset(CGVector(dx: sheet.midX, dy: sheet.minY / 2))
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

   Hunting for a back button does not survive both layouts: the panes' bars coexist behind the
   sheet, and `popNavigationStack(in:)` tells those two apart by width, which says nothing
   about a third bar floating over them. Dragging from the screen's own leading edge pops the
   stack the screen belongs to, and a sheet is inset from the screen's edge on either layout,
   so the drag starts inside the sheet rather than on the pane behind it.
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
