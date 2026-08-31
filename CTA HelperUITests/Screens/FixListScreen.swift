import XCTest
import XCUITestKit

/// The corrected fixes, in the trailing pane.
struct FixListScreen {
  /// The accessibility label the corrected minimums carry until the pilot enters a DA or MDA.
  private static let noCorrectedMinimums = "No corrected minimums"

  /// The altitude the seeded approach publishes at `CHARL`, which a correction moves it off.
  private static let charlPublishedFt = "10,000"

  /// The identifier of the key that closes the number pad, which has no return key of its own.
  private static let dismissKeyboardID = "dismissKeyboard"

  /**
   How many swipes it may take to reach the end of the longest approach in the seeded data.

   A segment that corrects nothing prints a footer saying why, and a fix ENR 1.8 never corrects
   prints a line of its own, so the list is taller than the fixes alone make it.
   */
  private static let maximumScrolls: UInt = 7

  /// How long the list may take to draw a row that is already on screen.
  private static let renderProbeSeconds: TimeInterval = 1

  let app: XCUIApplication

  /// The corrected DA or MDA as it reads on screen, or the placeholder standing in for none.
  var correctedMinimumsLabel: String { correctedMinimums.label }

  private var notice: XCUIElement { app.staticTexts["noCorrectionNotice"] }

  private var correctedMinimums: XCUIElement { app.staticTexts["correctedMinimums"] }

  private var minimumsField: XCUIElement { app.textFields["minimumsField"] }

  /// The screen the approach's name titles, once it has been pushed.
  @discardableResult
  func assertIsShowing(_ approachName: String) -> Self {
    app.navigationBars[approachName]
      .assertExists(
        "Fix list for \(approachName) did not appear",
        timeout: ScaledTimeouts.slowElement
      )
    return self
  }

  /// Open the METAR the reported temperature was filled from.
  func openWeather() -> WeatherScreen {
    app.descendant(id: "weatherLink")
      .assertExists("No link to the reporting station's METAR")
      .tap(
        untilExists: app.descendant(id: "weatherScreen"),
        using: XCUIElement.TapStrategy.escalating
      )
    return WeatherScreen(app: app)
  }

  @discardableResult
  func goBack() -> ApproachListScreen {
    let approaches = ApproachListScreen(app: app)
    // On iPad the fix list is the trailing pane and the approaches are already beside it in the
    // leading one, so there is nothing to pop. Popping anyway unwinds the *leading* pane to the
    // airport picker and takes the approach list with it.
    if !approaches.isShowing { app.popNavigationStack() }
    return approaches
  }

  /// Warmer than the airport's restriction, the fixes give way to a single note.
  func assertNoCorrectionNecessary() {
    assertIsShowing("RNAV (GPS) Y RWY 12")
    notice.assertExists(
      "No “No correction necessary” notice at a temperature above the restriction"
    )
    fixRow("CHARL").assertNeverAppears("Fixes shown at a temperature above the restriction")
  }

  /// Drag the temperature slider well below the airport's restriction.
  @discardableResult
  func reportColdTemperature() -> Self {
    let slider = app.sliders["reportedTemperatureSlider"]
      .assertExists("Temperature slider not found")
    // 0.25 of the −50…+10 range is −35 °C.
    slider.adjust(toNormalizedSliderPosition: 0.25)
    return self
  }

  /**
   Below the restriction, the coded fixes replace the notice, and a corrected fix reads out the
   value that supersedes its published one rather than the published one itself.

   The initial segment opens on `CHARL`, the first of the approach's transitions by name, so
   that is the transition whose legs are on screen to check.
   */
  func assertCorrectsCodedFixes() {
    fixRow("CHARL").assertExists("Corrected fixes did not appear")
    XCTAssertFalse(notice.exists, "Notice still shown below the restriction")

    let flown = reading(of: "CHARL")
    XCTAssertFalse(flown.isEmpty, "CHARL’s row reads out no altitude at all")
    XCTAssertFalse(
      flown.contains(Self.charlPublishedFt),
      "CHARL still reads out its published altitude, so it was not corrected: \(flown)"
    )
  }

  /**
   Choose a transition from the initial segment's header menu, and prove the menu took it.

   The options are matched as buttons rather than as any descendant: a collapsed menu picker
   carries the selected transition's name as its own label, so an `.any` match resolves to the
   picker itself before the menu has opened — the tap that follows then re-taps the picker and
   selects nothing. That fails silently, leaving the assertion that follows to report a missing
   fix row rather than a menu that never opened.
   */
  func selectTransition(_ name: String) {
    let picker = app.descendant(id: "transitionPicker-initial")
      .assertExists("No transition picker heading the initial segment")
    let shows = NSPredicate(format: "value == %@ OR label CONTAINS %@", name, name)
    guard !shows.evaluate(with: picker) else { return }

    // A transition is named by the procedure rather than by localized copy, so matching its name
    // is resilient; the identifier is matched too, for wherever SwiftUI carries it into the menu.
    let option = app.buttons.matching(
      NSPredicate(format: "identifier == %@ OR label == %@", "transitionOption-\(name)", name)
    ).firstMatch

    picker.tap(untilExists: option, using: XCUIElement.TapStrategy.escalating)
    option.assertExists("Transition \(name) is not offered").forceTap()

    XCTAssertTrue(
      picker.waitFor(shows),
      "Choosing \(name) left the transition picker reading “\(picker.label)”"
    )
  }

