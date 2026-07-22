import Foundation

/**
 Applies AIP ENR 1.8 cold temperature corrections to an approach's fixes.

 A corrector is built for one approach at one temperature and set of options. It computes a
 ``SegmentCorrection`` for each of the four segments once, then resolves each fix against its
 segment's correction — deciding whether the fix is corrected and, if so, by how much.

 ## Reference altitudes

 Each segment's correction is the ICAO formula evaluated at its reference altitude's height
 above the airport (``ReferenceAltitudes/reference(for:method:)``). The final segment's
 reference is the pilot-entered DA/MDA; every other reference comes from the coded procedure.

 ## What is corrected

 A fix is left uncorrected — carrying the ``UncorrectableReason`` why — when it is not
 correctable, its segment's reference is unavailable, the Individual Segments Method
 excludes its segment, the final segment has no DA/MDA yet, or it codes no altitude. Which of
 a fix's altitudes the correction moves is ``PublishedAltitude``'s to decide: a block is
 corrected on its floor, raising the obstacle-clearance floor and leaving its ceiling
 published.
 */
struct ApproachCorrector {
  /// The airport elevation, in feet, that every reference height is measured above.
  let elevationFt: Int
  /// The approach's segment reference altitudes.
  let referenceAltitudes: ReferenceAltitudes
  /// The temperature to correct for, in °C.
  let reportedTemperatureC: Double
  /**
   The airport's Cold Temperature Airport restriction, or `nil` at an airport that is not a
   CTA — where the Individual Segments Method has nothing marked and so corrects every
   segment.
   */
  let coldTemperature: ColdTemperatureRestriction?
  /// The correction method.
  let method: CorrectionMethod
  /// The rounding convention.
  let rounding: CorrectionRounding
  /// Whether to evaluate the formula above the table's 5,000 ft ceiling.
  let extrapolateAboveTable: Bool
  /// The pilot-entered DA or MDA, in feet, or `nil` until entered.
  let minimumsAltitudeFt: Int?

  /// The correction in force on a single segment, or `nil` when the segment is not corrected.
  func appliedCorrection(for segment: Segment) -> SegmentCorrection.Applied? {
    guard case let .applied(applied) = segmentCorrection(for: segment) else { return nil }
    return applied
  }

  /// The correction outcome for one fix.
  func corrected(_ fix: some CorrectableFix) -> CorrectedAltitude {
    CorrectedAltitude(published: fix.publishedAltitude, correction: correction(for: fix))
  }

  /**
   The correction ENR 1.8 applies to a fix, or why it applies none.

   A fix that publishes no altitude is reported as such whatever its correctable flag says:
   the flag qualifies an altitude, so with none published it has nothing to describe, and the
   missing altitude is what the fix row should explain.
   */
  private func correction(for fix: some CorrectableFix) -> Correction {
    guard fix.publishedAltitude != .unpublished else {
      return .unavailable(.noPublishedAltitude)
    }
    guard fix.isCorrectable else { return .unavailable(.notCorrectable) }

    return switch segmentCorrection(for: fix.segment) {
      case let .applied(applied): .add(ft: applied.roundedCorrectionFt)
      case let .unavailable(reason): .unavailable(reason)
    }
  }

  /// The correction computed for a whole segment.
  private func segmentCorrection(for segment: Segment) -> SegmentCorrection {
    if let excluded = exclusionReason(for: segment) { return .unavailable(excluded) }

    guard let referenceAltitudeFt = referenceAltitudeFt(for: segment) else {
      return .unavailable(segment == .final ? .minimumsNotEntered : .referenceUnavailable)
    }

    let heightFt = Double(referenceAltitudeFt - elevationFt)
    let rawCorrectionFt = ColdTemperatureCorrection.correctionFt(
      reportedTemperatureC: reportedTemperatureC,
      heightAboveAirportFt: heightFt,
      extrapolateAboveTable: extrapolateAboveTable
    )
    return .applied(
      SegmentCorrection.Applied(
        segment: segment,
        referenceAltitudeFt: referenceAltitudeFt,
        heightAboveAirportFt: referenceAltitudeFt - elevationFt,
        roundedCorrectionFt: rounding.rounded(rawCorrectionFt, segment: segment),
        isHeightCapped: !extrapolateAboveTable
          && heightFt > ColdTemperatureCorrection.tableCeilingFt
      )
    )
  }

  /**
   The reason the Individual Segments Method excludes this segment, or `nil`.

   The exclusion applies only at a CTA: at an airport with no restriction the method has
   nothing to narrow to and corrects every segment, as does the All Segments Method always.
   */
  private func exclusionReason(for segment: Segment) -> UncorrectableReason? {
    guard method == .individualSegments, let coldTemperature else { return nil }
    return coldTemperature.affectedSegments.contains(segment) ? nil : .segmentNotSelected
  }

  private func referenceAltitudeFt(for segment: Segment) -> Int? {
    segment == .final
      ? minimumsAltitudeFt
      : referenceAltitudes.reference(for: segment, method: method).altitudeFt
  }
}
