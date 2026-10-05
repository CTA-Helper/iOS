import Foundation
import NavDataSchema
import SwiftData

/**
 Whether the nav data is missing or out of date, as read from any `ModelContext`.

 Nonisolated, so the loading screen and the background refresh read it the same way, off the main
 actor.
 */
struct NavDataState: Equatable {
  /// Whether the store holds no airports at all.
  let noData: Bool
  /// Whether the data should be replaced: its cycle is not in force, or the schema has moved on.
  let needsLoad: Bool
  /// Whether the pilot may fly the stored data for now rather than replace it.
  let canSkip: Bool
  /// When the installed cycle stops being in force, or `nil` when none is installed.
  let cycleExpires: Date?

  /**
   Reads the state of the store `context` reads.

   - Parameters:
     - context: A context on the store to judge.
     - defaults: Where the installed schema version is recorded.
   */
  static func fetch(context: ModelContext, defaults: UserDefaults = .standard) throws -> Self {
    var airportDescriptor = FetchDescriptor<Airport>()
    airportDescriptor.fetchLimit = 1
    let noData = try context.fetch(airportDescriptor).isEmpty

    var cycleDescriptor = FetchDescriptor<NavDataCycle>()
    cycleDescriptor.fetchLimit = 1
    let cycle = try context.fetch(cycleDescriptor).first

    // The cycle judges itself, on the same half-open window a published manifest states: in force
    // from the instant it takes effect until the instant it expires. Anything else — a cycle that
    // has lapsed, one dated ahead of today, or airports with no cycle over them at all, which is
    // what a half-written store looks like — is data outside its validity.
    let schemaOutOfDate = defaults.navDataSchemaVersion != NavDataSchema.version
    let dataOutOfDate = !(cycle?.isInForce ?? false)

    return Self(
      noData: noData,
      needsLoad: schemaOutOfDate || dataOutOfDate,
      canSkip: !noData && !schemaOutOfDate,
      cycleExpires: cycle?.expirationDate
    )
  }
}
