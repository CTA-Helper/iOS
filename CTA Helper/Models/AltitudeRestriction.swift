import Foundation

/**
 How a fix's single published altitude constrains the aircraft, from the ARINC 424 altitude
 description code.

 The cases carry the semantics the fix list renders as over and under bars. A block is not one
 of them: the ARINC `between` description, whose second altitude is a true lower bound rather
 than the glidepath altitude the others carry, is
 ``PublishedAltitude/block(ceilingFt:floorFt:)``, so no restriction here can be left without
 the second altitude it needs.
 */
enum AltitudeRestriction: String, Codable, Sendable {
  // These cases decode from the nav data JSON, whose keys are exactly these camelCase names,
  // so their raw values are intentionally the case names.
  // swiftlint:disable raw_value_for_camel_cased_codable_enum
  /// Cross at the published altitude — an over and under bar.
  case at
  /// Cross at or above the published altitude — an under bar.
  case atOrAbove
  /// Cross at or below the published altitude — an over bar.
  case atOrBelow
  /// A glidepath altitude, coded as the aircraft follows the glideslope/glidepath.
  case glideslope
  /// The altitude at which the glideslope/glidepath is intercepted.
  case glideslopeIntercept
  /// A step-down fix altitude flown with VNAV.
  case stepDownVNAV = "stepDownVnav"
  /**
   Cross at or above the second published altitude (ARINC 424 code `C`).

   No fix in the published data codes it, so it is decoded for forward compatibility and
   rendered like the other single-altitude descriptions: bars off the primary altitude, with
   the second altitude shown beneath as a glidepath value. That is very likely wrong — under
   code `C` the second altitude is the operative bound, not an uncorrected glidepath — but
   which altitude the generator puts where is unconfirmed, so verify against a real record
   before rendering it differently.
   */
  case atOrAboveSecond
  // swiftlint:enable raw_value_for_camel_cased_codable_enum

  /**
   Whether the restriction places a bar above the altitude (a ceiling the aircraft stays
   at or below).
   */
  var hasBarAbove: Bool {
    switch self {
      case .at, .atOrBelow: true
      default: false
    }
  }

  /**
   Whether the restriction places a bar below the altitude (a floor the aircraft stays at
   or above).
   */
  var hasBarBelow: Bool {
    switch self {
      case .at, .atOrAbove: true
      default: false
    }
  }
}
