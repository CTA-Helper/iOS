import Foundation
import NavDataSchema
import Testing

@testable import CTA_Helper

/**
 Switching to a newly written dataset is a single recorded number, taken only after the new store
 has been opened and found to hold airports. These are the tests that earn the word "atomic":
 whatever happens to an update, the dataset in use is either replaced wholly or not at all.
 */
@Suite(.serialized)
struct `Nav data store install` {
  private let stores = TemporaryNavDataStores()

  @Test
  func `switches to a generation holding a dataset`() throws {
    let installer = stores.installer
    let generation = installer.reserveGeneration()
    try stores.write(["IMPORTED"], toGeneration: generation)

    try installer.install(generation: generation)

    #expect(installer.activeGeneration == generation)
    #expect(stores.defaults.navDataSchemaVersion == NavDataSchema.version)
  }

  /// An update that produced nothing must not become the dataset the pilot flies on.
  @Test
  func `refuses a generation holding no airports and keeps the one in use`() throws {
    let installer = stores.installer
    let live = installer.reserveGeneration()
    try stores.write(["LIVE"], toGeneration: live)
    try installer.install(generation: live)

    let generation = installer.reserveGeneration()
    try stores.write([], toGeneration: generation)

    #expect(throws: NavDataStoreInstaller.Errors.storeIsEmpty) {
      try installer.install(generation: generation)
    }
    #expect(installer.activeGeneration == live)
  }

  @Test
  func `reserves a generation nothing is using`() throws {
    let installer = stores.installer
    let first = installer.reserveGeneration()
    try stores.write(["FIRST"], toGeneration: first)
    try installer.install(generation: first)
    try stores.write(["ABANDONED"], toGeneration: first + 1)

    let second = installer.reserveGeneration()

    #expect(second > first + 1)
    #expect(!stores.layout.navStoreExists(generation: second))
  }
}
