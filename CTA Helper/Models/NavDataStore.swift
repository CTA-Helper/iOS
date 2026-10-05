import Foundation
import NavDataSchema
import SwiftData
import os

/**
 The nav data store, opened once per process and reopened when a new generation is installed.

 The app reads it and so do its App Intents, out of the one container rather than one opened per
 lookup: an intent can be what launches the app, and Shortcuts and Spotlight query as the pilot
 types, which is no rate at which to be opening a store.

 The app opens the store read-only. It is a downloaded artifact replaced whole every cycle, by
 writing the next *generation* beside it and switching to that one, so a store the app cannot
 write is a store the app cannot leave half-written. An update writes through a container of its
 own, over a generation nothing is reading yet.
 */
enum NavDataStore {
  /**
   The generation a fresh install reads: an empty store bootstrapped in place, which no update
   ever writes.

   An update reserves a number above every generation on disk, so any other active generation is
   one an install switched to.
   */
  static let emptyGeneration = 0

  private static let logger = Logger(subsystem: "codes.tim.CTA-Helper", category: "Store")

  private static let opened = OSAllocatedUnfairLock<Result<ModelContainer, any Error>?>(
    initialState: nil
  )
  private static let hasSweptStaleGenerations = OSAllocatedUnfairLock(initialState: false)

  /// Where the stores live: Application Support, or a directory of its own under a UI test.
  static var layout: StoreLayout { UITestConfiguration.storeLayout ?? .applicationSupport }

  /// The generation the app reads.
  static var activeGeneration: Int { UserDefaults.standard.activeNavDataGeneration }

  /**
   The store, or the error that stopped it opening even once discarded.

   Rebuilt by ``reopen()`` when an update installs a new generation, so a running app picks up a
   new dataset without being relaunched.
   */
  static var shared: Result<ModelContainer, any Error> {
    opened.withLock { opened in
      if let opened { return opened }
      let result = openActiveGeneration()
      opened = result
      return result
    }
  }

  /// The store to read, or `nil` when there is none — which an App Intent answers with nothing.
  static var container: ModelContainer? { try? shared.get() }

  /**
   Opens the store holding a generation, read-only, creating an empty one where none exists.

   - Parameters:
     - layout: Where the stores live.
     - generation: Which generation to read.
   - Returns: A read-only container over that generation.
   */
  static func makeContainer(layout: StoreLayout, generation: Int) throws -> ModelContainer {
    LegacyStoreMigration(layout: layout).migrateIfNeeded(activeGeneration: generation)
    try bootstrapIfAbsent(layout: layout, generation: generation)
    return try NavDataContainer.makeContainer(
      layout: layout,
      generation: generation,
      allowsSave: false
    )
  }

  /**
   Opens a generation that must already be on disk, read-only.

   Where ``makeContainer(layout:generation:)`` bootstraps an empty store for a generation with no
   file, this refuses one. A caller reading a generation to learn what the dataset holds needs a
   generation that has gone missing to read as an error, not as a dataset carrying nothing.

   - Parameters:
     - layout: Where the stores live.
     - generation: Which generation to read.
   - Returns: A read-only container over that generation.
   - Throws: ``Errors/navDataStoreIsMissing(generation:)`` if that generation has no store on
     disk, or the error SwiftData raised trying to open it.
   */
  static func makeContainerForExistingGeneration(
    layout: StoreLayout,
    generation: Int
  ) throws -> ModelContainer {
    guard layout.navStoreExists(generation: generation) else {
      throw Errors.navDataStoreIsMissing(generation: generation)
    }
    return try NavDataContainer.makeContainer(
      layout: layout,
      generation: generation,
      allowsSave: false
    )
  }

  /**
   Opens a generation writable, for an update to write the dataset into.

   The update writes through its own container so its bulk transactions queue on their own
   coordinator, and it writes a generation nothing is reading yet — so an update that fails costs
   nothing.

   - Parameters:
     - layout: Where the stores live.
     - generation: The generation to write.
   - Returns: A container whose store accepts writes.
   */
  static func makeWritableContainer(
    layout: StoreLayout,
    generation: Int
  ) throws -> ModelContainer {
    try NavDataContainer.makeContainer(layout: layout, generation: generation, allowsSave: true)
  }

