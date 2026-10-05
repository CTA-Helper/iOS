import Foundation
import NavDataSchema
import SwiftData
import Testing

@testable import CTA_Helper

/**
 A cycle replaces the nav data by writing a new generation beside the one in use and switching to
 it by number. These cover the files that scheme depends on: what the app opens, what an
 abandoned update leaves behind, and what is reclaimed.
 */
@Suite(.serialized)
struct `Nav data generations` {
  private let stores = TemporaryNavDataStores()

  private var layout: StoreLayout { stores.layout }

  @Test
  func `creates an empty store where the generation has none`() throws {
    #expect(try stores.siteNumbers(inGeneration: NavDataStore.emptyGeneration).isEmpty)
    #expect(layout.navStoreExists(generation: NavDataStore.emptyGeneration))
  }

  @Test
  func `opens the store read-only`() throws {
    let context = ModelContext(try NavDataStore.makeContainer(layout: layout, generation: 0))
    context.insert(TemporaryNavDataStores.airport(siteNumber: "WRITTEN"))

    #expect(throws: (any Error).self) { try context.save() }
  }

  @Test
  func `reads the generation it is switched to`() throws {
    try stores.write(["LIVE"], toGeneration: 1)
    try stores.write(["REPLACED"], toGeneration: 2)

    #expect(try stores.siteNumbers(inGeneration: 2) == ["REPLACED"])
  }

  /// The dataset in use must survive an update that never finishes — the failure that kept the
  /// import from running anywhere the system can kill it.
  @Test
  func `leaves the dataset in use untouched when an update is abandoned`() throws {
    try stores.write(["LIVE"], toGeneration: 1)
    try stores.write(["HALF-WRITTEN"], toGeneration: 2)

    #expect(try stores.siteNumbers(inGeneration: 1) == ["LIVE"])
  }

  @Test
  func `refuses a generation that is not on disk when it must already exist`() {
    #expect(throws: NavDataStore.Errors.self) {
      try NavDataStore.makeContainerForExistingGeneration(layout: layout, generation: 7)
    }
    #expect(!layout.navStoreExists(generation: 7))
  }

  @Test
  func `reclaims superseded generations and keeps the one in use`() throws {
    for generation in 1...3 { try stores.write(["AIRPORT"], toGeneration: generation) }

    layout.removeNavStores(exceptGeneration: 3)

    #expect(layout.navStoreGenerations() == [3])
  }
}

/**
 The store SwiftData opened by default before generations held nothing but nav data, and a pilot
 upgrading keeps it only until a generation replaces it.
 */
@Suite(.serialized)
struct `Legacy store migration` {
  private let stores = TemporaryNavDataStores()

  private var legacyStoreExists: Bool {
    FileManager.default.fileExists(atPath: stores.layout.legacyStoreURL.path)
  }

  init() throws {
    try FileManager.default.createDirectory(
      at: stores.layout.baseDirectory,
      withIntermediateDirectories: true
    )
    for suffix in ["", "-wal", "-shm"] {
      FileManager.default.createFile(
        atPath: stores.layout.legacyStoreURL.path + suffix,
        contents: Data("legacy".utf8)
      )
    }
  }

  @Test
  func `keeps the legacy store while no generation has been installed`() throws {
    _ = try NavDataStore.makeContainer(
      layout: stores.layout,
      generation: NavDataStore.emptyGeneration
    )

    #expect(legacyStoreExists)
  }

  @Test
  func `deletes the legacy store and its journals once a generation is installed`() throws {
    try stores.write(["INSTALLED"], toGeneration: 1)

    _ = try NavDataStore.makeContainer(layout: stores.layout, generation: 1)

    for suffix in ["", "-wal", "-shm"] {
      #expect(!FileManager.default.fileExists(atPath: stores.layout.legacyStoreURL.path + suffix))
    }
  }
}
