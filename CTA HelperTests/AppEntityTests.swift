import Foundation
import SwiftData
import Testing

@testable import CTA_Helper

/**
 The entity layer Shortcuts, Siri and Spotlight address the app through.

 Two things are pinned. The identity a saved Shortcut holds — a site number and an ARINC 424
 code, neither of which the FAA reassigns — has to survive the round trip through the string the
 system stores, because a parse that comes back empty drops the Shortcut without saying so. And
 an intent that fires before the first cycle has been imported has to answer "no such airport",
 not throw and not open a screen onto an empty store.
 */
@MainActor
@Suite("App entities", .serialized)
struct AppEntityTests {
  private let container: ModelContainer
  private let missoula: Airport
  private let eureka: Airport

  private var airports: AirportEntityQuery { .init(container: container) }
  private var approaches: ApproachEntityQuery { .init(container: container) }

  init() throws {
    container = .makeInMemory()
    missoula = PreviewData.missoula()
    eureka = PreviewData.eureka()
    container.mainContext.insert(missoula)
    container.mainContext.insert(eureka)
    try container.mainContext.save()
  }

  @Test("Finds an airport by what the pilot typed")
  func findsAnAirportByQuery() async throws {
    let found = try await airports.entities(matching: "KMSO")

    #expect(found.map(\.id) == [missoula.siteNumber])
    #expect(found.map(\.identifier) == ["KMSO"])
  }

  @Test("Resolves the airport a saved Shortcut names")
  func resolvesASavedAirport() async throws {
    let found = try await airports.entities(for: [missoula.siteNumber])

    #expect(found.map(\.id) == [missoula.siteNumber])
  }

  @Test("Resolves saved airports in the order the system asked for them")
  func resolvesSavedAirportsInOrder() async throws {
    let siteNumbers = [eureka.siteNumber, missoula.siteNumber]

    let found = try await airports.entities(for: siteNumbers)

    #expect(found.map(\.id) == siteNumbers)
  }

  @Test("Answers with nothing for a query too short to name an airport")
  func answersWithNothingForATooShortQuery() async throws {
    #expect(try await airports.entities(matching: "M").isEmpty)
  }

  @Test("Reads a typed approach query as the airport that publishes the procedures")
  func findsApproachesByAirport() async throws {
    let found = try await approaches.entities(matching: "KMSO")

    #expect(found.count == missoula.approaches.count)
    #expect(found.allSatisfy { $0.id.siteNumber == missoula.siteNumber })
  }

  @Test("Resolves the approach a saved Shortcut names")
  func resolvesASavedApproach() async throws {
    let approach = try #require(missoula.approaches.first)
    let id = ApproachID(
      siteNumber: missoula.siteNumber,
      approachIdentifier: approach.identifier
    )

    let found = try await approaches.entities(for: [id])

    #expect(found.map(\.id) == [id])
    #expect(found.map(\.name) == [approach.name])
  }

  @Test("An approach's identity survives the round trip through what the system stores")
  func anApproachIdentityRoundTrips() throws {
    let id = ApproachID(siteNumber: "00218.12A", approachIdentifier: "R12-Y")

    #expect(ApproachID.entityIdentifier(for: id.entityIdentifierString) == id)
  }

  @Test("An identity the system cannot have written resolves to nothing")
  func aMalformedIdentityResolvesToNothing() {
    #expect(ApproachID.entityIdentifier(for: "12453.A") == nil)
  }

  @Test("Answers with nothing before the first cycle is imported")
  func answersWithNothingBeforeAnImport() async throws {
    let empty = AirportEntityQuery(container: .makeInMemory())

    #expect(try await empty.entities(matching: "KMSO").isEmpty)
  }

  @Test("Answers with nothing when the app could not open a store at all")
  func answersWithNothingWithoutAStore() async throws {
    let storeless = AirportEntityQuery(container: nil)

    #expect(try await storeless.entities(for: [missoula.siteNumber]).isEmpty)
  }
}
