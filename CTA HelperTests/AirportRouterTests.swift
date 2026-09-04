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
@Suite(.serialized)
struct `Airport routing` {
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

  @Test
  func `choosing an airport clears the approach chosen under the previous one`() {
    let router = makeRouter()
    router.airport = missoula
    router.approach = missoula.approaches[0]

    router.airport = sanFrancisco

    #expect(router.approach == nil)
  }

  @Test
  func `choosing an airport records it as recently opened`() {
    let router = makeRouter()
    router.airport = missoula
    router.airport = sanFrancisco

    #expect(recents == [missoula.siteNumber, sanFrancisco.siteNumber])
  }

  @Test
  func `a route sets both selections without clearing the approach it names`() throws {
    let router = makeRouter()
    let approach = try #require(missoula.approaches.first)

    router.show(approach, at: missoula)

    #expect(router.airport == missoula)
    #expect(router.approach == approach)
    #expect(recents == [missoula.siteNumber])
  }

  @Test
  func `a route to the airport already shown keeps the approach it names`() throws {
    let router = makeRouter()
    router.airport = missoula
    let approach = try #require(missoula.approaches.last)

    router.show(approach, at: missoula)

    #expect(router.approach == approach)
  }

  @Test
  func `a route resolves to the airport and approach the store holds`() throws {
    let approach = try #require(missoula.approaches.first)
    let route = AirportRoute(
      airportSiteNumber: missoula.siteNumber,
      approachIdentifier: approach.identifier
    )

    let resolved = try #require(try route.resolve(in: container.mainContext))

    #expect(resolved.airport == missoula)
    #expect(resolved.approach == approach)
  }

  @Test
  func `a route naming an airport the store does not hold resolves to nothing`() throws {
    let route = AirportRoute(airportSiteNumber: "00000.A", approachIdentifier: nil)

    #expect(try route.resolve(in: container.mainContext) == nil)
  }

  @Test
  func `a route naming no approach resolves to the airport alone`() throws {
    let route = AirportRoute(airportSiteNumber: missoula.siteNumber, approachIdentifier: nil)

    let resolved = try #require(try route.resolve(in: container.mainContext))

    #expect(resolved.airport == missoula)
    #expect(resolved.approach == nil)
  }
}
