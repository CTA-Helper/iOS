import SwiftUI

/**
 The snowflake and restriction temperature shown for a Cold Temperature Airport, weighted by what
 the station is reporting now.

 The badge answers "is this one worth opening today," not "what is the correction" — the fix list
 remains the only place a corrected altitude appears.

 Its three states are separated by shape before colour, in the order of how much the app actually
 knows: a filled capsule where the restriction is in force right now, an outlined one where a
 station is reporting above it, and no capsule at all where no observation resolved. Shape rather
 than hue is what a pilot reading the list in sunlight, at an accessibility text size, or with a
 colour vision deficiency has to go on. Every state is named in the accessibility label besides.

 So "no correction required" is a mark the badge carries rather than one it drops — and an
 unmarked badge means only that nothing was reported, which is the common offline case and the one
 that asks the pilot to go and look.
 */
struct ColdTemperatureBadge: View {
  /**
   How far the filled capsule's blue is darkened toward black.

   System blue carries white text at only 4.0:1 in light appearance and 3.7:1 in dark, both short
   of WCAG AA. A sixth of the way to black clears 4.5:1 in either without leaving the blue this
   badge has always been.
   */
  private static let fillDarkening = 0.15

  /// The width of the outlined capsule's border.
  private static let borderWidth = 1.0

  let restriction: ColdTemperatureRestriction

  /// The station's latest reported temperature, or `nil` where no observation resolved.
  var reportedTemperature: Measurement<UnitTemperature>?

  @ScaledMetric(relativeTo: .body)
  private var size = 14.0
  @ScaledMetric(relativeTo: .body)
  private var horizontalPadding = 5.0
  @ScaledMetric(relativeTo: .body)
  private var verticalPadding = 1.0

  var body: some View {
    Label {
      Text(
        restriction.restrictionTemperature,
        format: .measurement(width: .narrow, usage: .asProvided)
      )
    } icon: {
      Image(systemName: "snowflake")
    }
    .labelStyle(.narrow)
    .font(.system(size: size, weight: weight))
    .foregroundStyle(foregroundStyle)
    .padding(.horizontal, horizontalPadding)
    // Padded and shaped in every state, so a row does not shift when an observation lands.
    .padding(.vertical, verticalPadding)
    .background(fill, in: .capsule)
    .overlay { Capsule().strokeBorder(border, lineWidth: Self.borderWidth) }
    .accessibilityLabel(accessibilityLabel)
  }

  private var status: ColdTemperatureStatus {
    .init(restriction: restriction, reportedTemperature: reportedTemperature)
  }

  private var weight: Font.Weight {
    status == .correctionRequired ? .semibold : .regular
  }

  /// Erased: two states are a concrete colour and the third a hierarchical style.
  private var foregroundStyle: AnyShapeStyle {
    switch status {
      case .correctionRequired: AnyShapeStyle(Color.white)
      case .aboveRestriction: AnyShapeStyle(Color.blue)
      case .noObservation: AnyShapeStyle(.secondary)
    }
  }

  private var fill: Color {
    status == .correctionRequired ? .blue.mix(with: .black, by: Self.fillDarkening) : .clear
  }

  private var border: Color {
    status == .aboveRestriction ? .blue : .clear
  }

  /**
   The badge read aloud as one phrase: the airport's threshold, then what today's observation
   makes of it.
   */
  private var accessibilityLabel: Text {
    let threshold = restriction.restrictionTemperature.formatted(
      .measurement(width: .wide, usage: .asProvided)
    )
    switch status {
      case .correctionRequired:
        return Text("Cold temperature airport, \(threshold), correction required")
      case .aboveRestriction:
        return Text("Cold temperature airport, \(threshold), above restriction")
      case .noObservation:
        return Text("Cold temperature airport, \(threshold), no observation")
    }
  }
}

#if DEBUG
  #Preview("Every state") {
    let restriction = ColdTemperatureRestriction(
      restrictionTemperatureC: -11,
      affectedSegments: [.initial, .intermediate, .final]
    )
    List {
      LabeledContent("Cold enough") {
        ColdTemperatureBadge(restriction: restriction, reportedTemperature: .celsius(-20))
      }
      LabeledContent("At the restriction") {
        ColdTemperatureBadge(restriction: restriction, reportedTemperature: .celsius(-11))
      }
      LabeledContent("Warm enough") {
        ColdTemperatureBadge(restriction: restriction, reportedTemperature: .celsius(5))
      }
      LabeledContent("No observation") {
        ColdTemperatureBadge(restriction: restriction)
      }
    }
  }

  #Preview("Accessibility text size") {
    let restriction = ColdTemperatureRestriction(
      restrictionTemperatureC: -11,
      affectedSegments: [.final]
    )
    List {
      ColdTemperatureBadge(restriction: restriction, reportedTemperature: .celsius(-20))
      ColdTemperatureBadge(restriction: restriction, reportedTemperature: .celsius(5))
      ColdTemperatureBadge(restriction: restriction)
    }
    .environment(\.dynamicTypeSize, .accessibility3)
  }
#endif
