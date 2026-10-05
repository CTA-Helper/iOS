import Foundation
import NavDataSchema
import Testing

@testable import CTA_Helper

/**
 The publish job runs some hours into the day a cycle takes effect, so for part of that day the
 current cycle's manifest is missing and the walk-back reaches for the cycle before it — whose
 store expired at midnight. Installing that one reports success, which stops the fall back to the
 import, and leaves the app asking for an update it has just been told it completed.
 */
struct `Prebuilt cycle selection` {
  private static let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
  private static let day: TimeInterval = 24 * 60 * 60

  private static func manifest(
    effective: Date,
    expires: Date,
    schemaVersion: Int = NavDataSchema.version
  ) -> NavDataStoreManifest {
    .init(
      cycle: NavDataStoreManifest.cycleName(effective: effective),
      effective: effective,
      expires: expires,
      schemaFingerprint: NavDataSchema.fingerprint,
      schemaVersion: schemaVersion,
      store: .init(
        filename: "store.lzma",
        bytes: 1024,
        sha256: String(repeating: "0", count: 64)
      ),
      counts: .init(airports: 1, approaches: 1, fixes: 1)
    )
  }

  private static func utc(_ string: String) throws -> Date {
    try Date(string, strategy: .iso8601)
  }

  @Test
  func `passes over a cycle that expired before the store would be installed`() throws {
    let expired = Self.manifest(
      effective: Self.now.addingTimeInterval(-28 * Self.day),
      expires: Self.now.addingTimeInterval(-3600)
    )

    #expect(try !PrebuiltNavDataStore.isInstallable(expired, at: Self.now))
  }

  @Test
  func `passes over a cycle published ahead of the day it takes effect`() throws {
    let future = Self.manifest(
      effective: Self.now.addingTimeInterval(Self.day),
      expires: Self.now.addingTimeInterval(29 * Self.day)
    )

    #expect(try !PrebuiltNavDataStore.isInstallable(future, at: Self.now))
  }

  @Test
  func `installs an older cycle that is still in force`() throws {
    let current = Self.manifest(
      effective: Self.now.addingTimeInterval(-14 * Self.day),
      expires: Self.now.addingTimeInterval(14 * Self.day)
    )

    #expect(try PrebuiltNavDataStore.isInstallable(current, at: Self.now))
  }

  /// No older cycle would be built for this binary's schema either, so the walk-back stops.
  @Test
  func `stops looking at a store built for another schema`() {
    let mismatched = Self.manifest(
      effective: Self.now.addingTimeInterval(-14 * Self.day),
      expires: Self.now.addingTimeInterval(14 * Self.day),
      schemaVersion: NavDataSchema.version + 1
    )

    #expect(throws: PrebuiltNavDataStore.Errors.schemaMismatch) {
      try PrebuiltNavDataStore.isInstallable(mismatched, at: Self.now)
    }
  }

  @Test
  func `asks for the cycle in force and then the one before it`() throws {
    let dates = AIRACCalendar.effectiveDates(at: try Self.utc("2026-10-05T12:00:00Z"), count: 2)

    #expect(
      dates.map { NavDataStoreManifest.cycleName(effective: $0) } == ["2026-10-01", "2026-09-03"]
    )
  }

  @Test
  func `counts a cycle as in force from the instant it takes effect`() throws {
    let dates = AIRACCalendar.effectiveDates(at: try Self.utc("2026-10-01T00:00:00Z"), count: 1)

    #expect(dates == [try Self.utc("2026-10-01T00:00:00Z")])
  }
}
