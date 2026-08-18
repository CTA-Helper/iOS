import Foundation

/**
 The altitude one approach segment's cold temperature correction is computed from, and where
 it comes from (AIP ENR 1.8 5.f.2.1).

 Only ``published(ft:source:)`` carries an altitude, and it always carries one: the two ways a
 segment can lack a reference are cases of their own, so a reference can never name the fix it
 was taken from without the altitude that fix published.
 */
enum ReferenceAltitude: Codable, Hashable, Sendable {
  /// An altitude the coded procedure publishes, in feet, and the fix it is taken from.
  case published(ft: Int, source: PublishedReferenceSource)
  /// The DA or MDA, which ARINC 424 does not publish; the pilot supplies it from the plate.
  case pilotEntered
  /// No reference could be resolved from the coded procedure (about 4% of initial segments).
  case unavailable

  /// The reference altitude, or `nil` when the segment has none to correct from.
  var altitude: Measurement<UnitLength>? {
    guard case let .published(ft, _) = self else { return nil }
    return .feet(ft)
  }
}

/// The fix a published reference altitude is taken from.
enum PublishedReferenceSource: String, Codable, Hashable, Sendable {
  /// The intermediate fix altitude (the initial segment's reference).
  case intermediateFix = "if"
  /// The final approach fix altitude (the intermediate and All Segments reference).
  case finalApproachFix = "faf"
  // This case decodes from the nav data JSON, whose key is exactly this camelCase name, so its
  // raw value is intentionally the case name.
  // swiftlint:disable raw_value_for_camel_cased_codable_enum
  /// The final missed approach holding altitude (the missed segment's reference).
  case missedHolding
  // swiftlint:enable raw_value_for_camel_cased_codable_enum
}
