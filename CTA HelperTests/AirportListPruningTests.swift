import Foundation
import NavDataSchema
import Testing

@testable import CTA_Helper

/**
 The pilot's lists remember airports by site number, and the FAA retires airports between cycles.
 Installing a dataset that no longer carries one has to forget it, while a dataset that still
 carries it must leave it alone — a prune that fired on every install would cost the pilot their
 favorites.
 */
@MainActor
@Suite(.serialized)
struct `Airport list pruning on install` {
  private static let carried = "CARRIED", retired = "RETIRED"

  nonisolated private static let listKeys = [
    SettingsKey.favoriteAirports,
    SettingsKey.recentAirports,
    SettingsKey.chartAirports
  ]

  private let stores = TemporaryNavDataStores()

  private var defaults: UserDefaults { stores.defaults }

  init() throws {
    try stores.write([Self.carried], toGeneration: 1)
    for key in Self.listKeys {
      defaults.set(AirportIDList([Self.retired, Self.carried]), forKey: key)
    }
  }

  @Test(arguments: listKeys)
  func `forgets an airport the incoming dataset dropped`(key: String) throws {
    let incoming = NavDataUpdater.incomingGeneration(
      1,
      layout: stores.layout,
      listing: [Self.retired, Self.carried]
    )

    NavDataUpdater.pruneAirportLists(
      dropping: try #require(incoming.droppedSiteNumbers),
      defaults: defaults
    )

    #expect(defaults.airportIDList(forKey: key).ids == [Self.carried])
  }

  @Test
  func `drops nothing when the incoming generation is gone from disk`() {
    StoreLayout.removeStore(at: stores.layout.navStoreURL(generation: 1))

    let incoming = NavDataUpdater.incomingGeneration(
      1,
      layout: stores.layout,
      listing: [Self.retired, Self.carried]
    )

    #expect(incoming.droppedSiteNumbers == nil)
  }
}
