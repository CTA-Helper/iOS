import Foundation
import NavDataSchema

extension ReferenceAltitude {
  /// The reference altitude, or `nil` when the segment has none to correct from.
  var altitude: Measurement<UnitLength>? {
    guard case let .published(ft, _) = self else { return nil }
    return .feet(ft)
  }
}