  /**
   Choose between correcting every segment and correcting only the ones the CTA list marks.

   The picker heads the list, so it may well be above the fold after reading a fix further down
   the approach.
   */
  @discardableResult
  func selectCorrectionMethod(_ method: Method) -> Self {
    let picker = app.descendant(id: "correctionMethodPicker")
    scroll(to: picker, .down, describedAs: "Correction method picker")

    let option = app.descendant(id: "correctionMethodOption-\(method.rawValue)")
    picker.tap(untilExists: option, using: XCUIElement.TapStrategy.escalating)
    option.assertExists("\(method.rawValue) is not offered").forceTap()
    return self
  }

  /**
   The section lists one transition at a time: the legs of the chosen one, and none of the legs
   flown only on the other.
   */
  func assertListsFix(_ shown: String, butNot hidden: String) {
    fixRow(shown).assertExists("\(shown) is not listed after choosing its transition")
    XCTAssertFalse(fixRow(hidden).exists, "\(hidden) is still listed from the other transition")
  }

  /**
   The altitude a fix's row reads out: the corrected value where a correction applies, and the
   published one where none does.

   The row is a single accessibility element, so the value it carries is the whole of what the
   correction came to — and the only part of it a test can see. What was published and what was
   added are `AXCustomContent`, which XCUITest does not expose, so a change in the correction is
   proved by the reading moving rather than by counting the values on the row.
   */
  func reading(of identifier: String) -> String {
    let row = fixRow(identifier)
    scroll(to: row, .up, describedAs: "Fix \(identifier)")
    return (row.value as? String) ?? ""
  }

  /// The segment said why it corrected nothing, in the footer under the legs it left alone.
  @discardableResult
  func assertExplains(_ segment: Segment) -> Self {
    app.descendant(id: "segmentNote-\(segment.rawValue)")
      .assertExists("The \(segment.rawValue) segment gives no reason for correcting nothing")
    return self
  }

  /**
   Scroll down to the minimums pseudo-fix that closes the final segment, and type a DA/MDA
   into it.
   */
  @discardableResult
  func enterMinimums(_ altitudeFt: String) -> Self {
    let field = minimumsField
    scroll(to: field, .up, describedAs: "Minimums field")
    XCTAssertEqual(
      correctedMinimums.label,
      Self.noCorrectedMinimums,
      "Minimums corrected before any were entered"
    )
    field.clearAndType(altitudeFt, app: app, doneButtonIdentifier: Self.dismissKeyboardID)
    return self
  }

  /**
   The entered minimums are corrected the way every other fix is: to a value of their own,
   higher than what was entered.
   */
  func assertCorrectsMinimums(enteredFt: String) {
    let corrected = correctedMinimums
    XCTAssertNotEqual(
      corrected.label,
      Self.noCorrectedMinimums,
      "Entered minimums were not corrected"
    )
    XCTAssertNotEqual(
      corrected.label.replacingOccurrences(of: ",", with: ""),
      enteredFt,
      "Corrected minimums match the entered value, so no correction was applied"
    )
  }

  /**
   Correcting a mistyped DA or MDA replaces it rather than appending to it: the field selects its
   contents when it takes focus. Appending would turn 4,520 into 45,203,200 and present that
   as a minimum, so the flow is worth driving even though the field implements it on its own.

   Typed raw rather than through `clearAndType`, which clears the field first — the very thing
   under test here, so using it would prove nothing.
   */
  func assertRetypingReplacesMinimums(_ altitudeFt: String) {
    let field = minimumsField
    field.forceTap()
    field.typeText(altitudeFt)
    app.dismissKeyboardStable(doneButtonIdentifier: Self.dismissKeyboardID)
    XCTAssertEqual(
      (field.value as? String)?.replacingOccurrences(of: ",", with: ""),
      altitudeFt,
      "Retyped minimums appended to the entered value instead of replacing it"
    )
  }

  private func fixRow(_ identifier: String) -> XCUIElement {
    app.descendant(id: "fixRow-\(identifier)")
  }

  /**
   Bring an element into view, centred clear of the home indicator so a tap on it lands.

   The probe comes first on purpose: a row the list has not drawn yet is not a row below the
   fold, and a scroll aimed at one goes straight past it.
   */
  private func scroll(
    to element: XCUIElement,
    _ direction: XCUIApplication.ScrollDirection,
    describedAs description: String
  ) {
    _ = element.wait(scaledSeconds: Self.renderProbeSeconds)
    app.scrollToElement(element, direction: direction, maxSwipes: Self.maximumScrolls)
    element.assertExists("\(description) not found after scrolling the approach")
  }

  /// One of the methods ENR 1.8 5.f offers, by the name the app identifies it with.
  enum Method: String {
    case allSegments, individualSegments
  }

  /// One of the four segments ENR 1.8 5.f divides an approach into, by the name it is coded under.
  enum Segment: String {
    case initial, intermediate, final, missed
  }
}
