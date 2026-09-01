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

 Donations are coalesced rather than run as they arrive. Each one replaces the whole index, and
 two overlapping would race: `CSSearchableIndex` does not cancel, so a superseded donation runs
 to completion, and landing last it would restore the very airport the pilot had just unstarred.
 */
actor EntitySpotlightIndex {
  /// The one donor, so that a donation arriving mid-pass supersedes rather than races.
  static let shared = EntitySpotlightIndex()

  /// The app's own index. The default one is for prototyping, per Apple.
  private static let name = "codes.tim.CTA-Helper.entities"
  private static let logger = Logger(subsystem: "codes.tim.CTA-Helper", category: "Spotlight")

  private var pending: Donation?
  private var isDonating = false

  /**
   Replace what Spotlight holds with these airports and their approaches.

   Both types are dropped first, which is what removes an airport the pilot has since unstarred;
   re-donating one already held updates it rather than duplicating it. Indexing is not recursive,
   so the approaches are donated as a set of their own.

   Where a pass is already running this records the airports as the pass to run next and returns:
   the running one picks them up when it finishes, and only the newest list is ever written.

   - Parameters:
     - siteNumbers: the airports to hold — the pilot's favorites and the ones they have opened.
     - container: the store to read them out of.
   */
  func donate(airports siteNumbers: [String], from container: ModelContainer) async {
    pending = Donation(siteNumbers: siteNumbers, container: container)
    guard !isDonating else { return }

    isDonating = true
    defer { isDonating = false }
    while let donation = pending {
      pending = nil
      await write(donation)
    }
  }

  private func write(_ donation: Donation) async {
    let lookup = AppEntityLookup(modelContainer: donation.container)
    do {
      let airports = try await lookup.airports(for: donation.siteNumbers)
      let approaches = try await lookup.approaches(atAirports: donation.siteNumbers)
      let index = CSSearchableIndex(name: Self.name)
      try await index.deleteAppEntities(ofType: AirportEntity.self)
      try await index.deleteAppEntities(ofType: ApproachEntity.self)
      try await index.indexAppEntities(airports)
      try await index.indexAppEntities(approaches)
    } catch {
      Self.logger.error("Could not index the pilot's airports: \(error)")
    }
  }

  /// The airports one pass writes, and the store to read them out of.
  private struct Donation {
    let siteNumbers: [String]
    let container: ModelContainer
  }
}
