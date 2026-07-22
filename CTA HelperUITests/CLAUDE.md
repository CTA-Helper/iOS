# UI tests

## XCUITestKit

The target links [XCUITestKit][kit] (pinned to `main`). Reach for it before
hand-rolling a wait, a tap or a scroll:

[kit]: https://github.com/RISCfuture/XCUITestKit

- `assertExists` / `assertHidden` / `assertNeverAppears` instead of
  `XCTAssertTrue(x.waitForExistence(timeout:))`. They name the element and the
  timeout themselves, so the message argument only adds what they can't know.
- `descendant(id:)` instead of `descendants(matching: .any).matching(identifier:)`.
- `forceTap()` instead of `tap()`: an iOS 26 Liquid Glass bar reports a control
  as not hittable and swallows a plain tap.
- `tap(untilExists:using: XCUIElement.TapStrategy.escalating)` for a tap that
  opens something — a menu, a sheet, a pushed screen. It confirms and escalates
  rather than tapping once and hoping. (`.escalating` is a static on
  `TapStrategy`, not on the array, so it needs qualifying.)
- `scrollToElement(_:direction:maxSwipes:)` instead of counting `swipeUp()`s: it
  stops when the element's *center* clears the home indicator, so the tap after
  it lands.
- `clearAndType(_:app:doneButtonIdentifier:)` for the minimums field — it asserts
  the keyboard surfaced, and reads the value back.
- Prefer the synchronous helpers. `tapStable`, `tap(untilExists:maxAttempts:)`
  and `Retry.untilVerified` are `async` and would make every screen method and
  test `async` to reach them.

`ScaledTimeouts` reads `XCUITEST_TIMEOUT_MULTIPLIER` and defaults to 1. The
`UI Tests` and `Screenshots` test plans both set it to 3, which is what gives a
hosted CI runner — several times slower than local hardware — room to finish.

## Launch arguments

Settle everything a test needs on the command line — it drives the app from
another process and cannot reach into it. Each is a bare flag: `UserDefaults`
claims `-key value` pairs off the command line and would register a test's own
arguments as app settings. `Support/AppLaunch.swift` names them.

- `-uiTestSeed` — in-memory store holding KMSO (favorited) and KSFO.
- `-uiTestNavDataBundled` / `-uiTestNavDataUnreachable` — point
  `NavDataManifest.url` / `.dataURL` at `UITestFixtures/` or at nothing, to
  drive the first-run download and its failure. The fixture is committed as
  plain JSON and gzipped at launch, since the loader gunzips what it downloads.
- `-uiTestLocationAuthorized` / `-uiTestLocationDenied` — inject a
  `FixedLocationStreamer`. It is the only way to reach the Nearest tab: a test
  cannot answer the system permission alert.

## Determinism

- Don't let a test depend on live weather. Under any `-uiTest…` flag,
  `CTA_HelperApp` injects a `METARLoader(serving:)` with one fixed observation
  and a `NetworkMonitor(reporting: true)`, and discards the persisted settings so
  one test's rounding or favorites cannot decide another's outcome.
- Don't seed a temperature into that observation — it reports none so
  `FixListView`'s auto-fill no-ops and the seeded 0 °C default holds, which is
  what `testCorrectsAnApproachFromTheAirportList` asserts against.
- Wait for a row before swiping toward it. A row the list has not drawn yet is
  not a row below the fold, and a scroll aimed at one goes straight past it —
  `FixListScreen.scroll(to:_:describedAs:)` probes first for that reason, then
  hands off to `scrollToElement`.

## Two layouts, one suite

The suite runs on iPhone and iPad, and `ContentView` draws them differently: a
single drill-down stack on iPhone, two panes at once on iPad. Every failure that
has ever been iPad-only came from a helper reaching for the wrong one of several
things that all exist at once.

- **Several navigation bars coexist.** Each pane has one, a sheet presented over
  them adds another, and the ones behind stay in the hierarchy. Neither
  `navigationBars.firstMatch` nor `.last` is reliably the one wanted — the first
  is the sidebar's, which is how `popNavigationStack()` came to tap the airport
  list's button from inside the settings sheet. Use
  `app.navigationBar(above:)`, which picks the bar geometrically.