  /**
   Rebuilds ``shared`` against whichever generation is now active.

   The container holds an open SQLite handle, so a generation is only ever switched to by opening
   the new file — never by replacing the old one underneath a reader. The new one is opened before
   the swap, so a reader of ``shared`` keeps the old one rather than waiting on the open.
   */
  static func reopen() {
    let reopened = openActiveGeneration()
    opened.withLock { $0 = reopened }
  }

  /**
   Opens the active generation, discarding it and opening an empty one in its place if it cannot
   be opened under the current schema.

   Nav data is a downloaded file, so a store the app can no longer read is worth less than the
   launch it would cost: an empty one reads as "no data", and the app offers the download again.
   A store that cannot be opened even then is returned as the error — the device is out of room
   or the container is unwritable, and telling the pilot so beats a launch crash.
   */
  private static func openActiveGeneration() -> Result<ModelContainer, any Error> {
    let layout = layout,
      generation = activeGeneration
    // Swept however this process first got a container, including by discarding a bad one: a
    // sweep that had not happened yet would happen on the next reopen instead, under a container
    // that may still be reading what it reclaims.
    defer { sweepStaleGenerationsOnce(layout: layout, keeping: generation) }

    do {
      return .success(try makeContainer(layout: layout, generation: generation))
    } catch {
      logger.warning("Discarding the unreadable nav data store: \(error)")
    }

    StoreLayout.removeStore(at: layout.navStoreURL(generation: generation))
    return Result { try makeContainer(layout: layout, generation: generation) }
  }

  /**
   Reclaims superseded generations, but only before this process has opened one.

   A generation is reclaimed at launch and never afterwards. Reopening onto a newer generation
   leaves the previous file alone, because the views may still hold the container reading it —
   deleting it would leave them on a file that no longer exists, which is exactly what numbering
   generations avoids.
   */
  private static func sweepStaleGenerationsOnce(layout: StoreLayout, keeping generation: Int) {
    let shouldSweep = hasSweptStaleGenerations.withLock { hasSwept in
      defer { hasSwept = true }
      return !hasSwept
    }
    guard shouldSweep else { return }
    layout.removeNavStores(exceptGeneration: generation)
  }

  /**
   Creates an empty store where none exists.

   A read-only configuration cannot create the file it is pointed at, and an empty store written
   by this binary matches this binary's schema by construction — which is also why no store needs
   to ship inside the app.
   */
  private static func bootstrapIfAbsent(layout: StoreLayout, generation: Int) throws {
    guard !layout.navStoreExists(generation: generation) else { return }
    _ = try makeWritableContainer(layout: layout, generation: generation)
  }

  /// Reasons a store couldn’t be opened.
  enum Errors: LocalizedError {
    /// The generation asked for has no store on disk.
    case navDataStoreIsMissing(generation: Int)

    var errorDescription: String? {
      String(localized: "Couldn’t open the navigation data.")
    }

    var failureReason: String? {
      switch self {
        case .navDataStoreIsMissing(let generation):
          String(localized: "Generation \(generation, format: .number) has no database on disk.")
      }
    }

    var recoverySuggestion: String? {
      String(localized: "Try downloading the navigation data again.")
    }
  }
}

extension UserDefaults {
  /// Which generation of the nav data store the app reads.
  var activeNavDataGeneration: Int {
    get { integer(forKey: SettingsKey.activeNavDataGeneration) }
    set { set(newValue, forKey: SettingsKey.activeNavDataGeneration) }
  }

  /// The ``NavDataSchema/version`` the active generation was installed under.
  var navDataSchemaVersion: Int {
    get { object(forKey: SettingsKey.navDataSchemaVersion) as? Int ?? NavDataSchema.version }
    set { set(newValue, forKey: SettingsKey.navDataSchemaVersion) }
  }
}
