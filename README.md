# CTA Helper

[![CI](https://github.com/CTA-Helper/iOS/actions/workflows/ci.yml/badge.svg)](https://github.com/CTA-Helper/iOS/actions/workflows/ci.yml)
[![Lint](https://github.com/CTA-Helper/iOS/actions/workflows/lint.yml/badge.svg)](https://github.com/CTA-Helper/iOS/actions/workflows/lint.yml)
[![App Store](https://img.shields.io/itunes/v/6795019635.svg)](https://apps.apple.com/us/app/cta-helper/id6795019635)
[![Platform](https://img.shields.io/badge/platform-iOS-lightgrey.svg)](https://developer.apple.com/ios/)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

CTA Helper applies FAA cold temperature altitude corrections to the altitudes of
an instrument approach, following the method published in AIP ENR 1.8.

A barometric altimeter assumes a standard atmosphere. In air colder than
standard the column is denser, the altimeter reads high, and the aircraft is
lower than it indicates. At a Cold Temperature Restricted Airport that means
computing a correction for every published altitude on the approach and adding
it — segment by segment, off a temperature read from a METAR, in the cockpit.
The app does that arithmetic.

## ⚠️ Disclaimer

This app is for situational awareness and planning only. **It is not for primary
navigation.** Always verify every correction independently, and read the DA/MDA
and all altitudes from the official approach plate before you fly them.

## Getting started

Swift 6.3 under complete strict concurrency, targeting iOS 26.5. Clone the
repository, open `CTA Helper.xcodeproj` in Xcode 26 or newer, and build — Xcode
resolves the package dependencies on first open, and nothing else needs
configuring to run the app in a simulator.

| Package | Used for |
| --- | --- |
| [SwiftMETAR](https://github.com/RISCfuture/SwiftMETAR) | Decoding METARs |
| [GzipSwift](https://github.com/1024jp/GzipSwift) | Inflating the nav data document |
| [sentry-cocoa](https://github.com/getsentry/sentry-cocoa) | Crash and error reporting |
| [XCUITestKit](https://github.com/RISCfuture/XCUITestKit) | UI test scaffolding |

The release tooling is the only part with a toolchain of its own — Ruby 4.0.6
and the `cta` gemset, per `.ruby-version` and `.ruby-gemset`:

```sh
bundle install
```

## Architecture

Three targets: **CTA Helper**, **CTA HelperTests** (unit tests, written in Swift
Testing), and **CTA HelperUITests** (end-to-end tests, built on
[XCUITestKit](https://github.com/RISCfuture/XCUITestKit)).

The app source is grouped by concern:

| Directory | Holds |
| --- | --- |
| `Corrections/` | The correction engine. No SwiftData, no SwiftUI. |
| `Models/` | The SwiftData `@Model` types — airports, approaches, fixes — and the store holding them. |
| `NavData/` | Downloading, verifying, and importing an AIRAC cycle. |
| `Charts/` | Fetching and caching approach plates. |
| `Weather/` | Fetching and decoding METARs. |
| `Location/` | Resolving nearest airports, on device. |
| `Intents/` | App Intents: what the system holds an airport and an approach as. |
| `Views/` | SwiftUI. |
| `Support/` | Settings, formatting, and the rest of the shared odds and ends. |

Physical values follow one naming rule throughout, so that a bare number is
never ambiguous about its unit; `CLAUDE.md` states it.

### Correction engine

`Corrections/` implements the ICAO Doc 8168 linear correction formula and the
FAA ENR 1.8 rules for which segments and altitudes it applies to. It is kept
free of SwiftData and SwiftUI — `CorrectableFix` is the protocol that decouples
it from the model layer — so it can be tested against the published worked
examples directly.

### Nav data

Approach and fix data is published as a versioned AIRAC cycle at
[CTA-Helper/Navdata](https://github.com/CTA-Helper/Navdata). On launch the app
checks whether the imported cycle has expired, and offers the current one when it
has — to download now, or to defer and fly the stored cycle for the rest of the
launch. Downloading polls the release manifest, fetches the gzipped document,
**verifies it against the SHA-256 and byte counts the manifest publishes**, and
imports it into SwiftData in bounded transactions. The import replaces the
store's airports, so it is never run behind the pilot's back.

### Approach charts

`Charts/` fetches the FAA approach plate an approach publishes and files it under
`Application Support/Charts/<cycle>/`, so the chart screen can lay the corrected
altitudes over the plate — the one thing a chart app cannot show. The FAA serves
plates `no-store`, so `URLCache` caches nothing and the store is hand-built: a
200 MB budget, least-recently-opened eviction, and a whole cycle's plates dropped
when a new one is imported. Nothing is fetched in the background — a plate is
downloaded when the pilot opens it, or when they ask for an airport's whole set —
because a cache that fills itself on a guess is one the pilot cannot rely on
airborne.

### Weather

METARs come from [aviationweather.gov](https://aviationweather.gov)'s cache,
throttled to one fetch per 15 minutes and decoded with
[SwiftMETAR](https://github.com/RISCfuture/SwiftMETAR).

### App Intents

`Intents/` teaches the system what an airport and an approach are, so Shortcuts, Spotlight and
Siri can hold one and hand it back. Both entities are keyed by the FAA site number and the ARINC
424 identifier — never by a code the FAA reassigns — so a Shortcut saved one cycle still opens
the right screen the next. An intent that fires before the first cycle has been imported answers
with nothing rather than opening onto an empty store.

Landing on the screen is `ContentView`'s `onAppIntentExecution(_:perform:)`, which runs before
the app is foregrounded. It hands the route to a router the two navigation layouts share, which
is what lets a screen be named from outside the view hierarchy at all — and it holds the route
until the store has data behind it.

Spotlight is given the airports the pilot has favorited or opened, and the approaches under them.
Not the whole database: twenty thousand landing facilities is a long indexing pass after every
cycle for content nobody searches from the home screen. One App Shortcut is published, on the
airport, which is also what puts the app on the Action button and the Lock Screen.

### Crash reporting

[Sentry](https://sentry.io) is wired in for exception and crash reporting.
Events from debug builds and the simulator are discarded before transmission.

## Testing

Three test plans: `Unit Tests`, `UI Tests`, and `Screenshots` (the capture run
the fastlane lanes drive).

A UI test cannot reach into the app it drives, so everything that has to be
settled before the first screen draws — what the store holds, where nav data
comes from, what Core Location reports — is passed as launch arguments and read
by `Support/UITestConfiguration.swift`. The bundled fixtures it selects live in
`CTA Helper/UITestFixtures/`, which keeps the suite offline and deterministic.
Launched without those arguments, the app runs against its own store, the
published nav data, and the real device.

## Linting

```sh
swiftlint --strict
swift format lint --strict …
periphery scan --strict
```

Both style configs are shared across projects and deliberately live outside this
repository: `.swiftlint.yml` inherits from a gist through `parent_config`, and
`.swift-format` is fetched rather than committed (it is in `.gitignore`).
`.github/workflows/lint.yml` shows how to fetch each, and is the reference for
running them locally.

## Build & release

GitHub Actions runs on every push and pull request to `main`:

- **CI** (`ci.yml`) delegates to the reusable iOS workflow in
  [XCUITestKit](https://github.com/RISCfuture/XCUITestKit), which builds once and
  then runs the unit and UI test plans across iPhone and iPad simulators.
- **Lint** (`lint.yml`) runs `swiftlint --strict` and
  `swift format lint --strict`.
- **Periphery** (`periphery.yml`) runs `periphery scan --strict` as a dead-code
  gate.

Actions never signs or uploads. The archive that reaches App Store Connect is
built by Xcode Cloud, which bootstraps itself through `ci_scripts/ci_post_clone.sh`.

```sh
bundle exec fastlane screenshots       # capture the App Store screenshot set
bundle exec fastlane site_screenshots  # capture the site's set, light and dark
bundle exec fastlane beta              # build and upload to TestFlight
bundle exec fastlane release           # build and upload to the App Store
```

The upload lanes authenticate with an App Store Connect API key resolved out of
1Password at run time — the `.p8` is never written to disk or committed.

## Marketing site

`docs/` is the marketing site, served by GitHub Pages from `main`. See
[`docs/README.md`](docs/README.md) for how to work on it.

## Privacy

See the [privacy policy](https://cta-helper.github.io/iOS/privacy.html), which
lives in [`docs/privacy.html`](docs/privacy.html) and is what the app and App
Store Connect both link to. In short: your location never leaves your device,
nothing you do is tracked, and the only data transmitted anywhere is anonymous
crash and performance diagnostics.
