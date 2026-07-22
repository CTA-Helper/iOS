import Testing

@testable import CTA_Helper

/**
 A fix reduced to just the properties the corrector reads, so a scenario can be written by
 hand without a SwiftData store.
 */
private struct TestFix: CorrectableFix {
  var segment: Segment
  var publishedAltitude: PublishedAltitude
  var isCorrectable: Bool

  init(_ segment: Segment, _ publishedAltitude: PublishedAltitude, correctable: Bool = true) {
    self.segment = segment
    self.publishedAltitude = publishedAltitude
    self.isCorrectable = correctable
  }

  /// A fix publishing a single altitude — the shape most of these scenarios need.
  init(
    _ segment: Segment,
    altitudeFt: Int,
    restriction: AltitudeRestriction = .atOrAbove,
    correctable: Bool = true
  ) {
    self.init(
      segment,
      .single(ft: altitudeFt, restriction: restriction, glidepathFt: nil),
      correctable: correctable
    )
  }
}

/**
 AIP ENR 1.8 6.a works Missoula Intl (KMSO) RNAV (GPS) Y RWY 12 at −12 °C as its example, so
 that approach anchors the corrector. Every input below is taken from the published nav data
 for that approach; the expected outputs are the FAA's, except where the note explains a
 deliberate 10 ft difference.
 */
struct ApproachCorrectorTests {
  private static let kmsoReferences = ReferenceAltitudes(
    initial: .published(ft: 9400, source: .intermediateFix),
    intermediate: .published(ft: 6200, source: .finalApproachFix),
    final: .pilotEntered,
    missed: .published(ft: 12000, source: .missedHolding),
    allSegments: .published(ft: 6200, source: .finalApproachFix)
  )

  /// KMSO is a CTA marked for the initial, intermediate and final segments.
  private static let kmsoRestriction = ColdTemperatureRestriction(
    restrictionTemperatureC: -11,
    affectedSegments: [.initial, .intermediate, .final]
  )

  /**
   ``kmsoReferences`` with the initial segment's reference replaced, for the scenarios that
   turn on what the procedure publishes to correct that segment from.
   */
  private static func kmsoReferences(initial: ReferenceAltitude) -> ReferenceAltitudes {
    var references = kmsoReferences
    references.initial = initial
    return references
  }

  private func kmso(
    references: ReferenceAltitudes = kmsoReferences,
    method: CorrectionMethod = .allSegments,
    rounding: CorrectionRounding = .nearestHundred,
    extrapolate: Bool = false,
    minimumsFt: Int? = 4520
  ) -> ApproachCorrector {
    ApproachCorrector(
      elevationFt: 3206,
      referenceAltitudes: references,
      reportedTemperatureC: -12,
      coldTemperature: Self.kmsoRestriction,
      method: method,
      rounding: rounding,
      extrapolateAboveTable: extrapolate,
      minimumsAltitudeFt: minimumsFt
    )
  }

  @Test("The All Segments Method matches the ENR 1.8 6.a worked example")
  func allSegmentsMatchesTheExample() {
    let corrector = kmso()

    // IAFs and the FAF-and-above fixes correct from the FAF (6200 ft), +300 ft.
    #expect(corrector.corrected(TestFix(.initial, altitudeFt: 9400)).correctedFt == 9700)
    #expect(corrector.corrected(TestFix(.intermediate, altitudeFt: 7000)).correctedFt == 7300)
    #expect(corrector.corrected(TestFix(.intermediate, altitudeFt: 6200)).correctedFt == 6500)

    // The missed holding altitude (12000 ft) is 8794 ft up, capped at the 5000 ft column, +500.
    #expect(corrector.corrected(TestFix(.missed, altitudeFt: 12000)).correctedFt == 12500)
  }

  @Test("The final segment differs from the FAA text by 10 ft, deliberately")
  func finalSegmentIsTenFeetLowerThanTheExample() {
    let corrector = kmso()

    // The MDA (4520 ft) is 1314 ft up; the formula gives 136.6 ft, rounded up to 140. The FAA
    // text reads "approximately 150 ft" off the chart by eye and so publishes 4990/4670. The
    // formula is exact, so we assert 10 ft lower on purpose — do not "correct" these to match
    // the example without revisiting the math.
    #expect(corrector.appliedCorrection(for: .final)?.roundedCorrectionFt == 140)
    #expect(corrector.corrected(TestFix(.final, altitudeFt: 4840)).correctedFt == 4980)

    // The MDA itself, corrected, is 4520 + 140 = 4660 (the example's 4670).
    let mdaFt = 4520 + (corrector.appliedCorrection(for: .final)?.roundedCorrectionFt ?? 0)
    #expect(mdaFt == 4660)
  }

