import Foundation

/// Why a fix's published altitude was not corrected.
enum UncorrectableReason: Equatable, Sendable {
  /**
   ENR 1.8 never corrects this altitude (a glidepath altitude, the runway threshold at the
   missed approach point, or a missed approach climb/intermediate altitude).
   */
  case notCorrectable
  /// The Individual Segments Method is in use and this segment is not one the CTA marks.
  case segmentNotSelected
  /// The segment's reference altitude could not be resolved from the coded procedure.
  case referenceUnavailable
  /// The final segment cannot be corrected until the pilot enters the DA or MDA.
  case minimumsNotEntered
  /// The fix codes no published altitude to correct.
  case noPublishedAltitude
}

/**
 The cold temperature correction in force on one fix: the feet ENR 1.8 adds to the altitude it
 corrects, or why it adds nothing.
 */
enum Correction: Equatable, Sendable {
  /// Add this much to the altitude the fix's ``PublishedAltitude`` marks as correctable.
  case add(Measurement<UnitLength>)
  /// Add nothing, for this reason.
  case unavailable(UncorrectableReason)
}

/**
 The correction outcome for one fix — everything the fix row needs to render its altitude,
 crossed-out published value and bold corrected value included.
 */
struct CorrectedAltitude: Equatable, Sendable {
  /// What the fix publishes, whose case decides which altitude the correction moves.
  var published: PublishedAltitude
  /// The correction in force, or why none is.
  var correction: Correction

  /**
   The corrected value of the altitude ENR 1.8 moves — a block's floor, otherwise the single
   published altitude — or `nil` when no correction applies.
   */
  var corrected: Measurement<UnitLength>? {
    guard case let .add(addend) = correction else { return nil }
    return published.correctable.map { $0 + addend }
  }
}
