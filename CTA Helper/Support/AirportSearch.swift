import Foundation
import SwiftData

/**
 How closely an airport matches a query, ordered worst to best: results are sorted on this, so an
 identifier match outranks a name match, which outranks a city match.
 */
private enum Relevance: Int, Comparable {
  case none
  case city
  case name
  case identifier

  static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Relevance-ranked airport search over identifier, name and city.
enum AirportSearch {
  /**
   The airports a query names, best match first.

   - Parameters:
     - query: what was typed — an identifier, a name, or a city.
     - context: the context to read.
     - limit: the most airports to return.
   - Returns: the matching airports, best match first.
   - Throws: whatever the fetch throws.
   */
  static func airports(matching query: String, in context: ModelContext, limit: Int) throws
    -> [Airport]
  {
    let upper = query.uppercased()
    return
      try context.fetch(FetchDescriptor(predicate: predicate(matching: query, upper: upper)))
      .map { ($0, relevance(of: $0, query: query, upper: upper)) }
      .sorted { $0.1 > $1.1 }
      .prefix(limit)
      .map(\.0)
  }

  private static func predicate(matching query: String, upper: String) -> Predicate<Airport> {
    // Optionals are compared and chained, never coalesced: SwiftData compiles this to SQL, and
    // `(city ?? "").localizedStandardContains(_:)` is a translation it rejects at fetch time,
    // taking the process down with it.
    #Predicate<Airport> {
      $0.faaIdentifier == upper
        || $0.icaoIdentifier == upper
        || $0.name.localizedStandardContains(query)
        || $0.city?.localizedStandardContains(query) == true
    }
  }

  private static func relevance(of airport: Airport, query: String, upper: String) -> Relevance {
    if airport.faaIdentifier == upper || airport.icaoIdentifier == upper { return .identifier }
    if airport.name.localizedStandardContains(query) { return .name }
    if airport.city?.localizedStandardContains(query) == true { return .city }
    return .none
  }
}
