import Foundation
import Testing

@testable import CTA_Helper

/**
 Anchors the whole import pipeline — decode the published JSON, build the models, correct the
 approach — on a real fixture: Missoula's RNAV (GPS) Y RWY 12, extracted verbatim from the
 release asset.
 */
private final class BundleMarker {}

struct NavDataImportTests {
  private func loadFixture() throws -> NavDataDocument {
    let url = try #require(
      Bundle(for: BundleMarker.self).url(forResource: "KMSO", withExtension: "json")
    )
    return try JSONDecoder().decode(NavDataDocument.self, from: Data(contentsOf: url))
  }

  @Test
  func `the fixture decodes to the expected airport, approach and fix counts`() throws {
    let document = try loadFixture()

    #expect(document.airports.count == 1)
    let airport = try #require(document.airports.first)
    #expect(airport.siteNumber == "12453.A")
    #expect(airport.faaIdentifier == "MSO")
    #expect(airport.icaoIdentifier == "KMSO")
    #expect(airport.elevationFt == 3206)
    #expect(airport.coldTemperature?.affectedSegments == [.initial, .intermediate, .final])
    #expect(airport.approaches.count == 1)
    #expect(airport.approaches.first?.fixes.count == 18)
  }

  /**
   Dropping the leg instead would leave the pilot an approach missing one of the fixes it flies,
   so a sequence the wire cannot mean has to stop the import rather than thin the procedure.
   */
  @Test
  func `a leg whose sequence cannot be read fails the import rather than being dropped`() {
    let leg = """
      {"identifier": "CHARL", "transition": "CHARL", "sequence": -10, "legType": "IF",
       "role": null, "segment": "initial", "altitude": null, "altitude2": null,
       "altitudeDescription": "at", "flyover": false, "correctable": false}
      """

    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(FixDTO.self, from: Data(leg.utf8))
    }
  }

  @Test
  func `the decoded models correct to the ENR 1.8 6.a answers`() throws {
    let airport = try #require(loadFixture().airports.first?.makeAirport())
    let approach = try #require(airport.approaches.first)

    let corrector = ApproachCorrector(
      elevation: airport.elevation,
      referenceAltitudes: approach.referenceAltitudes,
      reportedTemperature: .celsius(-12),
      coldTemperature: airport.coldTemperature,
      method: .allSegments,
      rounding: .nearestHundred,
      extrapolateAboveTable: false,
      minimumsAltitude: .feet(4520)
    )

    func correctedAltitude(
      of identifier: String,
      role: FixRole? = nil
    ) throws -> Measurement<UnitLength>? {
      let fix = try #require(
        approach.fixes.first {
          $0.identifier == identifier && (role == nil || $0.role == role)
        }
      )
      return corrector.corrected(fix).corrected
    }

    #expect(try correctedAltitude(of: "LANNY") == .feet(9700))
    #expect(try correctedAltitude(of: "CALIP") == .feet(7300))
    #expect(try correctedAltitude(of: "SUPPY") == .feet(6500))
    // JENKI is coded twice (an initial IF and the missed holding fix); check the holding one.
    #expect(try correctedAltitude(of: "JENKI", role: .missedHolding) == .feet(12500))
  }
}

/**
 The published digest is the only thing standing between a mangled download and altitudes a
 pilot flies, so each way a download can fail to be what the manifest describes is pinned to the
 error it raises.
 */
@Suite
struct `Nav data integrity` {
  private let payload = Data("the published cycle".utf8)

  private func manifestFile(
    sha256: String? = nil,
    bytes: UInt? = nil
  ) -> NavDataManifest.DataFile {
    .init(
      filename: "cta-navdata.json.gz",
      bytes: bytes ?? UInt(payload.count),
      uncompressedBytes: 4096,
      sha256: sha256 ?? NavDataIntegrity.sha256(of: payload)
    )
  }

  @Test
  func `a download matching the published digest and size verifies`() throws {
    try NavDataIntegrity.verify(payload, against: manifestFile())
  }

  @Test
  func `a download that does not hash to the published digest is refused`() {
    let file = manifestFile(sha256: String(repeating: "0", count: 64))

    #expect(throws: NavDataError.self) {
      try NavDataIntegrity.verify(payload, against: file)
    }
  }

  /**
   Size is checked first, so a truncated download reports the length it actually got rather
   than a digest mismatch that says nothing about why.
   */
  @Test
  func `a truncated download is refused for its size, not its digest`() throws {
    let truncated = payload.dropLast(4)
    let error = try #require(throws: NavDataError.self) {
      try NavDataIntegrity.verify(Data(truncated), against: manifestFile())
    }

    guard case let .sizeMismatch(expectedBytes, actualBytes) = error else {
      Issue.record("expected a size mismatch, got \(error)")
      return
    }
    #expect(expectedBytes == UInt(payload.count))
    #expect(actualBytes == UInt(truncated.count))
  }

  @Test
  func `a decompressed document of the wrong length is refused`() {
    #expect(throws: NavDataError.self) {
      try NavDataIntegrity.verifySize(of: payload, expecting: UInt(payload.count) + 1)
    }
  }

  /// Digests are published lowercase, but a hex digest means the same thing in either case.
  @Test
  func `a digest published in uppercase still matches`() throws {
    let file = manifestFile(sha256: NavDataIntegrity.sha256(of: payload).uppercased())

    try NavDataIntegrity.verify(payload, against: file)
  }
}

/**
 The wire's two nullable altitudes and separate description admit combinations that mean
 nothing; these pin down what each one resolves to before it reaches the store.
 */
@Suite
struct `Published altitude normalization` {
  @Test
  func `a block reads its second altitude as the floor`() {
    #expect(
      AltitudeDescription.between.publishedAltitude(altitudeFt: 6000, altitude2Ft: 3900)
        == .block(ceilingFt: 6000, floorFt: 3900)
    )
  }

  @Test
  func `a block the procedure gave no floor keeps the ceiling it did publish`() {
    #expect(
      AltitudeDescription.between.publishedAltitude(altitudeFt: 6000, altitude2Ft: nil)
        == .single(ft: 6000, restriction: .atOrBelow, glidepathFt: nil)
    )
  }

  @Test
  func `every other description reads its second altitude as the glidepath altitude`() {
    #expect(
      AltitudeDescription.glideslope.publishedAltitude(altitudeFt: 3200, altitude2Ft: 2100)
        == .single(ft: 3200, restriction: .glideslope, glidepathFt: 2100)
    )
  }

  @Test(arguments: [AltitudeDescription.at, .between, .stepDownVNAV])
  func `a fix with no primary altitude publishes nothing, whatever else it codes`(
    description: AltitudeDescription
  ) {
    #expect(description.publishedAltitude(altitudeFt: nil, altitude2Ft: 4840) == .unpublished)
  }

  @Test
  func `an ARINC code the app does not map decodes as a plain at restriction`() throws {
    let decoded = try JSONDecoder()
      .decode(AltitudeDescription.self, from: Data(#""unknown""#.utf8))

    #expect(decoded == .at)
  }
}
