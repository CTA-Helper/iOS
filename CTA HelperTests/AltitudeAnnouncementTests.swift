import Foundation
import Testing

@testable import CTA_Helper

/**
 What a fix row reads out. The row is one accessibility element, so these strings are the whole
 of what a pilot flying on VoiceOver hears — a number that names neither its unit nor which
 altitude it is would be indistinguishable from the one beside it.
 */
@Suite
struct `Altitude announcements` {
  @Test
  func `a corrected altitude reads out the value that supersedes the published one`() {
    let altitude = CorrectedAltitude(
      published: .single(ft: 10000, restriction: .atOrAbove, glidepathFt: nil),
      correction: .add(.feet(700))
    )

    #expect(altitude.announcement == "10,700 feet, minimum altitude")
    #expect(altitude.supersededAnnouncement == "10,000 feet")
    #expect(altitude.correctionAnnouncement == "+700 feet")
  }

  @Test
  func `an uncorrected altitude reads out what the procedure published`() {
    let altitude = CorrectedAltitude(
      published: .single(ft: 6200, restriction: .atOrAbove, glidepathFt: nil),
      correction: .unavailable(.segmentNotSelected)
    )

    #expect(altitude.announcement == "6,200 feet, minimum altitude")
    #expect(altitude.supersededAnnouncement == nil)
    #expect(altitude.correctionAnnouncement == nil)
  }

  /**
   ENR 1.8 raises a block's obstacle-clearance floor and leaves its ceiling as published, so both
   bounds are spoken. Flattened to one number, the row would announce an altitude it does not
   claim.
   */
  @Test
  func `a block reads out both bounds, over the corrected floor`() {
    let altitude = CorrectedAltitude(
      published: .block(ceilingFt: 7000, floorFt: 5000),
      correction: .add(.feet(200))
    )

    #expect(altitude.announcement == "5,200 feet to 7,000 feet")
    #expect(altitude.supersededAnnouncement == "floor 5,000 feet")
  }

  /**
   ENR 1.8 never corrects a glidepath altitude, and a bare second number spoken beside a
   corrected one is the worst confusion this screen could produce, so it is named separately
   rather than folded into the reading.
   */
  @Test
  func `a glidepath altitude is named apart from the altitude that was corrected`() {
    let altitude = CorrectedAltitude(
      published: .single(ft: 3200, restriction: .glideslope, glidepathFt: 2100),
      correction: .unavailable(.notCorrectable)
    )

    #expect(altitude.announcement == "3,200 feet, recommended altitude")
    #expect(altitude.glidepathAnnouncement == "2,100 feet")
  }

  @Test
  func `a leg publishing no altitude says so rather than reading out a dash`() {
    let altitude = CorrectedAltitude(
      published: .unpublished,
      correction: .unavailable(.noPublishedAltitude)
    )

    #expect(altitude.announcement == "No published altitude")
    #expect(altitude.supersededAnnouncement == nil)
    #expect(altitude.glidepathAnnouncement == nil)
  }
}
