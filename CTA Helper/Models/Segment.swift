import Foundation

/**
 One of the four segments an instrument approach is divided into for the purpose of cold
 temperature corrections (AIP ENR 1.8 5.f).

 Each segment's correction is computed from a different reference altitude and applied to a
 different set of fixes; ``ReferenceAltitude`` records where each reference comes from.
 */
enum Segment: String, Codable, CaseIterable, Sendable {
  case initial
  case intermediate
  case final
  case missed
}
