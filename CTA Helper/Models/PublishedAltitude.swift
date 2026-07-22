import Foundation

/**
 The altitude or altitudes a fix publishes, whose case decides which one a cold temperature
 correction moves.

 This is a fix's stored altitude. The nav data codes two nullable altitudes beside a separate
 ARINC 424 description, a shape in which most combinations mean nothing — a second altitude
 with no first, a block with no floor, a restriction on an altitude the procedure never
 published. ``AltitudeDescription/publishedAltitude(altitudeFt:altitude2Ft:)`` resolves that
 wire shape into these cases once, at import, so nothing downstream has to consider them.
 */
enum PublishedAltitude: Codable, Equatable, Sendable {
  /// The fix codes no altitude — a path terminator, or a leg the procedure leaves unrestricted.
  case unpublished
  /**
   A single altitude, with the glidepath or VNAV altitude coded beneath it when the fix
   carries one. ENR 1.8 corrects the primary altitude and never that second one.
   */
  case single(ft: Int, restriction: AltitudeRestriction, glidepathFt: Int?)
  /**
   A block the aircraft crosses within. ENR 1.8 raises the obstacle-clearance floor and
   leaves the ceiling as published.
   */
  case block(ceilingFt: Int, floorFt: Int)

  /// The altitude a correction moves: a block's floor, otherwise the single published altitude.
  var correctableFt: Int? {
    switch self {
      case .unpublished: nil
      case let .single(ft, _, _): ft
      case let .block(_, floorFt): floorFt
    }
  }
}
