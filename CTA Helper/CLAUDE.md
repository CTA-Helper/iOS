# App target

## Navigation

- Wrap each pane's content in its own `NavigationStack`. `ContentView`
  branches on `horizontalSizeClass` (two panes on iPad, one stack on iPhone)
  rather than relying on `NavigationSplitView` collapse.
- Don't put a `NavigationLink` in a bare split view column — it overwrites the
  column, desyncs the selection, and kills navigation after one Back tap.
- Push both panes off the same `Airport?` / `Approach?` selection bindings
  via `.navigationDestination(item:)`, keeping `AirportList` and
  `ApproachListView` plain `List(selection:)`. Guarded by
  `testWeatherPushesOverTheFixListWithoutUnsettlingTheStack`.

## Accessibility identifiers

- Don't nest `.accessibilityIdentifier` inside another one on a plain layout
  container: the outer one carries down the whole subtree and renames the inner
  element. `AirportRow` identifies its label column rather than the row, so the
  favorite star keeps an identifier of its own. A `List` / `Form` doesn't
  propagate this way, so `settingsScreen` over `roundingPicker` is fine.
- A control a UI test drives gets an identifier; a picker's options get one each
  (`roundingOption-…`, `transitionOption-…`), since a test must never match on
  localized copy.
- A row dense enough to merge is the other shape. `FixRow` is one accessibility
  element (`children: .ignore`) and identifies itself, so `fixRow-<id>` names the
  whole row and there is nothing beneath it left to name — the opposite of
  `AirportRow`, which identifies its label column precisely so the star keeps an
  identifier of its own. A merged row is read through its `label` and `value`;
  its `accessibilityCustomContent` is not reachable from XCUITest at all.

## Location

- Don't read `\.locationStreamer` outside the Nearest tab. Its default builds a
  `CoreLocationStreamer`, which asks for permission — `AirportSidebar` resolves
  `CLLocationManager.locationServicesEnabled()` directly for that reason, so the
  alert waits until the pilot opens the tab that needs it.
- `NearestView` reads authorization off the streamer rather than its own
  `CLLocationManager`, which is what lets a test inject one.

## Test hooks

- `Support/UITestConfiguration.swift` is the only place that reads the
  `-uiTest…` launch arguments; `CTA_HelperApp.init()` is the only place that
  acts on them. Keep both of those true — a test-mode branch anywhere else is a
  branch the app can take in a pilot's hands.
- None of it reaches a release build. `UITestConfiguration` is `#if DEBUG`, and
  the `#else` half supplies constant stubs — `isRunning` is `false`,
  `NavDataFixture` is uninhabited — so call sites need no `#if` of their own,
  nothing reads `ProcessInfo.arguments`, and no launch argument can redirect
  where the nav data comes from. `EXCLUDED_SOURCE_FILE_NAMES[config=Release]`
  keeps `UITestFixtures/` out of the bundle to match.
- `-navDataBaseURL <url>` is the one argument that carries a value. It is
  DEBUG-only, read in `UITestConfiguration` too, and points
  `PrebuiltNavDataStore` at a local server (`python3 -m http.server` over the
  builder's `out/`). It doesn't start with `-uiTest`, so it leaves
  `isRunning` false and the app on its real stores.
- A UI test runs the same generations on disk a pilot's app does, in a
  per-process `UITestConfiguration.storeLayout`; `-uiTestSeed` installs its
  airports as a generation before the store is opened read-only.
- `Support/PreviewSupport.swift` is `#if DEBUG` for the same reason, so every
  `#Preview` block is wrapped in `#if DEBUG` too — the macro expands and
  type-checks its body in any configuration, whatever `ENABLE_PREVIEWS` says,
  so an unguarded preview would drag the sample data back into the binary.
  Release sets `ENABLE_PREVIEWS = NO` to match.
