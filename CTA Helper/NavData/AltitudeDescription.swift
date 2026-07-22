import Foundation

/**
 The ARINC 424 altitude description code as the nav data publishes it — the wire vocabulary
 a fix's ``PublishedAltitude`` is resolved from at import.

 It carries one case the model has no counterpart for: ``between`` describes a block, whose
 second altitude is a true lower bound rather than the glidepath or VNAV altitude every other
 description's second altitude carries.
 */
enum AltitudeDescription: String, Decodable {
  // These decode from the nav data JSON, whose values are exactly these camelCase names, so
  // their raw values are intentionally the case names.
  // swiftlint:disable raw_value_for_camel_cased_codable_enum
  case at
  case atOrAbove
  case atOrBelow
  case between
  case glideslope
  case glideslopeIntercept
  case stepDownVNAV = "stepDownVnav"
  case atOrAboveSecond
  // swiftlint:enable raw_value_for_camel_cased_codable_enum

  /**
   Decodes leniently: an unmapped code — the generator emits `"unknown"` — reads as ``at``
   rather than failing the whole record.
   */
  init(from decoder: any Decoder) throws {
    let code = try decoder.singleValueContainer().decode(String.self)
    self = Self(rawValue: code) ?? .at
  }

  /**
   A block, or — where the procedure coded no floor — the ceiling it did publish, kept as the
   at-or-below restriction that ceiling amounts to on its own.
   */
  private static func block(ceilingFt: Int, floorFt: Int?) -> PublishedAltitude {
    guard let floorFt else {
      return .single(ft: ceilingFt, restriction: .atOrBelow, glidepathFt: nil)
    }
    return .block(ceilingFt: ceilingFt, floorFt: floorFt)
  }

  /**
   What a fix publishes, from this description and the two altitudes coded beside it.

   A fix with no primary altitude publishes nothing, whatever else it codes: a second altitude
   alone has no bound to hang off, and a restriction alone constrains nothing.

   - Parameters:
     - altitudeFt: the primary coded altitude, or `nil` where the procedure codes none.
     - altitude2Ft: the second coded altitude — a block's floor under ``between``, and a
       glidepath or VNAV altitude under every other description.
   */
  func publishedAltitude(altitudeFt: Int?, altitude2Ft: Int?) -> PublishedAltitude {
    guard let altitudeFt else { return .unpublished }

    return switch self {
      case .between: Self.block(ceilingFt: altitudeFt, floorFt: altitude2Ft)
      case .at: .single(ft: altitudeFt, restriction: .at, glidepathFt: altitude2Ft)
      case .atOrAbove: .single(ft: altitudeFt, restriction: .atOrAbove, glidepathFt: altitude2Ft)
      case .atOrBelow: .single(ft: altitudeFt, restriction: .atOrBelow, glidepathFt: altitude2Ft)
      case .glideslope:
        .single(ft: altitudeFt, restriction: .glideslope, glidepathFt: altitude2Ft)
      case .glideslopeIntercept:
        .single(ft: altitudeFt, restriction: .glideslopeIntercept, glidepathFt: altitude2Ft)
      case .stepDownVNAV:
        .single(ft: altitudeFt, restriction: .stepDownVNAV, glidepathFt: altitude2Ft)
      case .atOrAboveSecond:
        .single(ft: altitudeFt, restriction: .atOrAboveSecond, glidepathFt: altitude2Ft)
    }
  }
}
