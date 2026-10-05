import Foundation
import NavDataSchema

extension PublishedAltitude {
  /// The altitude a correction moves: a block's floor, otherwise the single published altitude.
  var correctable: Measurement<UnitLength>? {
    switch self {
      case .unpublished: nil
      case let .single(ft, _, _): .feet(ft)
      case let .block(_, floorFt): .feet(floorFt)
    }
  }
}
