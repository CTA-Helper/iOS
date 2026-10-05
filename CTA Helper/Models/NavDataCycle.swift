import Foundation
import NavDataSchema

extension NavDataCycle {
  /// Whether the AIRAC cycle this data came from has ended, so a newer one is published.
  var hasExpired: Bool { expirationDate < .now }
}
