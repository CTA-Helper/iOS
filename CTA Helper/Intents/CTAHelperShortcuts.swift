import AppIntents

/**
 The App Shortcut the system publishes without the pilot building one, and what puts the app on
 the Action button and the Lock Screen.

 One shortcut, and it opens an airport. `OpenIntent` carries a single `target`, so a phrase for
 an approach would have Siri disambiguate among every procedure in the country with no airport to
 narrow them by; ``OpenApproachIntent`` is reached instead through Spotlight, or a Shortcut the
 pilot builds once for the airport they actually fly.

 Apple states on the `AppShortcutsProvider` documentation page that anonymized App Shortcuts data
 — localized phrases, display representation values, and the titles and descriptions of the
 related intents — may be extracted to train its models.
 */
struct CTAHelperShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: OpenAirportIntent(),
      phrases: ["Open an airport in \(.applicationName)"],
      shortTitle: "Open Airport",
      systemImageName: "airplane"
    )
  }
}
