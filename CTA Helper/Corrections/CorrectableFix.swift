import Foundation

/**
 The correction-relevant properties of a fix, so the correction engine can work on either a
 persisted ``Fix`` or a lightweight test value without depending on SwiftData.
 */
protocol CorrectableFix {
  /// The segment the fix falls in, which selects the correction applied to it.
  var segment: Segment { get }
  /// What the fix publishes, whose case decides which altitude a correction moves.
  var publishedAltitude: PublishedAltitude { get }
  /**
   Whether ENR 1.8 applies a correction to this fix's published altitude at all (the nav
   data's `correctable` flag: false for glidepath altitudes, the runway threshold at the
   MAP, and the climb/intermediate altitudes of a missed approach).
   */
  var isCorrectable: Bool { get }
}