  @Test("The Individual Segments Method corrects only the segments the CTA marks")
  func individualSegmentsHonoursTheMarkedSegments() {
    let corrector = kmso(method: .individualSegments)

    // KMSO marks initial, intermediate and final — not missed.
    #expect(corrector.corrected(TestFix(.intermediate, altitudeFt: 6200)).correctedFt == 6500)
    let missed = corrector.corrected(TestFix(.missed, altitudeFt: 12000))
    #expect(missed.correction == .unavailable(.segmentNotSelected))
    #expect(missed.correctedFt == nil)
  }

  @Test("Capping the height at 5000 ft changes the missed correction")
  func heightCapAffectsTheMissedSegment() {
    #expect(
      kmso(extrapolate: false).corrected(TestFix(.missed, altitudeFt: 12000)).correctedFt == 12500
    )
    #expect(
      kmso(extrapolate: true).corrected(TestFix(.missed, altitudeFt: 12000)).correctedFt == 12900
    )
    #expect(kmso(extrapolate: false).appliedCorrection(for: .missed)?.isHeightCapped == true)
  }

  @Test("Round-up rounding raises corrections to the next 100 ft")
  func roundUpMode() {
    let corrector = kmso(rounding: .roundUp)

    // Initial raw correction 313 ft rounds up to 400.
    #expect(corrector.corrected(TestFix(.initial, altitudeFt: 9400)).correctedFt == 9800)
    // Final raw correction 137 ft rounds up to 200.
    #expect(corrector.corrected(TestFix(.final, altitudeFt: 4840)).correctedFt == 5040)
  }

  @Test("A block altitude is corrected on its floor, not its ceiling")
  func blockAltitudeCorrectsTheFloor() {
    // A block in the initial segment: ceiling 6000, floor 3900. All Segments corrects the
    // initial segment from the FAF (6200 ft), +300 ft, applied to the floor.
    let corrected = kmso().corrected(
      TestFix(.initial, .block(ceilingFt: 6000, floorFt: 3900))
    )
    #expect(corrected.published == .block(ceilingFt: 6000, floorFt: 3900))
    #expect(corrected.correctedFt == 4200)
  }

  @Test("A fix the data marks not correctable is left published")
  func notCorrectableFixIsUntouched() {
    // The runway threshold at the MAP is coded not correctable.
    let corrected = kmso().corrected(
      TestFix(.final, altitudeFt: 3237, restriction: .at, correctable: false)
    )
    #expect(corrected.correction == .unavailable(.notCorrectable))
    #expect(corrected.correctedFt == nil)
  }

  @Test("A fix publishing no altitude is reported as such, not as uncorrectable")
  func unpublishedAltitudeIsReportedAsUnpublished() {
    // Path terminators code no altitude and the data marks them not correctable, but the
    // missing altitude is what the row has to explain.
    let corrected = kmso().corrected(TestFix(.initial, .unpublished, correctable: false))

    #expect(corrected.correction == .unavailable(.noPublishedAltitude))
    #expect(corrected.correctedFt == nil)
  }

  @Test("The final segment cannot be corrected until the DA/MDA is entered")
  func finalSegmentNeedsMinimums() {
    let corrector = kmso(minimumsFt: nil)
    let corrected = corrector.corrected(TestFix(.final, altitudeFt: 4840))
    #expect(corrected.correction == .unavailable(.minimumsNotEntered))
  }

  @Test("An unavailable reference leaves its segment uncorrected")
  func unavailableReferenceIsReported() {
    // The Individual Segments Method reads the initial segment's own reference, and KMSO marks
    // that segment, so the unavailable reference is the only thing left to stop the correction.
    let corrector = kmso(
      references: Self.kmsoReferences(initial: .unavailable),
      method: .individualSegments
    )
    let corrected = corrector.corrected(TestFix(.initial, altitudeFt: 9400))
    #expect(corrected.correction == .unavailable(.referenceUnavailable))
  }
}
