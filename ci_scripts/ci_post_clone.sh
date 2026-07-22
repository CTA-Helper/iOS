#!/bin/sh
set -eu

# Skip macro fingerprint validation for Swift macros from packages. Xcode Cloud does not persist
# macro approvals between builds, so without this every clean build fails to expand SwiftData's
# `@Model` and Observation's `@Observable`.
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES

# sentry-cli is what the "Upload Debug Symbols to Sentry" build phase looks for; without it the
# phase warns and the archive ships unsymbolicated.
curl -sL https://sentry.io/get-cli/ | bash
