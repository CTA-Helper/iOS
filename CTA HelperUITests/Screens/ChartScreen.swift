import XCTest
import XCUITestKit

/// The approach plate, with the corrected altitudes laid over it.
struct ChartScreen {
  let app: XCUIApplication

  private var plate: XCUIElement { app.descendant(id: "approachPlate") }

  private var overlay: XCUIElement { app.descendant(id: "correctedAltitudeOverlay") }

  /// The plate finished downloading and drew, with its overlay beside it.
  @discardableResult
  func assertIsShowing() -> Self {
    plate.assertExists(
      "The approach plate never drew",
      timeout: ScaledTimeouts.slowElement
    )
    overlay.assertExists("The plate drew with no corrected altitudes over it")
    return self
  }

  /**
   Dismiss the plate and come back to the fix list underneath it.

   The chart pushes onto the same stack the weather screen does — the trailing pane's own on
   iPad — so there is always something to pop, on both layouts.
   */
  func goBack() -> FixListScreen {
    app.popNavigationStack()
    return FixListScreen(app: app)
  }

  /// The screen said why it has no plate, rather than drawing nothing.
  @discardableResult
  func assertExplainsWhyThereIsNoChart() -> Self {
    app.descendant(id: "chartUnavailable")
      .assertExists("The chart screen neither drew a plate nor said why it could not")
    return self
  }

  /**
   What the overlay reads out for a fix.

   The overlay and the fix list carry the same ``CorrectedAltitude`` announcement as their
   accessibility value, so comparing the two is what proves the column over the plate is showing
   the correction the fix list computed rather than a number of its own.
   */
  func reading(of fix: String) -> String {
    let line = app.descendant(id: "overlayLine-\(fix)")
    line.assertExists("\(fix) is not listed in the corrected altitude overlay")
    return (line.value as? String) ?? ""
  }

  /**
   Hide the corrected altitudes and bring them back.

   The control is a toolbar button rather than anything attached to the panel, so it is in the
   same place whether the panel is showing or not and this presses it twice.
   */
  @discardableResult
  func assertAltitudesCanBeHidden() -> Self {
    let toggle = app.descendant(id: "correctedAltitudesToggle")
      .assertExists("The chart offers no way to get the altitudes off the plate")

    toggle.forceTap()
    overlay.assertHidden("The altitudes are still covering the plate after being hidden")

    toggle.forceTap()
    overlay.assertExists("The altitudes did not come back")
    return self
  }
}
