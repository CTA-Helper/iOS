import SwiftUI

/**
 One row of the fix list: what the leg instructs, the fix it is flown to, and its corrected
 altitude.

 A leg flown to a named fix reads as its identifier, with the corrected altitude across the
 row. A leg with no fix to name — a climb to an altitude, a heading to an intercept — has
 nothing to put in that place, so its altitude stands there instead and the row's trailing
 column is empty.
 */
struct FixRow: View {
  /// The fix this row describes.
  let fix: Fix
  /// The correction outcome for the fix, rendered by ``AltitudeView``.
  let altitude: CorrectedAltitude

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      if let instruction { InstructionLabel(instruction: instruction) }
      HStack(alignment: .firstTextBaseline) {
        if let identifier = fix.identifier {
          NamedFix(identifier: identifier, role: roleLabel)
          Spacer()
          AltitudeView(altitude: altitude)
            .accessibilityIdentifier("fixAltitude-\(identifier)")
        } else {
          AltitudeView(altitude: altitude)
          Spacer()
        }
      }
    }
  }

  /// What the leg instructs, where it is flown to something other than the fix itself.
  private var instruction: String? {
    LegInstruction.instruction(for: fix.legType)
  }

  /**
   The fix's role in the approach, abbreviated the way a plate does — and only for the three
   roles that place a fix in a way its name and section do not already.
   */
  private var roleLabel: String? {
    switch fix.role {
      case .initialApproachFix, .initialApproachFixHolding: String(localized: "IAF")
      case .finalApproachFix: String(localized: "FAF")
      case .missedApproachPoint: String(localized: "MAP")
      case .intermediateFix, .finalApproachCourseFix, .missedHolding, .stepdown, nil: nil
    }
  }
}

/// The fix the procedure names, over the role it serves.
private struct NamedFix: View {
  let identifier: String
  let role: String?

  var body: some View {
    Group {
      if let role {
        Text("\(identifier) (\(role))")
      } else {
        Text(identifier)
      }
    }
    .accessibilityIdentifier("fixRow-\(identifier)")
  }
}

/// What the leg instructs, set above the row in smaller type than the row it heads.
private struct InstructionLabel: View {
  let instruction: String

  @ScaledMetric(relativeTo: .body)
  private var size = 13.0

  var body: some View {
    Text(instruction)
      .font(.system(size: size, weight: .medium))
  }
}

#if DEBUG
  #Preview("Named fixes") {
    let airport = PreviewData.missoula()
    let corrector = ApproachCorrector.preview(for: airport)

    List(airport.approaches[0].fixes) { fix in
      FixRow(fix: fix, altitude: corrector.corrected(fix))
    }
  }

  #Preview("Path terminators") {
    let airport = PreviewData.missoula()
    let corrector = ApproachCorrector.preview(for: airport)

    List(PreviewData.pathTerminators()) { fix in
      FixRow(fix: fix, altitude: corrector.corrected(fix))
    }
  }
#endif
