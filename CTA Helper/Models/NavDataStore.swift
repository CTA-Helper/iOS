import Foundation
import SwiftData
import os

/**
 The nav data store, opened once per process.

 The app reads it and so do its App Intents, out of the one container rather than one opened per
 lookup: an intent can be what launches the app, and Shortcuts and Spotlight query as the pilot
 types, which is no rate at which to be opening a store.

 The importer is the deliberate exception. It writes through a container of its own over this
 same store, so that its bulk transactions queue on their own coordinator rather than in front of
 the reads.
 */
enum NavDataStore {
  private static let logger = Logger(subsystem: "codes.tim.CTA-Helper", category: "Store")

  /// The store, or the error that stopped it opening even once rebuilt.
  static let shared = Result { try open(inMemory: UITestConfiguration.isRunning) }

  /// The store to read, or `nil` when there is none — which an App Intent answers with nothing.
  static var container: ModelContainer? { try? shared.get() }

  /**
   Open the store holding the imported nav data, discarding and rebuilding it if it cannot be
   opened under the current schema.

   Every airport in it is derived from the published cycle and re-downloaded on next launch, so a
   store the app can no longer read is worth less than the launch it would cost.

   A rebuild that fails too is thrown rather than fatal: the device is out of room or the
   container is unwritable, and telling the pilot so beats a launch crash they can only read about
   in a crash report they will never see.
   */
  private static func open(inMemory: Bool) throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
    do {
      return try ModelContainer(for: Airport.self, NavDataCycle.self, configurations: configuration)
    } catch {
      logger.warning("Discarding the unreadable nav data store: \(error)")
    }

    discardStore(at: configuration.url)
    return try ModelContainer(
      for: Airport.self,
      NavDataCycle.self,
      configurations: configuration
    )
  }

  private static func discardStore(at url: URL) {
    // SwiftData writes the SQLite journal and write-ahead log alongside the store itself, and
    // leaving either behind makes the freshly created store unreadable in turn.
    for suffix in ["", "-shm", "-wal"] {
      try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
    }
  }
}
