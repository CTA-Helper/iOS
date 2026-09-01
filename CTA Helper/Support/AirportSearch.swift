import Foundation
import SwiftData

/// Relevance-ranked airport search over identifier, name and city.
enum AirportSearch {
  /**
   The shortest query worth reading as an airport.

   A single character matches most of the twenty thousand US landing facilities by name or by
   city, and the pickers that call this fire a query per keystroke.
   */
  static let minimumQueryLength = 2

  /**
   The airports a query names, best match first.

   Each tier is read on its own and bounded by `limit`, and the tiers are the ranking: an
   identifier match outranks a name match, which outranks a city match. Reading them apart is
   what keeps the work bounded — ranking one fetch of every match would mean holding every
   airport whose name contains the letter typed.

   - Parameters:
     - query: what was typed — an identifier, a name, or a city.
     - context: the context to read.
     - limit: the most airports to return.
   - Returns: the matching airports, best match first, and none at all for a query too short to
     name one.
   - Throws: whatever the fetch throws.
   */
  static func airports(matching query: String, in context: ModelContext, limit: Int) throws
    -> [Airport]
  {
    let query = query.trimmingCharacters(in: .whitespaces)
    guard query.count >= minimumQueryLength else { return [] }

    var ranked: [Airport] = []
    for predicate in rankedPredicates(matching: query) where ranked.count < limit {
      let known = Set(ranked.map(\.siteNumber))
      ranked += try context.fetch(descriptor(matching: predicate, limit: limit))
        .filter { !known.contains($0.siteNumber) }
    }
    return Array(ranked.prefix(limit))
  }

  /// The match tiers, best first: the identifier the pilot typed, then a name, then a city.
  private static func rankedPredicates(matching query: String) -> [Predicate<Airport>] {
    let upper = query.uppercased()
    // Optionals are compared and chained, never coalesced: SwiftData compiles these to SQL, and
    // `(city ?? "").localizedStandardContains(_:)` is a translation it rejects at fetch time,
    // taking the process down with it.
    return [
      #Predicate<Airport> { $0.faaIdentifier == upper || $0.icaoIdentifier == upper },
      #Predicate<Airport> { $0.name.localizedStandardContains(query) },
      #Predicate<Airport> { $0.city?.localizedStandardContains(query) == true }
    ]
  }

  private static func descriptor(matching predicate: Predicate<Airport>, limit: Int)
    -> FetchDescriptor<Airport>
  {
    var descriptor = FetchDescriptor(predicate: predicate)
    descriptor.fetchLimit = limit
    return descriptor
  }
}
