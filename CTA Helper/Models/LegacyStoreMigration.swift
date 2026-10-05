import Foundation
import NavDataSchema
import os

/**
 Retires the single store SwiftData opened by default before nav data was kept in generations.

 That store held nothing but downloaded nav data — favorites and recents have always lived in
 `UserDefaults` — so there is nothing in it to carry forward. It is kept only until a generation
 has been installed in its place, and then deleted: a pilot upgrading keeps flying nothing worse
 than an empty store until they download, and never pays for the old file afterwards.
 */
struct LegacyStoreMigration {
  private static let logger = Logger(
    subsystem: "codes.tim.CTA-Helper",
    category: "LegacyStoreMigration"
  )

  let layout: StoreLayout

  /**
   Deletes the legacy store once a generation has replaced it.

   - Parameter activeGeneration: The generation the app is about to read. Until an install has
     switched away from ``NavDataStore/emptyGeneration``, the legacy store is left alone.
   */
  func migrateIfNeeded(activeGeneration: Int) {
    guard activeGeneration != NavDataStore.emptyGeneration,
      FileManager.default.fileExists(atPath: layout.legacyStoreURL.path)
    else { return }

    StoreLayout.removeStore(at: layout.legacyStoreURL)
    Self.logger.notice("Removed the store that predated nav data generations")
  }
}
