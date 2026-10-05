import Foundation
import NavDataSchema

/**
 The over and under bars the fix list draws for each restriction.

 `AltitudeRestriction.atOrAboveSecond` is drawn like the other single-altitude
 descriptions: bars off the primary altitude, with the second altitude shown beneath as a
 glidepath value. That is very likely wrong — under code `C` the second altitude is the operative
 bound, not an uncorrected glidepath — but which altitude the generator puts where is
 unconfirmed, so verify against a real record before rendering it differently.
 */
extension AltitudeRestriction {
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
