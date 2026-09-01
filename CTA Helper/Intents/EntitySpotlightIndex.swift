import AppIntents
import CoreSpotlight
import Foundation
import SwiftData
import os

/**
 The airports and approaches Spotlight holds: the ones the pilot has favorited or opened, and
 nothing else.

 Not the whole database. Twenty thousand landing facilities and the procedures under them would
 be a long indexing pass after every cycle, for content Apple's own guidance says not to donate —
 index what the person cares about or interacts with directly. What a pilot searches for from the
 home screen is an airport they fly, and both lists already name exactly those.
 */
enum EntitySpotlightIndex {
  /// The app's own index. The default one is for prototyping, per Apple.
  private static let name = "codes.tim.CTA-Helper.entities"
  private static let logger = Logger(subsystem: "codes.tim.CTA-Helper", category: "Spotlight")

  /**
   Replace what Spotlight holds with the airports these lists name, and their approaches.

   Both types are dropped first, which is what removes an airport the pilot has since unstarred;
   re-donating one already held updates it rather than duplicating it. Indexing is not recursive,
   so the approaches are donated as a set of their own.

   - Parameters:
     - favorites: the starred airports.
     - recents: the recently opened airports.
     - container: the store to read them out of.
   */
  static func donate(
    favorites: AirportIDList,
    recents: AirportIDList,
    container: ModelContainer
  ) async {
    let siteNumbers = Array(Set(favorites.ids).union(recents.ids))
    let lookup = AppEntityLookup(modelContainer: container)
    do {
      let airports = try await lookup.airports(for: siteNumbers)
      let approaches = try await lookup.approaches(atAirports: siteNumbers)
      let index = CSSearchableIndex(name: name)
      try await index.deleteAppEntities(ofType: AirportEntity.self)
      try await index.deleteAppEntities(ofType: ApproachEntity.self)
      try await index.indexAppEntities(airports)
      try await index.indexAppEntities(approaches)
    } catch {
      logger.error("Could not index the pilot's airports: \(error)")
    }
  }
}
