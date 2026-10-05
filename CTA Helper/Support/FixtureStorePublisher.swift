#if DEBUG
  import Compression
  import Foundation
  import NavDataSchema
  import SQLite3
  import SwiftData

  /**
   Publishes a nav data cycle as a store built ahead of time, into a local directory laid out the
   way the bucket is — `<cycle>.json` beside `<cycle>.store.lzma` — so a UI test downloads,
   verifies, expands and installs it exactly as the app does a published one.

   It does on the device what the macOS builder does on a Mac: write the dataset into a store,
   compact it into one file, compress that, and describe it in a manifest.
   */
  enum FixtureStorePublisher {
    /**
     Publishes `document` as the cycle `release` describes, under the name of the AIRAC cycle in
     force at `date`.

     - Parameters:
       - document: The dataset to publish.
       - release: The release the dataset came from, recorded as the store's cycle.
       - effective: When the published cycle takes effect.
       - expires: When it expires.
       - directory: Where to publish it; anything already there is replaced.
     - Returns: `directory`, for ``PrebuiltNavDataStore`` to fetch from.
     */
    static func publish(
      _ document: NavDataDocument,
      release: NavDataReleaseManifest,
      effective: Date,
      expires: Date,
      in directory: URL
    ) throws -> URL {
      try? FileManager.default.removeItem(at: directory)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

      let cycle = NavDataStoreManifest.cycleName(effective: effective),
        workingStore = directory.appending(component: "working.store"),
        compactStore = directory.appending(component: "\(cycle).store")
      let counts = try write(document, release: release, to: workingStore)
      try compact(workingStore, into: compactStore)
      StoreLayout.removeStore(at: workingStore)

      let compressed = try compress(Data(contentsOf: compactStore))
      try FileManager.default.removeItem(at: compactStore)
      let filename = "\(cycle).store.lzma"
      try compressed.write(to: directory.appending(component: filename))

      let manifest = NavDataStoreManifest(
        cycle: cycle,
        effective: effective,
        expires: expires,
        schemaFingerprint: NavDataSchema.fingerprint,
        schemaVersion: NavDataSchema.version,
        store: .init(
          filename: filename,
          bytes: UInt(compressed.count),
          sha256: NavDataIntegrity.sha256(of: compressed)
        ),
        counts: counts
      )
      let encoded = try NavDataStoreManifest.encoder().encode(manifest)
      try encoded.write(to: directory.appending(component: "\(cycle).json"))
      return directory
    }

    /// Writes the dataset and its cycle into a new store, returning what it holds.
    private static func write(
      _ document: NavDataDocument,
      release: NavDataReleaseManifest,
      to store: URL
    ) throws -> NavDataStoreManifest.Counts {
      let context = ModelContext(
        try NavDataContainer.makeContainer(storeAt: store, allowsSave: true)
      )
      let airports = document.airports.compactMap { $0.makeAirport() }
      airports.forEach(context.insert)
      context.insert(
        NavDataCycle(
          airacCycle: release.airacCycle,
          effectiveDate: release.cycleEffective,
          expirationDate: release.cycleExpires,
          sha256: release.data.sha256,
          importedAt: .now
        )
      )
      try context.save()

      let approaches = airports.flatMap(\.approaches)
      return .init(
        airports: UInt(airports.count),
        approaches: UInt(approaches.count),
        fixes: UInt(approaches.reduce(0) { $0 + $1.fixes.count })
      )
    }

    /**
     Copies a store into a single file holding all of it.

     A store open for writing keeps recent commits in its write-ahead log, beside the file rather
     than in it, so the file alone would be missing them.
     */
    private static func compact(_ source: URL, into destination: URL) throws {
      var database: OpaquePointer?
      defer { unsafe sqlite3_close(database) }
      guard unsafe sqlite3_open_v2(source.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
        unsafe sqlite3_exec(database, "VACUUM INTO '\(destination.path)'", nil, nil, nil)
          == SQLITE_OK
      else {
        throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: destination.path])
      }
    }

    /// Compresses a store the way the builder does, for ``PrebuiltNavDataStore`` to expand.
    private static func compress(_ store: Data) throws -> Data {
      var compressed = Data()
      let filter = try OutputFilter(.compress, using: .lzma) { chunk in
        if let chunk { compressed.append(chunk) }
      }
      try filter.write(store)
      try filter.finalize()
      return compressed
    }
  }
#endif
