import AppIntents

/**
 Opens an airport's approach list.

 There is no `perform()`: `OpenIntent` and `TargetContentProvidingIntent` each supply one, and
 the work is `ContentView`'s `onAppIntentExecution(_:perform:)`, which runs before the app is
 foregrounded and so has the route set before the first frame is drawn.
 */
struct OpenAirportIntent: OpenIntent, TargetContentProvidingIntent {
  static let title: LocalizedStringResource = "Open Airport"
  static let description: IntentDescription? = IntentDescription(
    "Shows an airport’s instrument approaches."
  )

  @Parameter(title: "Airport", requestValueDialog: "Which airport?")
  var target: AirportEntity
}
