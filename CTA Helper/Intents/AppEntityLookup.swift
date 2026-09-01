import Foundation
import SwiftData
import os

/// The nav data an entity query reads, fetched off the main actor.
@ModelActor
actor AppEntityLookup {
  private static let logger = Logger(subsystem: "codes.tim.CTA-Helper", category: "AppIntents")

  /// The most airports a typed query resolves to, matching what the Search tab lists.
  private static let airportLimit = 20
  /// The airports a typed approach query reads its procedures from.
  private static let approachAirportLimit = 3
  /// The most approaches a picker is offered, typed against or suggested.
  private static let approachLimit = 30

  /**
   Read entities out of a store, answering with none where there is nothing to read.

   An intent can fire before the first AIRAC cycle has been imported — the system launches the app
   to run one — and can fire against a store that would not open at all. Both have to read as “no
   such airport”: Shortcuts reports no match, rather than opening a screen onto an empty store.

   - Parameters:
     - container: the store to read, or `nil` when the app could not open one.
     - body: the lookup to run.
   - Returns: what the lookup found, or nothing.
   */
  static func lookUp<Entity: Sendable>(
    in container: ModelContainer?,
    _ body: (AppEntityLookup) async throws -> [Entity]
  ) async -> [Entity] {
    guard let container else { return [] }
    do {
      return try await body(.init(modelContainer: container))
    } catch {
      logger.error("An App Intent lookup failed: \(error)")
      return []
    }
  }

  /// The airports a saved Shortcut or a Spotlight result names, by site number.
  func airports(for siteNumbers: [String]) throws -> [AirportEntity] {
    try airports(withSiteNumbers: siteNumbers).map(AirportEntity.init)
  }

  /// The airports a typed query names — an identifier, a name, or a city.
  func airports(matching query: String) throws -> [AirportEntity] {
    try AirportSearch.airports(matching: query, in: modelContext, limit: Self.airportLimit)
      .map(AirportEntity.init)
  }

  /// The approaches a saved Shortcut or a Spotlight result names, in the order they were named.
  func approaches(for ids: [ApproachID]) throws -> [ApproachEntity] {
    try airports(withSiteNumbers: Array(Set(ids.map(\.siteNumber))))
      .flatMap(\.approaches)
      .compactMap(ApproachEntity.init)
      .ordered(by: ids)
  }

  /**
   The approaches a typed query names.

   The query is read as an airport — `KMSO`, `Missoula` — because an approach a pilot picks in
   Shortcuts is one at an airport they fly, while a procedure name on its own, `RNAV (GPS) Y RWY
   12`, names hundreds of them across the country.
   */
  func approaches(matching query: String) throws -> [ApproachEntity] {
    let airports = try AirportSearch.airports(
      matching: query,
      in: modelContext,
      limit: Self.approachAirportLimit
    )
    return approaches(at: airports)
  }

  /// A picker's worth of approaches at the pilot's own airports, to offer before they type.
  func suggestedApproaches(atAirports siteNumbers: [String]) throws -> [ApproachEntity] {
    try approaches(at: airports(withSiteNumbers: siteNumbers))
  }

  /// Every approach the named airports publish, which is what Spotlight holds alongside them.
  func approaches(atAirports siteNumbers: [String]) throws -> [ApproachEntity] {
    try airports(withSiteNumbers: siteNumbers)
      .flatMap(\.approaches)
      .compactMap(ApproachEntity.init)
  }

  /// As many approaches as a picker shows, in the order the charts come.
  private func approaches(at airports: [Airport]) -> [ApproachEntity] {
    airports
      .flatMap { $0.approaches.inJeppesenChartOrder() }
      .prefix(Self.approachLimit)
      .compactMap(ApproachEntity.init)
  }

  /**
   The named airports, in the order they were named.

   The store answers a `contains` fetch in its own order, which is neither the order the system
   asked for its entities in nor the order the pilot put their favorites in.
   */
  private func airports(withSiteNumbers siteNumbers: [String]) throws -> [Airport] {
    guard !siteNumbers.isEmpty else { return [] }
    let fetched = try modelContext.fetch(
      FetchDescriptor(predicate: #Predicate<Airport> { siteNumbers.contains($0.siteNumber) })
    )
    let bySiteNumber = Dictionary(fetched.map { ($0.siteNumber, $0) }) { first, _ in first }
    return siteNumbers.compactMap { bySiteNumber[$0] }
  }
}

extension Array where Element: Identifiable {
  /// The elements in the order these identifiers name them, dropping any the store cannot answer.
  fileprivate func ordered(by ids: [Element.ID]) -> [Element] {
    let byID = Dictionary(map { ($0.id, $0) }) { first, _ in first }
    return ids.compactMap { byID[$0] }
  }
}
