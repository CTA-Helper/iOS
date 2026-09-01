import Foundation
import SwiftData
import Testing

@testable import CTA_Helper

/**
 The routing seam both layouts push off.

 What is pinned here is the interaction the two ways of choosing a screen have with each other: a
 tap picks an airport and the approach under the last one has to go, while a route picks both at
 once and the approach it just named has to stay.
 */
@MainActor
@Suite("Airport routing", .serialized)
struct AirportRouterTests {
  private let container: ModelContainer
  private let defaults: UserDefaults
  private let missoula: Airport
  private let sanFrancisco: Airport

  private var recents: [String] {
    defaults.airportIDList(forKey: SettingsKey.recentAirports).ids
  }

  init() throws {
    container = .makeInMemory()
    missoula = PreviewData.missoula()
    sanFrancisco = PreviewData.sanFrancisco()
    container.mainContext.insert(missoula)
    container.mainContext.insert(sanFrancisco)
    try container.mainContext.save()

    defaults = try #require(UserDefaults(suiteName: "AirportRouterTests"))
    defaults.removePersistentDomain(forName: "AirportRouterTests")
  }

  private func makeRouter() -> AirportRouter { .init(defaults: defaults) }

  @Test("Choosing an airport clears the approach chosen under the previous one")
  func choosingAnAirportClearsTheApproach() {
    let router = makeRouter()
    router.airport = missoula
    router.approach = missoula.approaches[0]

    router.airport = sanFrancisco

    #expect(router.approach == nil)
  }

  @Test("Choosing an airport records it as recently opened")
  func choosingAnAirportRecordsARecent() {
    let router = makeRouter()
    router.airport = missoula
    router.airport = sanFrancisco

    #expect(recents == [missoula.siteNumber, sanFrancisco.siteNumber])
  }

  @Test("A route sets both selections without clearing the approach it names")
  func aRouteSetsBothSelections() throws {
    let router = makeRouter()
    let approach = try #require(missoula.approaches.first)

    router.show(approach, at: missoula)

    #expect(router.airport == missoula)
    #expect(router.approach == approach)
    #expect(recents == [missoula.siteNumber])
  }

  @Test("A route to the airport already shown keeps the approach it names")
  func aRouteToTheAirportAlreadyShown() throws {
    let router = makeRouter()
    router.airport = missoula
    let approach = try #require(missoula.approaches.last)

    router.show(approach, at: missoula)

    #expect(router.approach == approach)
  }

  @Test("A route resolves to the airport and approach the store holds")
  func aRouteResolves() throws {
    let approach = try #require(missoula.approaches.first)
    let route = AirportRoute(
      airportSiteNumber: missoula.siteNumber,
      approachIdentifier: approach.identifier
    )

    let resolved = try #require(try route.resolve(in: container.mainContext))

    #expect(resolved.airport == missoula)
    #expect(resolved.approach == approach)
  }

  @Test("A route naming an airport the store does not hold resolves to nothing")
  func anUnknownAirportResolvesToNothing() throws {
    let route = AirportRoute(airportSiteNumber: "00000.A", approachIdentifier: nil)

    #expect(try route.resolve(in: container.mainContext) == nil)
  }

  @Test("A route naming no approach resolves to the airport alone")
  func aRouteToAnAirportAlone() throws {
    let route = AirportRoute(airportSiteNumber: missoula.siteNumber, approachIdentifier: nil)

    let resolved = try #require(try route.resolve(in: container.mainContext))

    #expect(resolved.airport == missoula)
    #expect(resolved.approach == nil)
  }
}
