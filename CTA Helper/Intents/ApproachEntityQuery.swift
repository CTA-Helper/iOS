import AppIntents
import Foundation
import SwiftData

/// How Shortcuts, Siri and Spotlight find an ``ApproachEntity``.
struct ApproachEntityQuery: EntityStringQuery {
  private let container: ModelContainer?

  init() {
    self.init(container: NavDataStore.container)
  }

  /// - Parameter container: the store to read, or `nil` to answer with nothing.
  init(container: ModelContainer?) {
    self.container = container
  }

  func entities(for identifiers: [ApproachID]) async throws -> [ApproachEntity] {
    await AppEntityLookup.lookUp(in: container) { try await $0.approaches(for: identifiers) }
  }

  func entities(matching string: String) async throws -> [ApproachEntity] {
    await AppEntityLookup.lookUp(in: container) { try await $0.approaches(matching: string) }
  }

  func suggestedEntities() async throws -> [ApproachEntity] {
    let favorites = UserDefaults.standard.airportIDList(forKey: SettingsKey.favoriteAirports)
    return await AppEntityLookup.lookUp(in: container) {
      try await $0.suggestedApproaches(atAirports: favorites.ids)
    }
  }
}
