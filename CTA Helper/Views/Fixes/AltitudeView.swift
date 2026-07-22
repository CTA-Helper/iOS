import SwiftUI

/**
 Renders a fix's ``CorrectedAltitude``: the published altitude, its cold temperature
 correction, and the restriction bars that show how it constrains the aircraft.

 When a correction applies, the published value is crossed out and the bold corrected
 value sits beside it, with the restriction bars on the corrected (operative) value. A
 block stacks its ceiling over its floor and corrects only the floor. An uncorrected
 altitude shows plain. A fix with no published altitude shows a dash.
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
            published: feet(publishedFt),
            corrected: altitude.correctedFt.map(feet),
            restriction: restriction,
            glidepath: glidepathFt.map(feet)
          )
        case let .block(ceilingFt, floorFt):
          BlockAltitude(
            ceiling: feet(ceilingFt),
            floor: feet(floorFt),
            correctedFloor: altitude.correctedFt.map(feet)
          )
      }
    }
  }

  /**
   The correction engine's scalar feet as the `Measurement` the view layer displays.

   This is the whole boundary: ``CorrectedAltitude`` and ``PublishedAltitude`` speak `Int` feet
   because the correction tables and the store do, and taking the outcome apart is the one
   place a scalar is in hand. Converting here leaves every view below holding a value that
   carries its own unit, so none of them can format one as a bare number.
   */
  private func feet(_ ft: Int) -> Measurement<UnitLength> {
    .init(value: Double(ft), unit: .feet)
  }
}

/// The dash standing in for a fix that codes no altitude.
private struct UnpublishedAltitude: View {
  var body: some View {
    Text(verbatim: "—")
      .foregroundStyle(.secondary)
      .accessibilityLabel("No published altitude")
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
 floor an ``AltitudeRestriction/atOrAbove`` — which draws the one bar that half carries and
 leaves VoiceOver saying which bound of the block it just read.
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
      .padding(.vertical, 3)
      .overlay(alignment: .top) {
        if restriction.hasBarAbove { RestrictionBar() }
      }
      .overlay(alignment: .bottom) {
        if restriction.hasBarBelow { RestrictionBar() }
      }
      .foregroundStyle(.primary)
      .accessibilityValue(restriction.barDescription)
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

private extension AltitudeRestriction {
  /**
   What the restriction bars say, in the terms the FAA chart legend names them by.

   ``RestrictionBar`` draws the bars as rules, which carry no accessibility element of their
   own: VoiceOver reads the digits and nothing about how the fix is crossed. Reading the
   wording off the bars rather than off the case keeps the two in step — a description that
   draws no bar, a glidepath altitude among them, is a recommended altitude and is announced
   as one.
   */
  var barDescription: LocalizedStringKey {
    switch (hasBarAbove, hasBarBelow) {
      case (true, true): "Mandatory altitude"
      case (true, false): "Maximum altitude"
      case (false, true): "Minimum altitude"
      case (false, false): "Recommended altitude"
    }
  }
}

/// A thin rule standing in for the over/under restriction bar SwiftUI has no primitive for.
private struct RestrictionBar: View {
  var body: some View {
    Rectangle()
      .frame(height: 1.5)
      .padding(.horizontal, -3)
  }
}

#if DEBUG
  #Preview("Altitudes") {
    let samples: [(String, CorrectedAltitude)] = [
      (
        "At — corrected",
        CorrectedAltitude(
          published: .single(ft: 4000, restriction: .at, glidepathFt: nil),
          correction: .add(ft: 300)
        )
      ),
      (
        "At or above — corrected",
        CorrectedAltitude(
          published: .single(ft: 9400, restriction: .atOrAbove, glidepathFt: nil),
          correction: .add(ft: 300)
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
          correction: .add(ft: 200)
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