- **Don't pop what is already beside you.** On iPad the fix list is the trailing
  pane and the approaches are in the leading one, so `FixListScreen.goBack()`
  must do nothing: popping unwinds the *leading* pane and takes the approach
  list with it. It checks `ApproachListScreen.isShowing` first.
- **Pop a pushed screen with the back-swipe, not a back button.** A drag from the
  screen's own leading edge pops whichever stack it belongs to, wherever that
  stack is drawn. `AboutScreen.goBack()` does this.
- **A sheet is a form sheet on iPad.** It floats over the split view, and a drag
  on its bar does not always carry it off; tapping outside it does.
  `SettingsScreen.close()` tries both, in that order.
- **`XCUIElement.frame` raises when the element is not in the hierarchy** rather
  than returning zero, so check `exists` before measuring one.

## Make a control prove it moved

A tap that lands on the wrong thing usually does nothing at all, and nothing is
indistinguishable from success until an assertion three screens later reads a
number it cannot explain. Every helper that changes a control now reads the
control back:

- `toggleExtrapolation` checks the switch's `value` flipped. A `Toggle` in a
  `Form` publishes the whole row, so a centre tap lands on the label; the switch
  is at the trailing edge.
- `selectTransition` checks the picker moved, and matches its options as
  `app.buttons`. A collapsed menu picker carries the selected name as its own
  label, so an `.any` match resolves to the picker before the menu has opened.
- `AboutScreen.goBack` checks Settings came back.

This is also why `testExtrapolationChangesACorrectionAboveTheTable` was
unfixable for so long: the toggle never moved, so it compared a value with
itself and blamed the correction engine.

## Assertions

- Don't assert a rounding convention changes a correction without checking the
  raw value isn't a multiple of 100 — both conventions agree there.
  `CorrectionSettingsUITests` enters 4,000 ft for that reason.
- Don't reach for `clearAndType` in `assertRetypingReplacesMinimums`. It clears
  the field first, which is the behaviour that test exists to prove, so it would
  pass whatever the field did.
- A screen object owns its elements and its waiting, and every method that
  navigates returns the next screen's object. Keep what is being proved in the
  test body and how it is checked on the object.

## Screenshots

`GenerateScreenshots` captures the App Store set with fastlane's `snapshot`, off
the same seeded store the flow tests use. `bundle exec fastlane screenshots`
runs it; `fastlane/Snapfile` names the devices and points at the `Screenshots`
test plan, which selects this class alone. The `UI Tests` plan CI runs skips it
in turn, so neither plan pays for the other's work.

- It asserts only to synchronise a capture with the screen it means to
  photograph. Reuse the screen objects' assertions for that rather than adding
  waits of your own, and don't add an assertion a flow test should be making.
- Don't navigate backwards in it. On iPad the airport list, its approaches and
  the fix list are laid out across two panes at once, where `popNavigationStack`
  has no single answer; each chapter runs forwards from its own launch instead,
  so one flow serves iPhone and iPad alike.
- The screens that fill only the leading pane — the airport picker and the
  approach list — are captured on iPhone alone. On iPad they leave the detail
  pane showing the prompt to select an approach, which is a screenshot mostly of
  empty space. `XCTSkipIf(isSplitViewLayout)` is what leaves them out.
- The name decides where a shot lands on the product page, not when it was
  taken, so the numbering and the capture order disagree on purpose. A device
  that skips a shot leaves a gap in the numbering, which is harmless.
- Nothing scrolls before a capture. A screen photographed part-way down reads as
  a fragment on the product page, and scrolling away from the top of the fix list
  puts the weather link out of reach of the tap that opens it.
- `setupSnapshot(_:)` has to run between the app's creation and its launch — it
  appends launch arguments of its own. That is what `launchSeededApp`'s
  `preparedBy:` seam is for. Pass a closure capturing nothing: a main
  actor-isolated function type is implicitly `@Sendable`, so a method reference
  off the test case will not convert.
- `Support/SnapshotHelper.swift` is generated third-party source. Replace it with
  a newer `fastlane snapshot init` copy rather than editing it, restoring the
  `swiftlint:disable`/`enable` pair and the `swift-format-ignore-file` marker.
