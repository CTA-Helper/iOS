import Foundation
import Gzip
import SwiftData
import os

/**
 Downloads and imports the nav data published at `github.com/CTA-Helper/Navdata`.

 The loader polls the manifest, and when its SHA-256 differs from the imported
 ``NavDataCycle`` it downloads the ~1.3 MB gzipped document, verifies it against the digest
 and byte counts the manifest publishes, decodes it, and replaces the store's airports in
 batches. ``state`` is polled by the view model to drive the loading UI.
 */
@ModelActor
actor NavDataLoader {
  /**
   How many rows are written between saves, to keep any one transaction bounded.

   Each save holds the store's write lock for its full commit, stalling other readers of the
   same store, so transactions are kept small and frequent. An airport carries nested approach
   and fix inserts, so the batch is bounded by total rows rather than airport count.
   */
  private static let saveBatchRowLimit = 2000

  /// Pause between batch saves, so other store users can interleave.
  private static let interBatchPause = Duration.milliseconds(50)

  /**
   The session the cycle is fetched over.

   `URLSession.shared` carries the default seven-day resource timeout, which for a download
   this app blocks its first launch on is no timeout at all.
   */
  private static let session: URLSession = {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 60
    configuration.timeoutIntervalForResource = 600
    return URLSession(configuration: configuration)
  }()

  private static let logger = Logger(
    subsystem: "codes.tim.CTA-Helper",
    category: "NavDataLoader"
  )

  private(set) var state: State = .idle

  /**
   Update the store to the newest published cycle, or do nothing if it is already imported.

   - Parameters:
     - force: when `true`, re-import even if the manifest's SHA-256 matches the imported cycle.
     - chartStore: the plate cache to clear of superseded cycles once the import commits, or
       `nil` to leave it alone.
   */
  func load(force: Bool = false, purgingChartsFrom chartStore: ChartStore? = nil) async throws {
    state = .checking
    let manifest = try await fetchManifest()

    if !force, try isAlreadyImported(manifest) {
      state = .finished
      return
    }

    state = .downloading(progress: nil)
    let compressed = try await download(NavDataManifest.dataURL)
    try NavDataIntegrity.verify(compressed, against: manifest.data)

    state = .importing(progress: nil)
    let document = try decode(gunzip(compressed, expecting: manifest.data.uncompressedBytes))

    // Drop the cycle record before the store is rewritten. From here until `recordCycle`
    // succeeds the airports are in flux, and a cycle standing over a half-written store would
    // let the next launch run against a partial procedure set instead of downloading it again.
    try clearCycle()
    try await replaceAirports(with: document)
    try recordCycle(manifest)

    // Only once the new cycle is committed. A load that failed partway leaves the old plates
    // standing, which the next successful import clears — the safe direction to fail in, and
    // the reason the purge reads what to discard off the cache rather than off a record of what
    // it discarded last time.
    await chartStore?.removeCharts(outside: manifest.airacCycle)

    state = .finished
  }

  private func fetchManifest() async throws -> NavDataManifest {
    let data = try await download(NavDataManifest.url)
    do {
      return try NavDataManifest.decoder().decode(NavDataManifest.self, from: data)
    } catch {
      throw NavDataError.decodingFailed(underlying: error)
    }
  }

  private func isAlreadyImported(_ manifest: NavDataManifest) throws -> Bool {
    do {
      let cycles = try modelContext.fetch(FetchDescriptor<NavDataCycle>())
      return cycles.first?.sha256 == manifest.data.sha256
    } catch {
      throw NavDataError.importFailed(underlying: error)
    }
  }

  private func download(_ url: URL) async throws -> Data {
    try await withRetry(logger: Self.logger, label: "download \(url.lastPathComponent)") {
      let (data, response) = try await Self.session.data(from: url)
      if let http = response as? HTTPURLResponse, !http.isSuccessful {
        throw NavDataError.httpError(statusCode: http.statusCode)
      }
      return data
    }
  }

  private func gunzip(_ compressed: Data, expecting uncompressedBytes: UInt) throws -> Data {
    let data: Data
    do {
      data = try compressed.gunzipped()
    } catch {
      throw NavDataError.decompressionFailed(underlying: error)
    }

    try NavDataIntegrity.verifySize(of: data, expecting: uncompressedBytes)
    return data
  }

  private func decode(_ data: Data) throws -> NavDataDocument {
    do {
      return try JSONDecoder().decode(NavDataDocument.self, from: data)
    } catch {
      throw NavDataError.decodingFailed(underlying: error)
    }
  }

  private func replaceAirports(with document: NavDataDocument) async throws {
    do {
      try await deleteAll(Airport.self)

      let total = document.airports.count
      var rowsSinceLastSave = 0

      for (index, dto) in document.airports.enumerated() {
        guard let airport = dto.makeAirport() else { continue }
        modelContext.insert(airport)
        rowsSinceLastSave += rowCount(of: airport)

        if rowsSinceLastSave >= Self.saveBatchRowLimit {
          try modelContext.save()
          rowsSinceLastSave = 0
          state = .importing(progress: Double(index + 1) / Double(total))
          try await Task.sleep(for: Self.interBatchPause)
        }
      }

      if modelContext.hasChanges { try modelContext.save() }
    } catch is CancellationError {
      throw CancellationError()
    } catch {
      throw NavDataError.importFailed(underlying: error)
    }
  }

  /**
   Delete every row of `model` in bounded transactions.

   SwiftData's bulk `delete(model:)` removes every row in a single transaction that holds the
   store's write lock for its full duration, stalling concurrent main-context reads long enough
   to trip an app-hang report. Deleting in bounded transactions with a pause between them keeps
   each lock hold short, mirroring the insert path.
   */
  private func deleteAll<Model: PersistentModel>(_: Model.Type) async throws {
    var descriptor = FetchDescriptor<Model>()
    descriptor.fetchLimit = Self.saveBatchRowLimit

    while case let batch = try modelContext.fetch(descriptor), !batch.isEmpty {
      for object in batch { modelContext.delete(object) }
      try modelContext.save()
      try await Task.sleep(for: Self.interBatchPause)
    }
  }

  /// How many rows inserting one airport writes: the airport, its approaches, and their fixes.
  private func rowCount(of airport: Airport) -> Int {
    airport.approaches.reduce(1 + airport.approaches.count) { $0 + $1.fixes.count }
  }

  /**
   Forget which cycle is imported, so a load that fails partway leaves nothing claiming the
   half-written store is current.
   */
  private func clearCycle() throws {
    do {
      try modelContext.delete(model: NavDataCycle.self)
      try modelContext.save()
    } catch {
      throw NavDataError.importFailed(underlying: error)
    }
  }

  private func recordCycle(_ manifest: NavDataManifest) throws {
    do {
      modelContext.insert(
        NavDataCycle(
          airacCycle: manifest.airacCycle,
          effectiveDate: manifest.cycleEffective,
          expirationDate: manifest.cycleExpires,
          sha256: manifest.data.sha256,
          importedAt: .now
        )
      )
      try modelContext.save()
    } catch {
      throw NavDataError.importFailed(underlying: error)
    }
  }

  enum State: Equatable, Sendable {
    case idle
    case checking
    case downloading(progress: Double?)
    case importing(progress: Double?)
    case finished
  }
}
