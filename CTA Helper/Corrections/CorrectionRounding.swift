import Foundation

/**
 How a computed correction is rounded before it is added to a published altitude
 (AIP ENR 1.8 5.e).

 ENR 1.8 sanctions two rounding conventions for the segment corrections, and imposes one
 invariant on the final segment: the DA/MDA correction "may be used as is or rounded up, but
 never rounded down". So the final segment never rounds down under any mode — under
 ``nearestHundred`` it rounds up to the nearest 10 ft rather than to the nearest 100.
 */
enum CorrectionRounding: String, CaseIterable, Identifiable, Sendable {
  /// Round each segment correction to the nearest 100 ft (the final segment up to 10 ft).
  case nearestHundred
  /// Round every correction up to the next 100 ft.
  case roundUp

  /// The step a segment correction is rounded to, in feet.
  private static let segmentStepFt = 100.0

  /**
   The step the final segment's correction is rounded up to under ``nearestHundred``, in feet:
   the DA/MDA is never rounded down, so it takes the finer step instead of the nearest
   ``segmentStepFt``.
   */
  private static let finalSegmentStepFt = 10.0

  var id: Self { self }

  /**
   Round a raw correction for a segment.

   - Parameters:
     - correctionFt: the un-rounded correction, in feet.
     - segment: the segment the correction applies to; the final segment is never rounded
       down.
   - Returns: the rounded correction, in feet.
   */
  func rounded(_ correctionFt: Double, segment: Segment) -> Int {
    let roundedFt =
      switch self {
        case .roundUp:
          correctionFt.rounded(toMultipleOf: Self.segmentStepFt, rule: .up)
        case .nearestHundred:
          segment == .final
            ? correctionFt.rounded(toMultipleOf: Self.finalSegmentStepFt, rule: .up)
            : correctionFt.rounded(toMultipleOf: Self.segmentStepFt)
      }
    return Int(roundedFt)
  }
}
