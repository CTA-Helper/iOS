import XCTest
import XCUITestKit

/// The corrected fixes, in the trailing pane.
struct FixListScreen {
  /// The accessibility label the corrected minimums carry until the pilot enters a DA or MDA.
  private static let noCorrectedMinimums = "No corrected minimums"

  /// The identifier of the key that closes the number pad, which has no return key of its own.
  private static let dismissKeyboardID = "dismissKeyboard"

  /// How many swipes it may take to reach the end of the longest approach in the seeded data.
  private static let maximumScrolls: UInt = 5

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
   Below the restriction, the coded fixes replace the notice. A corrected fix shows two
   altitudes — the published one it supersedes and the value that replaces it — where an
   uncorrected one shows a single published altitude.

   The initial segment opens on `CHARL`, the first of the approach's transitions by name, so
   that is the transition whose legs are on screen to check.
   */
  func assertCorrectsCodedFixes() {
    fixRow("CHARL").assertExists("Corrected fixes did not appear")
    XCTAssertFalse(notice.exists, "Notice still shown below the restriction")

    let altitudes = fixAltitudes("CHARL")
    XCTAssertEqual(
      altitudes.count,
      2,
      "Expected CHARL’s published altitude beside its correction, got: \(altitudes)"
    )
    XCTAssertTrue(altitudes.contains("10,000"), "CHARL’s published altitude is not shown")
    XCTAssertFalse(
      altitudes.allSatisfy { $0 == "10,000" },
      "CHARL’s published altitude was not corrected to a different value"
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
   The altitudes a fix's row shows: the published value alone, or the published value beside
   the correction that supersedes it.
   */
  func altitudes(of identifier: String) -> [String] {
    scroll(to: fixRow(identifier), .up, describedAs: "Fix \(identifier)")
    return fixAltitudes(identifier)
  }

  /// A fix whose published altitude is struck through by a corrected one shows both values.
  @discardableResult
  func assertCorrects(_ identifier: String) -> Self {
    XCTAssertEqual(
      altitudes(of: identifier).count,
      2,
      "\(identifier) shows one altitude, so it was not corrected"
    )
    return self
  }

  /// A fix outside the correction shows the single altitude the procedure publishes.
  @discardableResult
  func assertDoesNotCorrect(_ identifier: String) -> Self {
    XCTAssertEqual(
      altitudes(of: identifier).count,
      1,
      "\(identifier) shows a second altitude, so it was corrected"
    )
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

  /**
   The altitude values shown on a fix's row. SwiftUI propagates an accessibility identifier
   to every text beneath it, so the altitude view's identifier names each value it renders.
   */
  private func fixAltitudes(_ identifier: String) -> [String] {
    let values = app.staticTexts
      .matching(identifier: "fixAltitude-\(identifier)")
      .allElementsBoundByIndex
    // `XCUIElement.label` is main actor-isolated, so `\.label` cannot form a key path.
    // swiftlint:disable:next prefer_key_path
    return values.map { $0.label }
  }

  /// One of the methods ENR 1.8 5.f offers, by the name the app identifies it with.
  enum Method: String {
    case allSegments, individualSegments
  }
}
