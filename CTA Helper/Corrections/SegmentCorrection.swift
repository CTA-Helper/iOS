import Foundation

/**
 The correction computed for one approach segment, which every fix in that segment is
 resolved against.
 */
enum SegmentCorrection: Equatable, Sendable {
  /// The segment is corrected, carrying the audit trail behind it.
  case applied(Applied)
  /// The segment is not corrected, for this reason.
  case unavailable(UncorrectableReason)

  /**
   The audit trail behind a corrected segment: what the correction was computed from and what
   it came to.
   */
  struct Applied: Equatable, Sendable {
    /// The segment corrected.
    var segment: Segment
    /// The altitude the correction is computed from, in feet.
    var referenceAltitudeFt: Int
    /// The reference altitude's height above the airport, in feet.
    var heightAboveAirportFt: Int
    /// The correction added to the segment's altitudes, in feet, after rounding.
    var roundedCorrectionFt: Int
    /// Whether the height was capped at the table's 5,000 ft ceiling.
    var isHeightCapped: Bool
  }
}
