import AppIntents

/// Opens an approach's cold temperature corrected altitudes.
struct OpenApproachIntent: OpenIntent, TargetContentProvidingIntent {
  static let title: LocalizedStringResource = "Open Approach"
  static let description: IntentDescription? = IntentDescription(
    "Shows an approach’s published altitudes, corrected for the reported temperature."
  )

  @Parameter(title: "Approach", requestValueDialog: "Which approach?")
  var target: ApproachEntity
}
