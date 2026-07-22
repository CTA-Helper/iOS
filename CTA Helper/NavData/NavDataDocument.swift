import Foundation

/**
 The decoded `cta-navdata.json.gz` document — a data-transfer view that decodes the JSON,
 then builds the persisted ``Airport`` / ``Approach`` / ``Fix`` models.

 The enums decode leniently through the DTO: an unrecognized altitude description or role is
 mapped to a safe default (or dropped) rather than throwing, so one odd record can never
 fail the import of the whole database.
 */
struct NavDataDocument: Decodable {
  let airports: [AirportDTO]
}

struct AirportDTO: Decodable {
  let siteNumber: String
  let faaIdentifier: String
  let icaoIdentifier: String?
  let name: String
  let city: String?
  let state: String?
  let stateName: String?
  let elevationFt: Int?
  let latitude: Double?
  let longitude: Double?
  let coldTemperature: ColdTemperatureRestriction?
  let approaches: [ApproachDTO]

  private enum CodingKeys: String, CodingKey {
    case siteNumber, faaIdentifier, icaoIdentifier, name, city, state, stateName
    case elevationFt = "elevation"
    case latitude, longitude, coldTemperature, approaches
  }
}

struct ApproachDTO: Decodable {
  let identifier: String
  let name: String
  let runway: String?
  let chartURL: String?
  let referenceAltitudes: ReferenceAltitudesDTO
  let fixes: [FixDTO]

  private enum CodingKeys: String, CodingKey {
    case identifier, name, runway
    case chartURL = "chartUrl"
    case referenceAltitudes, fixes
  }
}

/**
 The wire form of ``ReferenceAltitudes``: the JSON codes each reference altitude in feet under
 the key `altitude`, beside a source naming where it came from. Decoding into a DTO keeps that
 wire shape off the persisted model, where the pairing becomes a single ``ReferenceAltitude``
 that can no longer name a source without the altitude it published.
 */
struct ReferenceAltitudesDTO: Decodable {
  let initial: ReferenceDTO
  let intermediate: ReferenceDTO
  let final: ReferenceDTO
  let missed: ReferenceDTO
  let allSegments: ReferenceDTO

  var model: ReferenceAltitudes {
    ReferenceAltitudes(
      initial: initial.model,
      intermediate: intermediate.model,
      final: final.model,
      missed: missed.model,
      allSegments: allSegments.model
    )
  }
}

struct ReferenceDTO: Decodable {
  let altitudeFt: Int?
  let source: Source

  var model: ReferenceAltitude {
    switch source {
      case .intermediateFix: published(from: .intermediateFix)
      case .finalApproachFix: published(from: .finalApproachFix)
      case .missedHolding: published(from: .missedHolding)
      case .pilotEntered: .pilotEntered
      case .unavailable: .unavailable
    }
  }

  /**
   The published reference, or ``ReferenceAltitude/unavailable`` when the wire named the fix
   the reference comes from but coded no altitude for it.
   */
  private func published(from source: PublishedReferenceSource) -> ReferenceAltitude {
    guard let altitudeFt else { return .unavailable }
    return .published(ft: altitudeFt, source: source)
  }

  /**
   Where the wire says a reference altitude comes from. ``pilotEntered`` and ``unavailable``
   are the two that never publish an altitude, and become ``ReferenceAltitude`` cases in their
   own right rather than a source paired with a missing one.
   */
  enum Source: String, Decodable {
    case intermediateFix = "if"
    case finalApproachFix = "faf"
    // These decode from the nav data JSON, whose values are exactly these camelCase names, so
    // their raw values are intentionally the case names.
    // swiftlint:disable raw_value_for_camel_cased_codable_enum
    case missedHolding
    case pilotEntered
    case unavailable
    // swiftlint:enable raw_value_for_camel_cased_codable_enum
  }

  private enum CodingKeys: String, CodingKey {
    case altitudeFt = "altitude"
    case source
  }
}

/**
 A leg's position within its procedure, as the wire codes it.

 ARINC 424 numbers legs from 10 upward, so a negative value is corrupt data rather than a
 procedure the app does not recognize. Decoding it fails the import, because the alternative —
 dropping the leg — would show the pilot an approach missing one of the fixes it flies.
 */
struct SequenceNumber: Decodable {
  let value: UInt

  init(from decoder: any Decoder) throws {
    let coded = try decoder.singleValueContainer().decode(Int.self)
    guard let value = UInt(exactly: coded) else {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: decoder.codingPath,
          debugDescription: "A leg's sequence number cannot be negative; this one codes \(coded)."
        )
      )
    }
    self.value = value
  }
}

struct FixDTO: Decodable {
  let identifier: String?
  let transition: String?
  let sequence: SequenceNumber
  let legType: String
  let role: String?
  let segment: Segment
  let altitudeFt: Int?
  let altitude2Ft: Int?
  let altitudeDescription: AltitudeDescription
  let flyover: Bool
  let correctable: Bool

  private enum CodingKeys: String, CodingKey {
    case identifier, transition, sequence, legType, role, segment
    case altitudeFt = "altitude"
    case altitude2Ft = "altitude2"
    case altitudeDescription, flyover, correctable
  }
}

extension AirportDTO {
  /**
   Build the persisted airport, or `nil` if it lacks the elevation and coordinates every
   correction and the nearest query need (no airport in the published data does).
   */
  func makeAirport() -> Airport? {
    guard let elevationFt, let latitude, let longitude else { return nil }

    let airport = Airport(
      siteNumber: siteNumber,
      faaIdentifier: faaIdentifier,
      icaoIdentifier: icaoIdentifier,
      name: name,
      city: city,
      state: state,
      stateName: stateName,
      elevationFt: elevationFt,
      latitude: latitude,
      longitude: longitude,
      coldTemperature: coldTemperature
    )
    airport.approaches = approaches.map { $0.makeApproach() }
    return airport
  }
}

extension ApproachDTO {
  func makeApproach() -> Approach {
    let approach = Approach(
      identifier: identifier,
      name: name,
      runway: runway,
      chartURL: chartURL.flatMap(URL.init(string:)),
      referenceAltitudes: referenceAltitudes.model
    )
    approach.fixes = fixes.map { $0.makeFix() }
    return approach
  }
}

extension FixDTO {
  func makeFix() -> Fix {
    Fix(
      identifier: identifier,
      transition: transition,
      sequence: sequence.value,
      legType: LegType(rawValue: legType),
      role: role.flatMap(FixRole.init(rawValue:)),
      segment: segment,
      publishedAltitude: altitudeDescription.publishedAltitude(
        altitudeFt: altitudeFt,
        altitude2Ft: altitude2Ft
      ),
      flyover: flyover,
      isCorrectable: correctable
    )
  }
}
