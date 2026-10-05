import Foundation
import NavDataSchema
import SwiftData

@testable import CTA_Helper

/**
 Nav data generations written to a directory of their own, with a `UserDefaults` suite of their
 own to record which one is active, both removed when the fixture goes away.

 The app's stores and settings are the test host's, and an install recorded in them would be
 followed by the running app.
 */
final class TemporaryNavDataStores {
  let layout: StoreLayout
  let defaults: UserDefaults
  private let suiteName: String

  var installer: NavDataStoreInstaller { .init(layout: layout, defaults: defaults) }

  init() {
    let name = "NavDataStoreTests-\(UUID().uuidString)"
    layout = StoreLayout(baseDirectory: URL.temporaryDirectory.appending(path: name))
    suiteName = name
    guard let defaults = UserDefaults(suiteName: name) else {
      preconditionFailure("Could not create the defaults suite \(name)")
    }
    self.defaults = defaults
  }

  /// An airport with nothing to it but the site number that identifies it.
  static func airport(siteNumber: String) -> Airport {
    Airport(
      siteNumber: siteNumber,
      faaIdentifier: siteNumber,
      icaoIdentifier: nil,
      name: "Test Airport",
      city: "Test",
      state: "MT",
      stateName: "Montana",
      elevationFt: 0,
      latitude: 0,
      longitude: 0,
      coldTemperature: nil
    )
  }

  /**
   Writes airports into a generation, as an update would.

   - Parameters:
     - siteNumbers: The airports the generation holds.
     - generation: The generation to write.
   */
  func write(_ siteNumbers: [String], toGeneration generation: Int) throws {
    let context = ModelContext(
      try NavDataStore.makeWritableContainer(layout: layout, generation: generation)
    )
    for siteNumber in siteNumbers { context.insert(Self.airport(siteNumber: siteNumber)) }
    try context.save()
  }

  /// The site numbers a generation holds, read the way the app reads it.
  func siteNumbers(inGeneration generation: Int) throws -> [String] {
    let context = ModelContext(
      try NavDataStore.makeContainer(layout: layout, generation: generation)
    )
    return try context.fetch(FetchDescriptor<Airport>()).map(\.siteNumber)
  }

  deinit {
    try? FileManager.default.removeItem(at: layout.baseDirectory)
    UserDefaults.standard.removePersistentDomain(forName: suiteName)
  }
}
