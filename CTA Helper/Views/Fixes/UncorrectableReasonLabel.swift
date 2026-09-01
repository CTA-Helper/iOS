import Foundation

/**
 What the fix list says when it corrects nothing, kept in the view layer because
 ``UncorrectableReason`` is a coded outcome with no display concern of its own.

 Every case is worded so it distinguishes itself from the other four. A row left uncorrected
 because the Individual Segments Method excludes its segment and a row left uncorrected because
 the procedure codes no reference altitude are the same blank column on screen, and telling them
 apart is the whole point of showing a reason at all.
 */
extension UncorrectableReason {
  /// The reason in the fewest words that still separate it from the rest, as a row reads it.
  var label: String {
    switch self {
      case .notCorrectable: String(localized: "ENR 1.8 does not correct this altitude")
      case .segmentNotSelected: String(localized: "Segment not marked by this airport’s CTA")
      case .referenceUnavailable: String(localized: "No reference altitude")
      case .minimumsNotEntered: String(localized: "DA or MDA not entered")
      case .noPublishedAltitude: String(localized: "No published altitude")
    }
  }

  /**
   The reason as a segment's section footer explains it, or `nil` for the two reasons a whole
   segment can never carry.

   ``ApproachCorrector/unavailableReason(for:)`` resolves a segment, and a segment is only ever
   left uncorrected by its method, its reference altitude or its minimums — the other two cases
   belong to a single fix and are answered on its row.
   */
  var segmentNote: String? {
    switch self {
      case .segmentNotSelected:
        String(
          localized:
            "The Individual Segments Method corrects only the segments this airport’s CTA marks."
        )
      case .referenceUnavailable:
        String(localized: "The procedure codes no reference altitude for this segment.")
      case .minimumsNotEntered:
        String(localized: "Enter the DA or MDA to correct this segment.")
      case .notCorrectable, .noPublishedAltitude:
        nil
    }
  }
}
