import Foundation
import Observation
import SwiftData
import os

private let maximumSearchResults = 20
private let searchLogger = Logger(subsystem: "codes.tim.CTA-Helper", category: "Search")

/**
 How closely an airport matches a query, ordered worst to best: results are sorted on this, so
 an identifier match outranks a name match, which outranks a city match.
 */
private enum Relevance: Int, Comparable {
  case none
  case city
  case name
  case identifier

  static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Debounced, relevance-ranked airport search over identifier, name and city.
@Observable
@MainActor
final class SearchViewModel {
  private static let debounce = Duration.milliseconds(250)
  private static let minimumQueryLength = 2

  var query: String = "" {
    didSet { scheduleSearch() }
  }

  private(set) var results: [Airport] = []

  private let container: ModelContainer
  private var searchTask: Task<Void, Never>?

  init(container: ModelContainer) {
    self.container = container
  }

  nonisolated private static func relevance(of airport: Airport, query: String, upper: String)
    -> Relevance
  {
    if airport.faaIdentifier == upper || airport.icaoIdentifier == upper { return .identifier }
    if airport.name.localizedStandardContains(query) { return .name }
    if airport.city?.localizedStandardContains(query) == true { return .city }
    return .none
  }

  private func scheduleSearch() {
    searchTask?.cancel()
    let query = query.trimmingCharacters(in: .whitespaces)
    guard query.count >= Self.minimumQueryLength else {
      results = []
      return
    }
    searchTask = Task { [weak self] in
      try? await Task.sleep(for: Self.debounce)
      guard !Task.isCancelled, let self else { return }
      await search(query)
    }
  }

  private func search(_ query: String) async {
    do {
      let ids = try await rankedIDs(matching: query)
      guard !Task.isCancelled else { return }
      let context = container.mainContext
      results = ids.compactMap { context.model(for: $0) as? Airport }
    } catch {
      guard !Task.isCancelled else { return }
      searchLogger.error("Airport search failed: \(error)")
      results = []
    }
  }

  @concurrent
  private func rankedIDs(matching query: String) async throws -> [PersistentIdentifier] {
    let context = ModelContext(container)
    let upper = query.uppercased()
    // Optionals are compared and chained, never coalesced: SwiftData compiles this to SQL, and
    // `(city ?? "").localizedStandardContains(_:)` is a translation it rejects at fetch time,
    // taking the process down with it.
    let predicate = #Predicate<Airport> {
      $0.faaIdentifier == upper
        || $0.icaoIdentifier == upper
        || $0.name.localizedStandardContains(query)
        || $0.city?.localizedStandardContains(query) == true
    }
    return
      try context.fetch(FetchDescriptor(predicate: predicate))
      .map { ($0.persistentModelID, Self.relevance(of: $0, query: query, upper: upper)) }
      .sorted { $0.1 > $1.1 }
      .prefix(maximumSearchResults)
      .map(\.0)
  }
}
