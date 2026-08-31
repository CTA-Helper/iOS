import SwiftUI

/**
 One row of the fix list: what the leg instructs, the fix it is flown to, and its corrected
 altitude.

 A leg flown to a named fix reads as its identifier, with the corrected altitude across the
 row. A leg with no fix to name — a climb to an altitude, a heading to an intercept — has
 nothing to put in that place, so its altitude stands there instead and the row's trailing
 column is empty. Where ENR 1.8 corrects the altitude for a reason belonging to the fix rather
 than to its segment, the row says so beneath itself; the reasons a whole segment carries are
 answered once in its section footer.

 The row is a single accessibility element. A fix list is a dense table, and read as the loose
 fragments it draws, a corrected row announces two numbers with no word saying which is
 published and which is flown. It reads out as the fix and the altitude the pilot flies, with
 everything behind that value — what was published, what the correction came to, why there was
 none — attached as ``AltitudeDetail``.
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
        } else {
          AltitudeView(altitude: altitude)
          Spacer()
        }
      }
      if altitude.uncorrectableReason == .notCorrectable {
        UncorrectedNote(reason: .notCorrectable)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityValue(altitude.announcement)
    .accessibilityIdentifier(rowIdentifier)
    .modifier(AltitudeDetail(altitude: altitude, segment: fix.segment))
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

  /// How VoiceOver names the row: what the leg instructs, the fix it names, and the role it serves.
  private var accessibilityLabel: String {
    [instruction, fix.identifier, roleLabel].compactMap(\.self).joined(separator: ", ")
  }

  /**
   What a UI test matches the row by.

   A leg that ends at an altitude rather than at a fix has no name to build an identifier from,
   and nothing addresses those rows. An empty identifier is what SwiftUI reads as none at all.
   */
  private var rowIdentifier: String {
    fix.identifier.map { "fixRow-\($0)" } ?? ""
  }
}

/**
 What the row carries beyond the altitude it reads out: the published value a correction
 superseded, the size of that correction or the reason there was none, the glidepath altitude
 ENR 1.8 leaves alone, and the segment the fix falls in.

 The published value is high importance, so it is spoken with the row — a corrected altitude
 the pilot cannot check against the plate is one they have to take on trust. The rest is asked
 for, which is what keeps a fifteen-row approach to fifteen announcements.

 A `nil` value removes its entry rather than adding an empty one, so each is attached
 unconditionally and only the ones this fix actually has are spoken.
 */
private struct AltitudeDetail: ViewModifier {
  let altitude: CorrectedAltitude
  let segment: Segment

  func body(content: Content) -> some View {
    content
      .accessibilityCustomContent(
        AccessibilityCustomContentKey("Published"),
        altitude.supersededAnnouncement.map(Text.init),
        importance: .high
      )
      .accessibilityCustomContent(
        AccessibilityCustomContentKey("Correction"),
        altitude.correctionAnnouncement.map(Text.init)
      )
      .accessibilityCustomContent(
        AccessibilityCustomContentKey("Not corrected"),
        altitude.uncorrectableReason.map { Text($0.label) }
      )
      .accessibilityCustomContent(
        AccessibilityCustomContentKey("Glidepath"),
        altitude.glidepathAnnouncement.map(Text.init)
      )
      .accessibilityCustomContent(AccessibilityCustomContentKey("Segment"), Text(segment.label))
  }
}

/// The fix the procedure names, over the role it serves.
private struct NamedFix: View {
  let identifier: String
  let role: String?

  var body: some View {
    if let role {
      Text("\(identifier) (\(role))")
    } else {
      Text(identifier)
    }
  }
}

/**
 Why this fix's altitude stands as published, set under the row in smaller type than the value
 it qualifies.

 Only the reasons that belong to the fix reach this far. A reason its whole segment carries is
 printed once in the section footer instead of down every row the segment holds.
 */
private struct UncorrectedNote: View {
  let reason: UncorrectableReason

  var body: some View {
    Text(reason.label)
      .font(.caption)
      .foregroundStyle(.secondary)
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

  // The minimums go unentered so the final segment carries a reason of its own, and the method
  // narrows to the segments KMSO's restriction marks so the missed approach carries another.
  #Preview("Uncorrected") {
    let airport = PreviewData.missoula()
    let corrector = ApproachCorrector.preview(
      for: airport,
      method: .individualSegments,
      minimums: nil
    )

    List(airport.approaches[0].fixes) { fix in
      FixRow(fix: fix, altitude: corrector.corrected(fix))
    }
  }
#endif
