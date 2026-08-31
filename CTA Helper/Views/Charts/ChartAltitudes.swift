import Foundation
import SwiftData

/**
 The altitudes the chart overlay lists: every named fix of the approach, in the order it is
 flown, at the altitude the pilot actually flies it.

 The list is built through the same ``FixGrouping`` the fix list renders from, reading the same
 selected transitions, so the two screens can never disagree about which legs belong to the
 procedure on screen or what order they come in.
 */
enum ChartAltitudes {
  /**
   The overlay's lines for an approach.

   - Parameters:
     - approach: the approach whose fixes are listed.
     - corrector: the correction in force, rebuilt from the fix list's own controls.
     - transitions: the transition each segment is showing, as the pilot chose it.
     - minimums: the DA or MDA the pilot entered, or `nil` until they enter one.

   Legs the procedure does not name are left out. The overlay exists to be read against the
   plate, and a line the pilot cannot find on the chart — a climb to an altitude, a heading to
   an intercept — is one they cannot check, so it would cost space without buying anything. The
   fix list still lists every one of them.
   */
  static func sections(
    of approach: Approach,
    corrector: ApproachCorrector,
    transitions: [Segment: String],
    minimums: Measurement<UnitLength>?
  ) -> [Section] {
    let groups = FixGrouping.groups(
      approach.fixes,
      segment: \.segment,
      transition: \.transition,
      sequence: \.sequence
    )

    var sections = groups.compactMap { group -> Section? in
      let lines = group.elements(via: transitions[group.segment] ?? group.transitions.first?.name)
        .compactMap { line(of: $0, corrector: corrector) }
      return lines.isEmpty ? nil : Section(segment: group.segment, lines: lines)
    }

    // The minimums close the final segment, where the fix list puts them.
    if let minimums = self.minimums(minimums, corrector: corrector) {
      if let index = sections.firstIndex(where: { $0.segment == .final }) {
        sections[index] = Section(
          segment: .final,
          lines: sections[index].lines + [minimums]
        )
      } else {
        sections.append(Section(segment: .final, lines: [minimums]))
      }
    }
    return sections
  }

  /// One named fix's line, or `nil` where it is unnamed or publishes no altitude to show.
  private static func line(of fix: Fix, corrector: ApproachCorrector) -> Line? {
    guard let identifier = fix.identifier else { return nil }

    let altitude = corrector.corrected(fix)
    guard let constraint = constraint(of: altitude) else { return nil }

    return Line(
      id: "\(fix.persistentModelID)",
      name: identifier,
      constraint: constraint,
      isCorrected: altitude.corrected != nil,
      announcement: altitude.announcement
    )
  }

  /**
   The altitude a line shows and how it bounds the aircraft, or `nil` for a leg that publishes
   none.

   The correction moves one altitude and leaves the rest of the constraint as published, so
   each case substitutes the corrected value in the one place ENR 1.8 puts it: the single
   altitude, or a block's floor. The restriction travels with it, because an altitude shown
   without its bars says only how high and never whether the aircraft may be higher.
   */
  private static func constraint(of altitude: CorrectedAltitude) -> Line.Constraint? {
    switch altitude.published {
      case .unpublished:
        nil
      case let .single(publishedFt, restriction, _):
        .single(altitude.corrected ?? .feet(publishedFt), restriction: restriction)
      case let .block(ceilingFt, floorFt):
        .block(ceiling: .feet(ceilingFt), floor: altitude.corrected ?? .feet(floorFt))
    }
  }

  /// The entered DA or MDA as a line, corrected the way every charted fix is.
  private static func minimums(
    _ minimums: Measurement<UnitLength>?,
    corrector: ApproachCorrector
  ) -> Line? {
    guard let minimums else { return nil }

    let altitude = corrector.corrected(MinimumsFix(altitude: minimums))
    return Line(
      id: "minimums",
      name: String(localized: "DA/MDA"),
      // A DA or MDA is the floor of the approach: the bar goes beneath it, as it does on the
      // plate and as ``MinimumsFix`` publishes it.
      constraint: .single(altitude.corrected ?? minimums, restriction: .atOrAbove),
      isCorrected: altitude.corrected != nil,
      announcement: altitude.announcement
    )
  }

  /**
   One segment's worth of lines, headed the way the fix list heads them.

   The grouping is not decoration. A fix flown in two segments is listed twice, and on the fix
   list the section headers are what say why; flattened into one column the repeat reads as a
   glitch instead of as two legs.
   */
  struct Section: Identifiable, Equatable {
    /// The segment these lines belong to.
    let segment: Segment
    /// The lines, in the order they are flown.
    let lines: [Line]

    var id: String { segment.rawValue }
  }

  /// One line of the overlay: what the plate names the fix, and the altitude to fly it at.
  struct Line: Identifiable, Equatable {
    /// A stable identity within one list.
    let id: String
    /// The fix as the procedure names it, or the label standing in for the entered minimums.
    let name: String
    /// The altitude the pilot flies, with the bars that bound it.
    let constraint: Constraint
    /// Whether ``constraint`` carries a correction rather than the published value unchanged.
    let isCorrected: Bool
    /// The whole outcome, as VoiceOver reads it off the fix list's own row.
    let announcement: String

    /**
     What a line puts against the plate: the altitude to fly, and the bars saying which way the
     procedure lets the aircraft leave it.

     A block is its own case rather than a single altitude with a restriction, because it is the
     one shape carrying two true bounds — a ceiling the aircraft stays under and a floor the
     correction raises. Collapsed to its floor, as the panel would have it from
     ``PublishedAltitude/correctable``, the ceiling would vanish from the only place the pilot
     is reading.
     */
    enum Constraint: Equatable {
      /// One altitude, bounded as the procedure describes it.
      case single(Measurement<UnitLength>, restriction: AltitudeRestriction)
      /// A block the aircraft crosses within: the published ceiling over the corrected floor.
      case block(ceiling: Measurement<UnitLength>, floor: Measurement<UnitLength>)
    }
  }
}
