import SwiftUI

/**
 Renders a fix's ``CorrectedAltitude``: the published altitude, its cold temperature
 correction, and the restriction bars that show how it constrains the aircraft.

 When a correction applies, the published value is crossed out and the bold corrected
 value sits beside it, with the restriction bars on the corrected (operative) value. A
 block stacks its ceiling over its floor and corrects only the floor. An uncorrected
 altitude shows plain. A fix with no published altitude shows a dash.

 Taking ``PublishedAltitude`` apart is the last place whole feet are in hand — the store codes
 them that way — so every view below holds a measurement that carries its own unit, and none of
 them can format one as a bare number.

 Every view here is drawn and not spoken. ``FixRow`` merges the whole row into one accessibility
 element and reads the same ``CorrectedAltitude`` aloud through
 ``CorrectedAltitude/announcement``, so an accessibility label attached down here would be
 discarded rather than heard.
 */
struct AltitudeView: View {
  /// The correction outcome to render.
  let altitude: CorrectedAltitude

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      switch altitude.published {
        case .unpublished:
          UnpublishedAltitude()
        case let .single(publishedFt, restriction, glidepathFt):
          SingleAltitude(
            published: .feet(publishedFt),
            corrected: altitude.corrected,
            restriction: restriction,
            glidepath: glidepathFt.map { .feet($0) }
          )
        case let .block(ceilingFt, floorFt):
          BlockAltitude(
            ceiling: .feet(ceilingFt),
            floor: .feet(floorFt),
            correctedFloor: altitude.corrected
          )
      }
    }
  }
}

/// The dash standing in for a fix that codes no altitude.
private struct UnpublishedAltitude: View {
  var body: some View {
    Text(verbatim: "—")
      .foregroundStyle(.secondary)
  }
}

/**
 A single published altitude with optional restriction bars, either plain or as a
 crossed-out published value beside its bold correction.
 */
private struct BarredAltitude: View {
  let published: Measurement<UnitLength>
  let corrected: Measurement<UnitLength>?
  let restriction: AltitudeRestriction

  var body: some View {
    HStack {
      if let corrected {
        SupersededAltitude(altitude: published)
        BarredNumber(altitude: corrected, restriction: restriction, isEmphasized: true)
      } else {
        BarredNumber(altitude: published, restriction: restriction, isEmphasized: false)
      }
    }
  }
}

/**
 The altitude of a non-block fix, with a lighter glidepath/VNAV value beneath it when the
 fix codes one.
 */
private struct SingleAltitude: View {
  let published: Measurement<UnitLength>
  let corrected: Measurement<UnitLength>?
  let restriction: AltitudeRestriction
  let glidepath: Measurement<UnitLength>?

  var body: some View {
    VStack(alignment: .trailing, spacing: 1) {
      BarredAltitude(published: published, corrected: corrected, restriction: restriction)
      if let glidepath {
        GlidepathAltitude(altitude: glidepath)
      }
    }
  }
}

/**
 A block: the published ceiling over the floor, with only the floor corrected.

 Each half is the single bound it names — the ceiling an ``AltitudeRestriction/atOrBelow``, the
 floor an ``AltitudeRestriction/atOrAbove`` — which draws the one bar that half carries.
 */
private struct BlockAltitude: View {
  let ceiling: Measurement<UnitLength>
  let floor: Measurement<UnitLength>
  let correctedFloor: Measurement<UnitLength>?

  var body: some View {
    VStack(alignment: .trailing, spacing: 1) {
      BarredAltitude(published: ceiling, corrected: nil, restriction: .atOrBelow)
      BarredAltitude(published: floor, corrected: correctedFloor, restriction: .atOrAbove)
    }
  }
}

/**
 An altitude drawn with the restriction bars a fix can carry above and below it. It holds
 the full-strength foreground the surrounding row would otherwise dim, because every value
 that isn't slashed out is one the pilot flies.
 */
private struct BarredNumber: View {
  let altitude: Measurement<UnitLength>
  let restriction: AltitudeRestriction
  let isEmphasized: Bool

  var body: some View {
    Text(altitude, format: .altitudeDigits)
      .fontWeight(isEmphasized ? .bold : .regular)
      .monospacedDigit()
      .restrictionBars(restriction)
      .foregroundStyle(.primary)
  }
}

/// The published altitude a correction supersedes, struck through by ``SwiftUI/View/superseded(_:)``.
private struct SupersededAltitude: View {
  let altitude: Measurement<UnitLength>

  var body: some View {
    Text(altitude, format: .altitudeDigits)
      .monospacedDigit()
      .superseded()
  }
}

/// A glidepath or VNAV altitude shown as a lighter secondary value; ENR 1.8 never corrects it.
private struct GlidepathAltitude: View {
  let altitude: Measurement<UnitLength>

  @ScaledMetric(relativeTo: .body)
  private var size = 12.0

  var body: some View {
    Text(altitude, format: .altitudeDigits)
      .font(.system(size: size))
      .monospacedDigit()
      .foregroundStyle(.secondary)
  }
}

#if DEBUG
  #Preview("Altitudes") {
    let samples: [(String, CorrectedAltitude)] = [
      (
        "At — corrected",
        CorrectedAltitude(
          published: .single(ft: 4000, restriction: .at, glidepathFt: nil),
          correction: .add(.feet(300))
        )
      ),
      (
        "At or above — corrected",
        CorrectedAltitude(
          published: .single(ft: 9400, restriction: .atOrAbove, glidepathFt: nil),
          correction: .add(.feet(300))
        )
      ),
      (
        "At or above — not selected",
        CorrectedAltitude(
          published: .single(ft: 6200, restriction: .atOrAbove, glidepathFt: nil),
          correction: .unavailable(.segmentNotSelected)
        )
      ),
      (
        "At or below — reference unavailable",
        CorrectedAltitude(
          published: .single(ft: 5000, restriction: .atOrBelow, glidepathFt: nil),
          correction: .unavailable(.referenceUnavailable)
        )
      ),
      (
        "Block — floor corrected",
        CorrectedAltitude(
          published: .block(ceilingFt: 7000, floorFt: 5000),
          correction: .add(.feet(200))
        )
      ),
      (
        "Glideslope + glidepath",
        CorrectedAltitude(
          published: .single(ft: 3200, restriction: .glideslope, glidepathFt: 2100),
          correction: .unavailable(.notCorrectable)
        )
      ),
      (
        "No published altitude",
        CorrectedAltitude(published: .unpublished, correction: .unavailable(.noPublishedAltitude))
      )
    ]

    return List(Array(samples.enumerated()), id: \.offset) { _, sample in
      LabeledContent(sample.0) {
        AltitudeView(altitude: sample.1)
      }
    }
  }
#endif
