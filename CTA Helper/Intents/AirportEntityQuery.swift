import AppIntents
import Foundation
import SwiftData

/**
 How Shortcuts, Siri and Spotlight find an ``AirportEntity``.

 The suggestions are the pilot's favorites: an airport they fly is the one they are picking, and
 offering all twenty thousand US landing facilities before they have typed anything is offering
 nothing.
 */
struct AirportEntityQuery: EntityStringQuery {
  private let container: ModelContainer?

  init() {
    self.init(container: NavDataStore.container)
  }

  /// - Parameter container: the store to read, or `nil` to answer with nothing.
  init(container: ModelContainer?) {
    self.container = container
  }

  func entities(for identifiers: [AirportEntity.ID]) async throws -> [AirportEntity] {
    await AppEntityLookup.lookUp(in: container) { try await $0.airports(for: identifiers) }
  }

  func entities(matching string: String) async throws -> [AirportEntity] {
    await AppEntityLookup.lookUp(in: container) { try await $0.airports(matching: string) }
  }

  func suggestedEntities() async throws -> [AirportEntity] {
    let suggested = UserDefaults.standard.suggestedAirportIDs
    return await AppEntityLookup.lookUp(in: container) { try await $0.airports(for: suggested) }
  }
}
