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
 not throw and not open a screen onto an empty store. The order airports come back in is pinned
 too: a fetch answers in import order, and the suggestions a picker shows are ordered by the pilot
 — starred as they starred them, opened newest first.
 */
@MainActor
@Suite(.serialized)
struct `App entities` {
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

  @Test
  func `finds an airport by what the pilot typed`() async throws {
    let found = try await airports.entities(matching: "KMSO")

    #expect(found.map(\.id) == [missoula.siteNumber])
    #expect(found.map(\.identifier) == ["KMSO"])
  }

  @Test
  func `resolves the airport a saved Shortcut names`() async throws {
    let found = try await airports.entities(for: [missoula.siteNumber])

    #expect(found.map(\.id) == [missoula.siteNumber])
  }

  // Asked both ways round: one order or the other is the one the store would have answered in on
  // its own, so a single direction can pass without the airports having been ordered at all.
  @Test
  func `resolves saved airports in the order the system asked for them`() async throws {
    let siteNumbers = [eureka.siteNumber, missoula.siteNumber]
    let reversed = Array(siteNumbers.reversed())

    #expect(try await airports.entities(for: siteNumbers).map(\.id) == siteNumbers)
    #expect(try await airports.entities(for: reversed).map(\.id) == reversed)
  }

  @Test
  func `answers with nothing for a query too short to name an airport`() async throws {
    #expect(try await airports.entities(matching: "M").isEmpty)
  }

  @Test
  func `reads a typed approach query as the airport that publishes the procedures`() async throws {
    let found = try await approaches.entities(matching: "KMSO")

    #expect(found.count == missoula.approaches.count)
    #expect(found.allSatisfy { $0.id.siteNumber == missoula.siteNumber })
  }

  @Test
  func `resolves the approach a saved Shortcut names`() async throws {
    let approach = try #require(missoula.approaches.first)
    let id = ApproachID(
      siteNumber: missoula.siteNumber,
      approachIdentifier: approach.identifier
    )

    let found = try await approaches.entities(for: [id])

    #expect(found.map(\.id) == [id])
    #expect(found.map(\.name) == [approach.name])
  }

  @Test
  func `an approach's identity survives the round trip through what the system stores`() throws {
    let id = ApproachID(siteNumber: "00218.12A", approachIdentifier: "R12-Y")

    #expect(ApproachID.entityIdentifier(for: id.entityIdentifierString) == id)
  }

  @Test
  func `an identity the system cannot have written resolves to nothing`() {
    #expect(ApproachID.entityIdentifier(for: "12453.A") == nil)
  }

  @Test
  func `answers with nothing before the first cycle is imported`() async throws {
    let empty = AirportEntityQuery(container: .makeInMemory())

    #expect(try await empty.entities(matching: "KMSO").isEmpty)
  }

  @Test
  func `answers with nothing when the app could not open a store at all`() async throws {
    let storeless = AirportEntityQuery(container: nil)

    #expect(try await storeless.entities(for: [missoula.siteNumber]).isEmpty)
  }
}
