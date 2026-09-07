# Changelog

Release notes for CTA Helper. A version heading is `## <version>`, matching the
tag exactly: `Scripts/release-notes.sh` reads these sections, the Release
workflow verifies the one it is about to ship before anything is built, and
writes it into App Store Connect's "What's New" once the build has uploaded.
The changelog is the source of truth for that field — editing the notes in App
Store Connect leaves them to be overwritten by the next release.

Write entries to survive both renderings. Here they are Markdown; on the store
they are shown verbatim as plain text, so anything that depends on its
formatting to make sense will read badly in one of the two places.

## 1.1

Approach plates. Open an approach's FAA plate and read every named fix beside it
at the altitude cold air makes it. Plates you have opened stay cached for the
cycle, so they are there without a signal.

Uncorrected altitudes now say why — a segment the Individual Segments Method
excludes, a procedure that codes no reference altitude, an altitude ENR 1.8
never corrects — on screen and under VoiceOver.

Airport lists mark cold weather: a filled badge where the restriction is in
force in what is being reported now, outlined where a station reports above it.

Siri and Spotlight open an airport or an approach by name.

Nearest fills as soon as you allow location, and tracks at flight speeds.

The display stays awake while the fix list is showing.

Expired nav data is caught on launch and the current cycle offered.

## 1.0

The first release: every fix of an approach at the altitude cold air makes it,
computed the way AIM ENR 1.8 says to, for the airports and procedures the FAA
publishes as needing it.
