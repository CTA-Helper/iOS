import Foundation

/**
 The pilot-entered DA or MDA presented to the correction engine as a fix of the final segment,
 so the minimums are corrected by exactly the machinery every charted fix goes through.
 */
struct MinimumsFix: CorrectableFix {
  let segment = Segment.final
  let isCorrectable = true
  let publishedAltitude: PublishedAltitude

  /**
   Wraps an entered DA or MDA, publishing nothing until the pilot types one.

   ``PublishedAltitude`` codes the whole feet the store holds, so the entry is rounded to them
   here. The conversion is `Int(exactly:)` rather than `Int(_:)` because a number pad accepts
   more digits than an `Int` holds, and converting a `Double` past `Int.max` traps outright. A
   value that large is not a minimum anyone typed on purpose, so it publishes nothing at all.
   */
  init(altitude: Measurement<UnitLength>?) {
    publishedAltitude =
      altitude
      .flatMap { Int(exactly: $0.converted(to: .feet).value.rounded()) }
      .map { .single(ft: $0, restriction: .atOrAbove, glidepathFt: nil) } ?? .unpublished
  }
}
