# CTA Helper

[![CI](https://github.com/CTA-Helper/iOS/actions/workflows/ci.yml/badge.svg)](https://github.com/CTA-Helper/iOS/actions/workflows/ci.yml)
[![Lint](https://github.com/CTA-Helper/iOS/actions/workflows/lint.yml/badge.svg)](https://github.com/CTA-Helper/iOS/actions/workflows/lint.yml)
[![App Store](https://img.shields.io/itunes/v/6795019635.svg)](https://apps.apple.com/us/app/cta-helper/id6795019635)
[![Platform](https://img.shields.io/badge/platform-iOS-lightgrey.svg)](https://developer.apple.com/ios/)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

CTA Helper applies FAA cold temperature altitude corrections to the altitudes of
an instrument approach, following the method published in AIP ENR 1.8.

## ⚠️ Disclaimer

This app is for situational awareness and planning only. **It is not for primary
navigation.** Always verify every correction independently, and read the DA/MDA
and all altitudes from the official approach plate before you fly them.

## The Problem

A barometric altimeter assumes the atmosphere is standard. When it is much
colder than standard, the air column is denser and the altimeter reads high —
the aircraft is lower than the indication. On an instrument approach into a
Cold Temperature Restricted Airport, the correction has to be computed for each
published altitude, added, and then flown, all while the temperature that drives
the calculation is being read off a METAR.

Doing that arithmetic across a whole approach, segment by segment, in the cockpit,
is exactly the kind of task worth handing to a computer.

## Features

- **Pick an airport** by ICAO identifier, FAA location identifier, or city
  name — or from the airports nearest you, your favorites, or the ones you
  looked at recently.
- **Pick an approach**, and see every fix in it grouped by segment and transition.
- **Read the corrected altitudes.** Each fix shows its published altitude and the
  corrected one, honoring altitude windows, block altitudes, and the fixes the
  FAA method leaves uncorrected. DA/MDA is corrected only where the method
  allows it.
- **Auto-fill the temperature from weather.** The current METAR for the airport
  is fetched and its reported temperature drives the correction, with the raw
  observation a tap away.
- **Choose your conventions.** Correction method and rounding convention are
  settings, so the numbers match how you were taught to fly them.

## Requirements

CTA Helper is written in Swift 6 and targets iOS 26.

## Development

The Xcode project defines three targets:

- **CTA Helper** — the application.
- **CTA HelperTests** — the unit test suite, written in Swift Testing.
- **CTA HelperUITests** — the end-to-end UI test suite, built on
  [XCUITestKit](https://github.com/RISCfuture/XCUITestKit).

### Correction engine

`CTA Helper/Corrections/` implements the ICAO Doc 8168 linear correction formula
and the FAA ENR 1.8 rules for which segments and altitudes it applies to. It is
kept free of SwiftData and SwiftUI — `CorrectableFix` is the protocol that
decouples it from the model layer — so it can be tested against the published
worked examples directly.

### Nav data

Approach and fix data is published as a versioned AIRAC cycle at
[CTA-Helper/Navdata](https://github.com/CTA-Helper/Navdata). On launch the app
polls the release manifest, and when a newer cycle is available downloads the
gzipped document, **verifies it against the SHA-256 and byte counts the manifest
publishes**, and imports it into SwiftData in bounded transactions.

### Weather

METARs come from [aviationweather.gov](https://aviationweather.gov)'s cache,
throttled to one fetch per 15 minutes and decoded with
[SwiftMETAR](https://github.com/RISCfuture/SwiftMETAR).

### Crash reporting

[Sentry](https://sentry.io) is wired in for exception and crash reporting.
Events from debug builds and the simulator are discarded before transmission.

### Build & Release

#### CI/CD

GitHub Actions runs three workflows on every push and pull request to `main`:

- **CI** (`ci.yml`) delegates to the reusable iOS workflow in
  [XCUITestKit](https://github.com/RISCfuture/XCUITestKit), which builds once and
  then runs the unit and UI test plans across iPhone and iPad simulators.
- **Lint** (`lint.yml`) runs `swiftlint --strict` and
  `swift format lint --strict`.
- **Periphery** (`periphery.yml`) runs `periphery scan --strict` as a dead-code
  gate.

Actions never signs or uploads. The archive that reaches App Store Connect is
built by Xcode Cloud, which bootstraps itself through `ci_scripts/ci_post_clone.sh`.

#### Fastlane

```sh
bundle exec fastlane screenshots       # capture the App Store screenshot set
bundle exec fastlane site_screenshots  # capture the site's set, light and dark
bundle exec fastlane beta              # build and upload to TestFlight
bundle exec fastlane release           # build and upload to the App Store
```

The upload lanes authenticate with an App Store Connect API key resolved out of
1Password at run time — the `.p8` is never written to disk or committed.

## Marketing site

`docs/` is the marketing site, served by GitHub Pages from `main`. It is plain
HTML, CSS and JavaScript with no build step and no Jekyll — `.nojekyll` turns
that processing off. It makes no third-party requests: the
[IBM Plex](https://github.com/IBM/plex) faces it sets its type in are served
from `docs/fonts/` under the SIL Open Font License, rather than from a font CDN.

`site_screenshots` captures the same screens as the App Store set in both
appearances and installs the three iPhone shots the page walks through, scaled
down, into `docs/images/screenshots/{light,dark}/`, where the page picks between
them with `prefers-color-scheme`. Adding a screen to the page means adding it to
`SITE_SCREENS` as well. Pass `appearance:light` or `appearance:dark` to capture
one of them, or run `install_site_screenshots` to re-install what a previous
capture already staged.

## Privacy

See the [privacy policy](https://cta-helper.github.io/iOS/privacy.html), which
lives in [`docs/privacy.html`](docs/privacy.html) and is what the app and App
Store Connect both link to. In short: your location never leaves your device,
nothing you do is tracked, and the only data transmitted anywhere is anonymous
crash and performance diagnostics.
