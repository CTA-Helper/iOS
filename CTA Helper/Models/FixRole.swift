import Foundation

/**
 A fix's role in an approach, as classified from its ARINC 424 waypoint description
 (AIP ENR 1.8 identifies segments by these named fixes).
 */
enum FixRole: String, Codable, Sendable {
  case initialApproachFix = "iaf"
  case initialApproachFixHolding = "iafHolding"
  case intermediateFix = "if"
  case finalApproachCourseFix = "facf"
  case finalApproachFix = "faf"
  case missedApproachPoint = "map"
  case stepdown
  // Decodes from the nav data JSON key "missedHolding", so the raw value is the case name.
  // swiftlint:disable:next raw_value_for_camel_cased_codable_enum
  case missedHolding
}
