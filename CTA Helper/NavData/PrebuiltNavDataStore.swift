import Compression
import CryptoKit
import Foundation
import NavDataSchema
import os

/**
 Fetches a nav data store that was built ahead of time, instead of assembling one on the device.

 The store is built on a Mac once per cycle and published, so the work left to the device is a
 transfer and a decompression.

 Every step here is allowed to fail. A cycle that was never published, a store built against a
 different schema, a truncated download: each falls back to importing the published JSON, which
 is still released and still works. That is what makes this an optimization rather than a
 dependency.
 */
actor PrebuiltNavDataStore {
  /**
   Where published stores are served from: the R2 bucket's public URL, under the `navdata` key
   prefix the builder uploads to.
   */
  static let publishedBaseURL = URL(string: "https://r2-public-url.invalid/navdata/")!

  /**
   How many cycles back to look before giving up and importing instead.

   Which cycle is current is a judgement this build makes from the AIRAC calendar and its own
   clock, and the manifests are what actually say. One step of slack covers the two disagreeing;
   beyond that a candidate would have to be so old that its own window has closed, and every such
   candidate is refused anyway.
   */
  private static let cyclesToWalkBack = 2

  /**
   How long a manifest probe is given before it is treated as unpublished.

   A manifest is a few hundred bytes, and the cycles are probed one after the other, so the
   default minute apiece is minutes the import could have spent doing the work.
   */
  private static let manifestTimeoutSeconds: TimeInterval = 10

  /// How much of the compressed store to feed the decompressor at a time.
  private static let expandChunkSizeBytes = 1 << 20

  private static let logger = Logger(
    subsystem: "codes.tim.CTA-Helper",
    category: "PrebuiltNavDataStore"
  )

  /// Where this build looks for published stores: the bucket, or wherever a debug launch says.
  static var baseURL: URL { UITestConfiguration.navDataBaseURL ?? publishedBaseURL }

  /// Where the manifests and stores are published.
  private let baseURL: URL

  /// The networks every request here may use.
  private let networkAccess: NavDataNetworkAccess

  /// The configuration the manifest probes run on.
  private var manifestProbeConfiguration: URLSessionConfiguration {
    let configuration = networkAccess.sessionConfiguration
    configuration.timeoutIntervalForRequest = Self.manifestTimeoutSeconds
    configuration.timeoutIntervalForResource = Self.manifestTimeoutSeconds
    return configuration
  }

  /**
   - Parameters:
     - baseURL: Where the manifests and stores are published.
     - networkAccess: The networks every request may use.
   */
  init(baseURL: URL = PrebuiltNavDataStore.baseURL, networkAccess: NavDataNetworkAccess) {
    self.baseURL = baseURL
    self.networkAccess = networkAccess
  }

  /**
   Whether a published cycle is worth downloading, given what this build reads and when it is.

   A publish runs some hours into the day a cycle takes effect, so for part of that day the
   current cycle's manifest is absent while its JSON is already released. Walking back to the
   previous cycle then would install a store that expired at midnight — data the app asks to
   replace on the very next launch, reached by a path that reports success and so never falls
   through to the import that would have replaced it.

   - Parameters:
     - manifest: The cycle's manifest.
     - date: The moment the store would be installed.
   - Returns: Whether the cycle should be installed.
   - Throws: ``Errors/schemaMismatch`` if the store was built for a different shape of store,
     which no older cycle would fix either.
   */
  nonisolated static func isInstallable(
    _ manifest: NavDataStoreManifest,
    at date: Date = .now
  ) throws -> Bool {
    guard manifest.isEffective(at: date) else {
      logger.notice(
        """
        Cycle \(manifest.cycle, privacy: .public) is outside the window it is effective for; \
        looking further back
        """
      )
      return false
    }
    guard manifest.matchesSchema else {
      let published = "\(manifest.schemaFingerprint) v\(manifest.schemaVersion)",
        expected = "\(NavDataSchema.fingerprint) v\(NavDataSchema.version)"
      logger.notice(
        """
        Cycle \(manifest.cycle, privacy: .public) publishes store shape \
        \(published, privacy: .public); this build reads \(expected, privacy: .public) — importing \
        instead
        """
      )
      throw Errors.schemaMismatch
    }
    return true
  }

  nonisolated private static func fetch(
    from url: URL,
    networkAccess: NavDataNetworkAccess,
    reportingTo continuation: AsyncStream<Float>.Continuation
  ) async throws -> URL {
    defer { continuation.finish() }
    let (fileURL, response) = try await downloadWithRetry(
      from: url,
      configuration: networkAccess.sessionConfiguration,
      logger: logger,
      label: "prebuilt nav data",
      reportingTo: continuation
    )
    if let http = response as? HTTPURLResponse, !http.isSuccessful {
      try? FileManager.default.removeItem(at: fileURL)
      throw Errors.noPublishedCycle
    }
    return fileURL
  }

  /// Hashes the downloaded payload, off this actor.
  @concurrent
  nonisolated private static func digest(of payload: URL) async throws -> String {
    let data = try Data(contentsOf: payload, options: .mappedIfSafe)
    return NavDataIntegrity.sha256(of: data)
  }

  /**
   Expands the compressed store straight onto disk, off this actor.

   The payload is fed through the decompressor a chunk at a time and each chunk of store is
   written as it emerges, so neither the compressed payload nor the expanded store is ever
   resident whole. This runs while the app may be in the background under a
   `BGContinuedProcessingTask`, where a small footprint is the difference between finishing and
   being jetsammed.

   - Parameters:
     - payload: The compressed store.
     - payloadBytes: The payload's size, as its manifest published it.
     - destination: Where to write the expanded store.
     - continuation: Yielded the fraction of the payload consumed so far.
   */
  @concurrent
  nonisolated private static func expand(
    _ payload: URL,
    ofSize payloadBytes: UInt,
    to destination: URL,
    reportingTo continuation: AsyncStream<Float>.Continuation
  ) async throws {
    defer { continuation.finish() }

    let source = try FileHandle(forReadingFrom: payload)
    defer { try? source.close() }

    try FileManager.default.createDirectory(
      at: destination.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    FileManager.default.createFile(atPath: destination.path, contents: nil)
    let sink = try FileHandle(forWritingTo: destination)
    defer { try? sink.close() }

    let filter = try OutputFilter(.decompress, using: .lzma) { store in
      guard let store else { return }
      try sink.write(contentsOf: store)
    }

    // The digest matched, so the payload holds exactly as many bytes as its manifest published.
    let totalBytes = Float(max(payloadBytes, 1))
    var consumedBytes = 0
    while let chunk = try source.read(upToCount: expandChunkSizeBytes), !chunk.isEmpty {
      try Task.checkCancellation()
      try filter.write(chunk)
      consumedBytes += chunk.count
      continuation.yield(min(Float(consumedBytes) / totalBytes, 1))
    }
    try filter.finalize()
  }

  /**
   The newest published cycle whose store this build can install.

   Cycles are asked for by name and walked backwards, because a manifest states the window it is
   effective for and a mutable "latest" pointer could not. Each candidate is judged on the window
   it publishes rather than on this build's own reckoning of which cycle is current, so a cycle
   still in force is installed even when it is not the one the AIRAC calendar names today.

   Checked before anything is downloaded, let alone opened: SwiftData answers a near-miss schema
   by migrating rather than by refusing, so a store opened first would be silently, slowly
   migrated where a clean fall back to the import was wanted.

   - Throws: ``Errors`` if nothing installable is published.
   */
  func newestInstallableCycle() async throws -> PublishedCycle {
    let now = Date.now
    for effective in AIRACCalendar.effectiveDates(at: now, count: Self.cyclesToWalkBack) {
      let name = NavDataStoreManifest.cycleName(effective: effective)
      guard let published = await manifest(for: name) else { continue }
      guard try Self.isInstallable(published.manifest, at: now) else { continue }
      return published
    }
    throw Errors.noPublishedCycle
  }

  /**
   Downloads a published cycle's store and expands it to `destination`.

   - Parameters:
     - cycle: The cycle to download, from ``newestInstallableCycle()``.
     - destination: Where to write the expanded store.
     - continuation: Yielded progress as the transfer and expansion proceed.
   */
  func download(
    _ cycle: PublishedCycle,
    to destination: URL,
    reportingTo continuation: AsyncStream<NavDataLoader.State>.Continuation
  ) async throws {
    continuation.yield(.downloading(progress: 0))
    let payload = try await fetchStore(for: cycle, reportingTo: continuation)
    defer { try? FileManager.default.removeItem(at: payload) }

    try await expandStore(
      payload,
      ofSize: cycle.manifest.store.bytes,
      to: destination,
      reportingTo: continuation
    )
  }

  /// The manifest for one cycle, or `nil` if it was never published.
  private func manifest(for cycle: String) async -> PublishedCycle? {
    let url = baseURL.appending(path: "\(cycle).json")
    let session = URLSession(configuration: manifestProbeConfiguration)
    defer { session.finishTasksAndInvalidate() }

    do {
      let (data, response) = try await session.data(from: url)
      if let http = response as? HTTPURLResponse, !http.isSuccessful {
        Self.logger.info("No published store for cycle \(cycle, privacy: .public)")
        return nil
      }
      return PublishedCycle(
        manifest: try NavDataStoreManifest.decoder().decode(NavDataStoreManifest.self, from: data),
        url: url
      )
    } catch {
      Self.logger.notice("Couldn’t read the manifest for \(cycle, privacy: .public): \(error)")
      return nil
    }
  }

  /// Downloads the store a manifest describes, and checks it against the digest published for it.
  private func fetchStore(
    for cycle: PublishedCycle,
    reportingTo continuation: AsyncStream<NavDataLoader.State>.Continuation
  ) async throws -> URL {
    let url = cycle.baseURL.appending(path: cycle.manifest.store.filename)

    let (progressUpdates, progress) = AsyncStream<Float>.makeStream(
      of: Float.self,
      bufferingPolicy: .bufferingNewest(1)
    )
    async let downloaded = Self.fetch(
      from: url,
      networkAccess: networkAccess,
      reportingTo: progress
    )
    for await completed in progressUpdates {
      continuation.yield(.downloading(progress: completed))
    }

    let payload = try await downloaded
    do {
      guard try await Self.digest(of: payload) == cycle.manifest.store.sha256 else {
        throw Errors.digestMismatch
      }
    } catch {
      try? FileManager.default.removeItem(at: payload)
      throw error
    }
    return payload
  }

  /**
   Expands a downloaded payload, mirroring the decompressor's progress onto the update's state.

   The decompression takes long enough that reporting no fraction for its duration reads to the
   system as a stalled task, which it expires to reclaim the resources.
   */
  private func expandStore(
    _ payload: URL,
    ofSize payloadBytes: UInt,
    to destination: URL,
    reportingTo continuation: AsyncStream<NavDataLoader.State>.Continuation
  ) async throws {
    let (progressUpdates, progress) = AsyncStream<Float>.makeStream(
      of: Float.self,
      bufferingPolicy: .bufferingNewest(1)
    )
    continuation.yield(.decompressing(progress: 0))
    async let expanded: Void = Self.expand(
      payload,
      ofSize: payloadBytes,
      to: destination,
      reportingTo: progress
    )
    for await completed in progressUpdates {
      continuation.yield(.decompressing(progress: completed))
    }
    try await expanded
  }

  /**
   A manifest and where it was published, so the store beside it can be addressed without
   rebuilding a URL out of the manifest's own contents.
   */
  struct PublishedCycle: Sendable {
    let manifest: NavDataStoreManifest
    let url: URL

    /// Where the assets this manifest describes are published.
    var baseURL: URL { url.deletingLastPathComponent() }
  }

  /**
   Reasons a prebuilt store could not be used.

   Each of these falls back to importing the published JSON, so in normal operation none of them
   reaches the pilot; the precise cause — which cycle, which store shape — is logged at the point
   it is discovered. What these carry is what would be worth saying in an alert if one of them
   ever did surface, in the pilot's terms rather than the store's.
   */
  enum Errors: LocalizedError {
    /// No cycle in range had a manifest this build could read.
    case noPublishedCycle

    /// The published store was built for a different shape of store than this build reads.
    case schemaMismatch

    /// The download did not match the digest its manifest published.
    case digestMismatch

    var errorDescription: String? {
      String(localized: "Couldn’t download the navigation data.")
    }

    var failureReason: String? {
      switch self {
        case .noPublishedCycle:
          String(localized: "The current navigation data isn’t available to download right now.")
        case .schemaMismatch:
          String(localized: "The available navigation data isn’t compatible with this app version.")
        case .digestMismatch:
          String(localized: "The navigation data was damaged in transit.")
      }
    }
  }
}
