import Foundation
import os

/**
 The approach plates held on disk, and the only thing that fetches one.

 `aeronav.faa.gov` serves every plate `no-store`, so `URLCache` caches nothing and this store is
 hand-built. Its layout is `<root>/<cycle>/<NAME>.pdf`, which does three things at once: a whole
 superseded cycle is discarded with one directory removal, a lookup can only ever find a plate
 published in the cycle it asked for, and the directory needs no index beside it — a file's size
 and the last time it was opened are the file's own attributes.

 Plates live in Application Support rather than in Caches. The system reclaims Caches under disk
 pressure, which on a pilot's full iPad is exactly the moment they are airborne with no network,
 and reclaiming what they deliberately downloaded is the one failure this store exists to
 prevent. They are excluded from backup instead, being re-downloadable.
 */
actor ChartStore {
  /// How many bytes of plates are kept before the least recently opened are evicted.
  static let defaultByteLimit: UInt64 = 200_000_000

  /// The bytes every PDF begins with, which is what decides that a response really is one.
  private static let pdfMagic = Array("%PDF-".utf8)

  /// The extension every cached plate carries, and the only one an enumeration counts.
  private static let plateExtension = "pdf"

  /**
   The largest response accepted as a plate.

   Plates run about 1 MB. Anything this far past that is not one, and refusing it keeps a
   misrouted response from evicting the whole cache to make room for itself.
   */
  private static let maximumPlateBytes = 32_000_000

  /**
   The session plates are fetched over.

   `URLSession.shared` carries the default seven-day resource timeout, which for a fetch a pilot
   is waiting on is no timeout at all. Ephemeral because the on-disk cache is this type's job.
   */
  private static let session: URLSession = {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 30
    configuration.timeoutIntervalForResource = 120
    return URLSession(configuration: configuration)
  }()

  private static let logger = Logger(
    subsystem: "codes.tim.CTA-Helper",
    category: "ChartStore"
  )

  private let root: URL

  private let byteLimit: UInt64

  /**
   The fetches running now, so two callers asking for one plate share one download.

   On iPad the chart button and the pane beside it can ask at once, and a bulk download can race
   a plate the pilot opens by hand.
   */
  private var inFlight: [ChartID: Task<URL, any Error>] = [:]

  /**
   Creates a store over a directory.

   - Parameters:
     - root: the directory plates are filed under, created on first write.
     - byteLimit: how many bytes of plates to keep before evicting the least recently opened.
   */
  init(root: URL, byteLimit: UInt64 = ChartStore.defaultByteLimit) {
    self.root = root
    self.byteLimit = byteLimit
  }

  /// The store the app runs against, or a per-launch one when a UI test is driving it.
  static func makeDefault() -> ChartStore {
    let root =
      UITestConfiguration.chartStoreRoot
      ?? URL.applicationSupportDirectory.appending(component: "Charts", directoryHint: .isDirectory)
    return ChartStore(root: root)
  }

  /// Whether a response body really is a PDF, judged by its own first bytes rather than a header.
  static func isPDF(_ data: Data) -> Bool {
    data.starts(with: pdfMagic)
  }

  /// Where the plate is filed if it is already on disk, without touching the network.
  func cachedPlate(for id: ChartID) -> URL? {
    let plate = url(for: id)
    guard FileManager.default.fileExists(atPath: plate.path(percentEncoded: false)) else {
      return nil
    }
    markOpened(plate)
    return plate
  }

  /// Where the plate is filed, downloading it first if it is not already cached.
  func plate(for id: ChartID) async throws -> URL {
    if let cached = cachedPlate(for: id) { return cached }
    if let running = inFlight[id] { return try await running.value }

    // Unstructured, and deliberately not cancelled when its first awaiter goes away: a plate
    // most of the way down is worth more finished and filed than abandoned.
    let fetch = Task { try await fetchAndStore(id) }
    inFlight[id] = fetch
    defer { inFlight[id] = nil }
    return try await fetch.value
  }

  /// How many bytes the cached plates occupy on disk.
  func totalBytes() -> UInt64 {
    entries().reduce(0) { $0 + $1.bytes }
  }

  /// Discard every cached plate.
  func removeAll() throws {
    guard FileManager.default.fileExists(atPath: root.path(percentEncoded: false)) else { return }
    try FileManager.default.removeItem(at: root)
  }

  /**
   Discard every plate not published in `cycle`.

   Run once per completed nav data import. It never throws: a purge that fails must not fail an
   import that has already committed, and since what to purge is read off the directory rather
   than off a record of past purges, the next import simply tries again.
   */
  func removeCharts(outside cycle: String) {
    let directories =
      (try? FileManager.default.contentsOfDirectory(
        at: root,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      )) ?? []

    for directory in directories where directory.lastPathComponent != cycle {
      do {
        try FileManager.default.removeItem(at: directory)
      } catch {
        Self.logger.warning(
          "Could not discard plates for \(directory.lastPathComponent): \(error)"
        )
      }
    }
  }

  /// Where a plate is filed, whether or not it is there.
  private func url(for id: ChartID) -> URL {
    root.appending(path: id.cachePath, directoryHint: .notDirectory)
  }

  private func fetchAndStore(_ id: ChartID) async throws -> URL {
    let data = try await download(id)
    return try store(data, for: id)
  }

  /**
   Fetch a plate, refusing anything that is not one before a byte of it reaches the disk.

   A superseded cycle answers 404 rather than a wrong chart, and a captive portal answers a login
   page — sometimes labelled `application/pdf`, which is why the body's own first bytes decide
   and the declared content type only explains.
   */
  private func download(_ id: ChartID) async throws -> Data {
    do {
      return try await withRetry(logger: Self.logger, label: "download \(id.name)") {
        let (data, response) = try await Self.session.data(from: id.fetchURL)
        // A file URL answers with a plain `URLResponse` and no status at all, which is how a UI
        // test serves a fixture; the magic bytes below are what actually vouch for the body.
        let http = response as? HTTPURLResponse
        if let http {
          if http.statusCode == 404 { throw ChartError.cycleSuperseded(cycle: id.cycle) }
          guard http.isSuccessful else { throw ChartError.httpError(statusCode: http.statusCode) }
        }
        guard data.count <= Self.maximumPlateBytes, Self.isPDF(data) else {
          throw ChartError.notAPDF(contentType: http?.value(forHTTPHeaderField: "Content-Type"))
        }
        return data
      }
    } catch let error as ChartError {
      // Already said why; retrying a 404 three times only delays the same answer.
      throw error
    } catch {
      if error.isCancellation { throw error }
      throw ChartError.downloadFailed(underlying: error)
    }
  }

  /**
   File a plate, making room for it first.

   Evicting before the write rather than after keeps the store from momentarily exceeding its
   budget on a device that may have no room for the excess. The write is atomic, so a plate is
   either wholly there or not there at all.
   */
  private func store(_ data: Data, for id: ChartID) throws -> URL {
    let plate = url(for: id)
    do {
      try prepareRoot()
      makeRoom(forAdditional: UInt64(data.count))
      try FileManager.default.createDirectory(
        at: plate.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try data.write(
        to: plate,
        options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
      )
    } catch {
      throw ChartError.writeFailed(underlying: error)
    }
    return plate
  }

  /// Create the root directory, and keep 200 MB of re-downloadable federal PDFs out of iCloud.
  private func prepareRoot() throws {
    if !FileManager.default.fileExists(atPath: root.path(percentEncoded: false)) {
      try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    // Set every time rather than only on the launch that created the directory: a store that
    // predates the flag, or one whose creation was interrupted after the directory appeared,
    // would otherwise carry 200 MB of re-downloadable federal PDFs into iCloud forever.
    var excluded = root
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try excluded.setResourceValues(values)
  }

  /// Evict the least recently opened plates until `incoming` more bytes fit inside the budget.
  private func makeRoom(forAdditional incoming: UInt64) {
    let evictions = Self.evictions(from: entries(), toFit: incoming, budget: byteLimit)
    for eviction in evictions {
      do {
        try FileManager.default.removeItem(at: eviction.url)
      } catch {
        Self.logger.warning("Could not evict \(eviction.url.lastPathComponent): \(error)")
      }
    }
  }

  /**
   Note that a plate was just opened, which is what orders eviction.

   The modification date stands in for the access date because nothing else ever modifies these
   files, and because a volume is not obliged to maintain access dates at all — an eviction order
   resting on one would be wrong in a way nothing could observe.
   */
  private func markOpened(_ plate: URL) {
    var plate = plate
    var values = URLResourceValues()
    values.contentModificationDate = .now
    try? plate.setResourceValues(values)
  }

  /**
   Every cached plate, with what eviction needs to know about it.

   Anything that is not a `.pdf` is skipped rather than counted: a crash between an atomic
   write's temporary file and its rename leaves a stray behind, and a stray must never be
   counted toward the budget, chosen for eviction, or mistaken for a plate.
   */
  private func entries() -> [CacheEntry] {
    let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .contentModificationDateKey]
    guard
      let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: keys,
        options: [.skipsHiddenFiles]
      )
    else { return [] }

    return enumerator.compactMap { element in
      guard let url = element as? URL, url.pathExtension == Self.plateExtension,
        let values = try? url.resourceValues(forKeys: Set(keys)),
        let bytes = values.totalFileAllocatedSize
      else { return nil }

      return CacheEntry(
        url: url,
        bytes: UInt64(bytes),
        lastOpened: values.contentModificationDate ?? .distantPast
      )
    }
  }
}
