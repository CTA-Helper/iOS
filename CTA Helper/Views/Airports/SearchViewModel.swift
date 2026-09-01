import Foundation
import Observation
import SwiftData
import os

private let maximumSearchResults = 20
private let searchLogger = Logger(subsystem: "codes.tim.CTA-Helper", category: "Search")

/// Debounced, relevance-ranked airport search over identifier, name and city.
@Observable
@MainActor
final class SearchViewModel {
  private static let debounce = Duration.milliseconds(250)

  var query: String = "" {
    didSet { scheduleSearch() }
  }

  private(set) var results: [Airport] = []

  private let container: ModelContainer
  private var searchTask: Task<Void, Never>?

  init(container: ModelContainer) {
    self.container = container
  }

  private func scheduleSearch() {
    searchTask?.cancel()
    let query = query.trimmingCharacters(in: .whitespaces)
    guard query.count >= AirportSearch.minimumQueryLength else {
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
    return
      try AirportSearch.airports(matching: query, in: context, limit: maximumSearchResults)
      .map(\.persistentModelID)
  }
}
