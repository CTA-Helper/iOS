import CoreLocation
import Foundation
import SwiftData

#if DEBUG
  /**
   Sample data for SwiftUI previews: Missoula (KMSO, a CTA with the ENR 1.8 example approach)
   and San Francisco (KSFO, not a CTA), in an in-memory store.
   */
  enum PreviewData {
    /**
     Missoula Intl — a Cold Temperature Airport marked for the initial, intermediate and final
     segments — with an approach roster spanning three runways and a circling-only procedure.

     Only the first approach, the RNAV (GPS) Y RWY 12 worked in ENR 1.8 6.a, carries fixes; the
     rest exist to populate the approach list. The roster is deliberately out of both runway and
     chart order, so a preview shows the list sorting it.
     */
    static func missoula() -> Airport {
      let airport = Airport(
        siteNumber: "12453.A",
        faaIdentifier: "MSO",
        icaoIdentifier: "KMSO",
        name: "Missoula Montana",
        city: "Missoula",
        state: "MT",
        stateName: "Montana",
        elevationFt: 3206,
        latitude: 46.916_3,
        longitude: -114.090_6,
        coldTemperature: ColdTemperatureRestriction(
          restrictionTemperatureC: -11,
          affectedSegments: [.initial, .intermediate, .final]
        )
      )
      airport.approaches = [
        rnavY12(),
        charted("R12-Z", "RNAV (GPS) Z RWY 12", runway: "12"),
        charted("R30", "RNAV (GPS) RWY 30", runway: "30"),
        charted("V-A", "VOR-A", runway: nil),
        charted("R08", "RNAV (GPS) RWY 08", runway: "08"),
        charted("I12", "ILS OR LOC RWY 12", runway: "12")
      ]
      return airport
    }

    /// San Francisco Intl — a busy airport that is not a CTA.
    static func sanFrancisco() -> Airport {
      Airport(
        siteNumber: "02187.A",
        faaIdentifier: "SFO",
        icaoIdentifier: "KSFO",
        name: "San Francisco Intl",
        city: "San Francisco",
        state: "CA",
        stateName: "California",
        elevationFt: 13,
        latitude: 37.618_8,
        longitude: -122.375_4,
        coldTemperature: nil
      )
    }

    /// Eureka — a Cold Temperature Airport with no ICAO code, only an FAA location identifier.
    static func eureka() -> Airport {
      Airport(
        siteNumber: "13054.A",
        faaIdentifier: "05U",
        icaoIdentifier: nil,
        name: "Eureka",
        city: "Eureka",
        state: "NV",
        stateName: "Nevada",
        elevationFt: 5958,
        latitude: 39.603_8,
        longitude: -116.003_6,
        coldTemperature: ColdTemperatureRestriction(
          restrictionTemperatureC: -17,
          affectedSegments: [.final]
        )
      )
    }

    /**
     A cycle to stand over seeded airports, current or already expired.

     Seeded data with no cycle beside it reads as a half-written import, and the app would offer
     to download the nav data rather than show the airports — so anything that seeds a store
     seeds one of these too.
     */
    static func navDataCycle(expired: Bool = false) -> NavDataCycle {
      let day: TimeInterval = 24 * 3600
      let effectiveDate = Date.now.addingTimeInterval(expired ? -56 * day : -7 * day)
      return NavDataCycle(
        airacCycle: expired ? "2605" : "2607",
        effectiveDate: effectiveDate,
        expirationDate: effectiveDate.addingTimeInterval(28 * day),
        sha256: "preview",
        importedAt: effectiveDate
      )
    }

    private static func rnavY12() -> Approach {
      let approach = Approach(
        identifier: "R12-Y",
        name: "RNAV (GPS) Y RWY 12",
        runway: "12",
        chartURL: URL(string: "https://aeronav.faa.gov/d-tpp/2607/00266R12Y.PDF"),
        referenceAltitudes: ReferenceAltitudes(
          initial: .published(ft: 9400, source: .intermediateFix),
          intermediate: .published(ft: 6200, source: .finalApproachFix),
          final: .pilotEntered,
          missed: .published(ft: 12000, source: .missedHolding),
          allSegments: .published(ft: 6200, source: .finalApproachFix)
        )
      )
      approach.fixes = makeFixes()
      return approach
    }

    /**
     A procedure with no coded fixes — enough to fill a row of the approach list, without the
     fix detail only ``rnavY12()`` carries.
     */
    private static func charted(_ identifier: String, _ name: String, runway: String?) -> Approach {
      Approach(
        identifier: identifier,
        name: name,
        runway: runway,
        chartURL: nil,
        referenceAltitudes: ReferenceAltitudes(
          initial: .unavailable,
          intermediate: .unavailable,
          final: .pilotEntered,
          missed: .unavailable,
          allSegments: .unavailable
        )
      )
    }

    /**
     The legs a procedure flies to something other than a fix — a climb to an altitude, a
     heading to an intercept — which a fix row heads with the instruction rather than a name.
     */
    static func pathTerminators() -> [Fix] {
      [
        pathTerminator(.courseToAltitude, .missed, altitudeFt: 3400, sequence: 40),
        pathTerminator(.headingToIntercept, .missed, altitudeFt: nil, sequence: 50),
        pathTerminator(.procedureTurn, .initial, altitudeFt: 9400, sequence: 60)
      ]
    }

    private static func makeFixes() -> [Fix] {
      [
        fix("LANNY", .iaf, .initial, 9400, sequence: 10, transition: "JENKI"),
        fix("ODIRE", .if, .initial, 9400, sequence: 20, transition: "JENKI"),
        fix("CHARL", .iaf, .initial, 10000, sequence: 10, transition: "CHARL"),
        fix("ODIRE", .if, .initial, 9400, sequence: 20, transition: "CHARL"),
        fix("ODIRE", .facf, .initial, 9400, sequence: 10),
        fix("CALIP", nil, .intermediate, 7000, sequence: 20),
        fix("SUPPY", .faf, .intermediate, 6200, sequence: 30),
        fix("BEGPE", .stepdown, .final, 4840, sequence: 40, restriction: .stepDownVNAV),
        fix("RW12", .map, .final, 3247, sequence: 50, restriction: .at, correctable: false),
        // The missed approach climbs to 3,400 before turning, exactly as the procedure codes it:
        // a leg that ends at an altitude rather than at a fix, and so has no identifier to name.
        pathTerminator(.courseToAltitude, .missed, altitudeFt: 3400, sequence: 60),
        fix(
          "JENKI",
          .missedHolding,
          .missed,
          12000,
          sequence: 90,
          legType: .holdToManualTermination
        )
      ]
    }

    private static func fix(
      _ identifier: String,
      _ role: FixRole?,
      _ segment: Segment,
      _ altitudeFt: Int,
      sequence: UInt,
      transition: String? = nil,
      restriction: AltitudeRestriction = .atOrAbove,
      correctable: Bool = true,
      legType: LegType = .trackToFix
    ) -> Fix {
      Fix(
        identifier: identifier,
        transition: transition,
        sequence: sequence,
        legType: legType,
        role: role,
        segment: segment,
        publishedAltitude: .single(ft: altitudeFt, restriction: restriction, glidepathFt: nil),
        flyover: false,
        isCorrectable: correctable
      )
    }

    private static func pathTerminator(
      _ legType: LegType,
      _ segment: Segment,
      altitudeFt: Int?,
      sequence: UInt
    ) -> Fix {
      Fix(
        identifier: nil,
        transition: nil,
        sequence: sequence,
        legType: legType,
        role: nil,
        segment: segment,
        publishedAltitude:
          altitudeFt
          .map { .single(ft: $0, restriction: .atOrAbove, glidepathFt: nil) } ?? .unpublished,
        flyover: false,
        isCorrectable: altitudeFt != nil
      )
    }
  }

  extension CLLocation {
    /// A position a few miles north of Missoula, so ``PreviewData/missoula()`` is the nearest.
    static let nearMissoula = CLLocation(latitude: 46.983_3, longitude: -114.090_6)
  }

  extension METARObservation {
    /// A cold observation, the one the fix list's correction is worth doing for.
    static let preview = METARObservation(
      stationID: "KMSO",
      temperature: .celsius(-20),
      date: Date(timeIntervalSinceReferenceDate: 806_000_000),
      rawText: "KMSO 241953Z 30012KT 10SM FEW070 M20/M24 A3002 RMK AO2 SLP215"
    )

    /**
     An observation above a Cold Temperature Airport's restriction, so the badge shows that
     nothing needs correcting at Missoula today.
     */
    static let previewWarm = METARObservation(
      stationID: "KMSO",
      temperature: .celsius(5),
      date: Date(timeIntervalSinceReferenceDate: 806_000_000),
      rawText: "KMSO 241953Z 30012KT 10SM FEW070 05/M04 A3002 RMK AO2 SLP215"
    )

    /**
     An observation warmer than the reported-temperature slider spans, which the fix list pins
     to the slider's warm end.
     */
    static let previewOffScale = METARObservation(
      stationID: "KBDN",
      temperature: .celsius(31),
      date: Date(timeIntervalSinceReferenceDate: 806_000_000),
      rawText: "KBDN 241953Z 30012KT 10SM CLR 31/M01 A3002 RMK AO2 SLP128"
    )

    /// An observation whose METAR filed no temperature, so nothing auto-fills from it.
    static let previewWithoutTemperature = METARObservation(
      stationID: "K05U",
      temperature: nil,
      date: Date(timeIntervalSinceReferenceDate: 806_000_000),
      rawText: "K05U 241953Z AUTO 30012KT 10SM CLR A3002 RMK AO2"
    )
  }

  extension ApproachCorrector {
    /**
     A corrector for an airport's first approach, so a preview of a single row or section can
     show a real correction without assembling the whole calculation itself.

     - Parameters:
       - airport: the airport whose first approach is corrected.
       - temperature: the reported temperature.
       - minimums: the pilot-entered DA or MDA, or `nil` for minimums not yet entered.
     */
    static func preview(
      for airport: Airport,
      temperature: Measurement<UnitTemperature> = .celsius(-20),
      method: CorrectionMethod = .allSegments,
      minimums: Measurement<UnitLength>? = .feet(4520)
    ) -> Self {
      Self(
        elevation: airport.elevation,
        referenceAltitudes: airport.approaches[0].referenceAltitudes,
        reportedTemperature: temperature,
        coldTemperature: airport.coldTemperature,
        method: method,
        rounding: .nearestHundred,
        extrapolateAboveTable: false,
        minimumsAltitude: minimums
      )
    }
  }

  extension UserDefaults {
    /**
     A settings store previewing the Individual Segments Method, which a preview hands to
     `@AppStorage` through `defaultAppStorage(_:)`.

     A screen driven by a stored setting can only be previewed in one of its states otherwise,
     and the state worth seeing is the one where a segment goes uncorrected.
     */
    @MainActor static let individualSegmentsPreview: UserDefaults = {
      let defaults = UserDefaults(suiteName: "preview.individualSegments") ?? .standard
      defaults.set(
        CorrectionMethod.individualSegments.rawValue,
        forKey: SettingsKey.correctionMethod
      )
      return defaults
    }()
  }

  extension ModelContainer {
    /// An in-memory container seeded with ``PreviewData`` for previews.
    @MainActor static let preview: ModelContainer = {
      let container = makeInMemory()
      container.mainContext.insert(PreviewData.missoula())
      container.mainContext.insert(PreviewData.sanFrancisco())
      container.mainContext.insert(PreviewData.navDataCycle())
      return container
    }()

    /// An empty in-memory container, for previews and tests that seed their own data.
    @MainActor
    static func makeInMemory() -> ModelContainer {
      do {
        return try ModelContainer(
          for: Airport.self,
          NavDataCycle.self,
          configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
      } catch {
        fatalError("Could not create in-memory ModelContainer: \(error)")
      }
    }
  }

  extension FixRole {
    /// Short aliases so preview data reads like the plate.
    fileprivate static let iaf = FixRole.initialApproachFix
    fileprivate static let `if` = FixRole.intermediateFix
    fileprivate static let facf = FixRole.finalApproachCourseFix
    fileprivate static let faf = FixRole.finalApproachFix
    fileprivate static let map = FixRole.missedApproachPoint
  }
#endif
