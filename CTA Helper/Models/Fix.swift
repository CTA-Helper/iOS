import Foundation
import SwiftData

/**
 One leg of a published approach, with the altitude and segment classification a cold
 temperature correction needs.

 A leg appears once per transition it is flown on, so the same fix can occur several times
 in an approach; ``transition`` and ``sequence`` place it. Legs with no ``identifier`` are
 path terminators (a climb or a heading to intercept) that the fix row names from
 ``legType``.
 */
@Model
final class Fix: CorrectableFix {
  var identifier: String?
  var transition: String?
  var sequence: UInt
  /// The ARINC 424 path terminator, or `nil` for a code the app does not recognize.
  var legType: LegType?
  var role: FixRole?
  var segment: Segment
  var publishedAltitude: PublishedAltitude
  var flyover: Bool
  var isCorrectable: Bool

  var approach: Approach?

  init(
    identifier: String?,
    transition: String?,
    sequence: UInt,
    legType: LegType?,
    role: FixRole?,
    segment: Segment,
    publishedAltitude: PublishedAltitude,
    flyover: Bool,
    isCorrectable: Bool
  ) {
    self.identifier = identifier
    self.transition = transition
    self.sequence = sequence
    self.legType = legType
    self.role = role
    self.segment = segment
    self.publishedAltitude = publishedAltitude
    self.flyover = flyover
    self.isCorrectable = isCorrectable
  }
}
