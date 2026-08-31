import SwiftData
import SwiftUI

/**
 The corrected altitudes, in a Liquid Glass panel over the trailing edge of the plate.

 This is the whole reason the app draws a chart at all. Every other viewer a pilot carries shows
 the plate; none of them can show what the published altitudes become in cold air. Read against
 the procedure it annotates, this panel is the one thing the app knows that the chart does not.

 Liquid Glass is what it is made of rather than a material rectangle, because it is exactly what
 Apple reserves the material for: a functional element floating over the content layer, of which
 this screen has precisely one.

 The `regular` variant, not `clear`: clear is for components over photography and video and wants
 a dimming layer beneath it, which over a white line-drawn plate would obliterate the thing the
 pilot is reading.
 */
struct CorrectedAltitudeOverlay: View {
  /// The altitudes to list, grouped into the segments the fix list groups them into.
  let sections: [ChartAltitudes.Section]

  @Namespace private var glass

  var body: some View {
    GlassEffectContainer {
      AltitudeList(sections: sections)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .glassEffectID("correctedAltitudes", in: glass)
        // Nothing else on this screen is made of glass, so there is no neighbouring shape for
        // the panel to take its geometry from; `materialize` is the transition for a shape that
        // arrives on its own.
        .glassEffectTransition(.materialize)
    }
    .padding(.vertical)
    .padding(.trailing, 8)
  }
}

/**
 The panel's contents: a section per segment, a line per fix.

 It is sized to what it holds and scrolls only once it outgrows the plate, so a short approach
 gets a short panel rather than a full-height column of empty glass over the chart.
 */
private struct AltitudeList: View {
  let sections: [ChartAltitudes.Section]

  /// Wide enough for a five-digit altitude beside a five-character fix name, and no wider.
  @ScaledMetric(relativeTo: .body)
  private var width = 132.0

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // The heading carries the identifier rather than the stack around it: an identifier on a
      // plain layout container carries down onto its children and renames them.
      Text("Corrected")
        .font(.caption)
        .fontWeight(.semibold)
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .accessibilityIdentifier("correctedAltitudeOverlay")

      ViewThatFits(in: .vertical) {
        lines
        ScrollView {
          lines
        }
        .scrollBounceBehavior(.basedOnSize)
        // Without this a row scrolling past the panel's rounded corners reads as a smear of
        // digits against the plate showing through them.
        .scrollEdgeEffectStyle(.soft, for: .vertical)
      }
    }
    .frame(width: width)
  }

  private var lines: some View {
    VStack(alignment: .leading, spacing: 18) {
      if sections.isEmpty {
        NoAltitudesNotice()
      } else {
        ForEach(sections) { section in
          AltitudeSection(section: section)
        }
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
  }
}

/// One segment's lines, under the segment's own name.
private struct AltitudeSection: View {
  let section: ChartAltitudes.Section

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(section.segment.label)
        .font(.caption2)
        .fontWeight(.semibold)
        .foregroundStyle(.tertiary)
      ForEach(section.lines) { line in
        AltitudeLine(line: line)
      }
    }
  }
}

/**
 One fix and the altitude to fly it at.

 Read as one element, the way ``FixRow`` is: two loose numbers with no word saying which is
 published and which is flown is exactly what a merged row exists to prevent.
 */
private struct AltitudeLine: View {
  let line: ChartAltitudes.Line

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // A fix is named by the procedure rather than by localized copy.
      Text(verbatim: line.name)
        .font(.caption)
        .foregroundStyle(.secondary)
      ConstrainedAltitude(constraint: line.constraint, isCorrected: line.isCorrected)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(line.name)
    .accessibilityValue(line.announcement)
    .accessibilityIdentifier("overlayLine-\(line.name)")
  }
}

/**
 The altitude to fly, drawn with the restriction bars the procedure puts around it — the same
 notation ``AltitudeView`` draws on the fix list, so a number checked against the plate on one
 screen is bounded the same way on the other.

 A block stacks its published ceiling over its corrected floor. Only the floor is emphasized:
 the correction moved it, and it is the bound the pilot is here to read.
 */
private struct ConstrainedAltitude: View {
  let constraint: ChartAltitudes.Line.Constraint
  let isCorrected: Bool

  var body: some View {
    switch constraint {
      case let .single(altitude, restriction):
        BarredAltitude(altitude: altitude, restriction: restriction, isEmphasized: isCorrected)
      case let .block(ceiling, floor):
        VStack(alignment: .leading, spacing: 1) {
          BarredAltitude(altitude: ceiling, restriction: .atOrBelow, isEmphasized: false)
          BarredAltitude(altitude: floor, restriction: .atOrAbove, isEmphasized: isCorrected)
        }
    }
  }
}

/// One altitude of a line, between whichever of its bars the restriction carries.
private struct BarredAltitude: View {
  let altitude: Measurement<UnitLength>
  let restriction: AltitudeRestriction
  let isEmphasized: Bool

  var body: some View {
    Text(altitude, format: .altitudeDigits)
      .fontWeight(isEmphasized ? .bold : .regular)
      .monospacedDigit()
      .restrictionBars(restriction)
  }
}

/// What the panel says when the reported temperature calls for no correction at all.
private struct NoAltitudesNotice: View {
  var body: some View {
    Text("No correction")
      .font(.caption)
      .foregroundStyle(.secondary)
      .accessibilityIdentifier("noOverlayAltitudes")
  }
}

#if DEBUG
  #Preview("Over a plate") {
    let airport = PreviewData.missoula()
    let approach = airport.approaches[0]

    Color.gray.opacity(0.35)
      .overlay(alignment: .topTrailing) {
        CorrectedAltitudeOverlay(
          sections: ChartAltitudes.sections(
            of: approach,
            corrector: .preview(for: airport, minimums: .feet(4520)),
            transitions: [:],
            minimums: .feet(4520)
          )
        )
      }
      .modelContainer(.preview)
  }

  #Preview("Nothing to correct") {
    Color.gray.opacity(0.35)
      .overlay(alignment: .topTrailing) {
        CorrectedAltitudeOverlay(sections: [])
      }
      .modelContainer(.preview)
  }
#endif
