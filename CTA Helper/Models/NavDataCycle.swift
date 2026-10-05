import Foundation
import NavDataSchema

extension NavDataCycle {
  /// Whether the AIRAC cycle this data came from has ended, so a newer one is published.
  var hasExpired: Bool { expirationDate <= .now }

  /**
   Whether the cycle is in force right now: taken effect, and not yet expired.

   The window is half-open, as a published manifest states it, so at the instant one cycle
   expires its successor is the one in force.
   */
  var isInForce: Bool { (effectiveDate..<expirationDate).contains(.now) }
}
