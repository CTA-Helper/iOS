import Foundation
import Gzip
import NavDataSchema
import SwiftData
import os

/**
 Downloads the JSON release published at `github.com/CTA-Helper/Navdata` and writes it into a
 store, for when no prebuilt store can be installed.

 It writes into an empty store of its own — the next *generation* of the dataset — and never
 touches the one in use. Nothing switches to what it wrote until the write finishes and the
 result is found to hold airports, so an import that fails, or is killed when the pilot swipes
 the app away, costs the pilot nothing. That is why there is no step here that clears anything
 first.

 ## Executor Constraints

 The writer is a `@ModelActor`, whose executor blocks whoever enqueues onto it for as long as it
 is busy. Progress therefore leaves through ``stateUpdates()`` rather than through state a caller
 would have to await, and the CPU-bound gunzip and decode run in `@concurrent` functions.
 */
actor NavDataLoader {
  /// The seconds a request may go without receiving data before it is abandoned.
  private static let requestTimeoutSeconds: TimeInterval = 60

  /**
   The seconds a whole transfer may take.

   The system default is seven days, which for a download a pilot is watching is no timeout at
   all.
   */
  private static let resourceTimeoutSeconds: TimeInterval = 600

  /**
   Smallest change in download progress worth pushing to consumers.

   The session reports progress once per received chunk, which is far finer than a progress
   indicator can show; coarsening it keeps consumers from waking hundreds of times a second for
   changes they cannot render.
   */
  private static let progressReportingStep: Float = 0.005

  private static let logger = Logger(subsystem: "codes.tim.CTA-Helper", category: "NavDataLoader")

  private(set) var state: State = .idle {
    didSet { stateContinuation?.yield(state) }
  }

  private let writer: NavDataStoreWriter
  private let networkAccess: NavDataNetworkAccess
  private var stateContinuation: AsyncStream<State>.Continuation?

  /**
   - Parameters:
     - modelContainer: A container whose store accepts writes, holding the generation this
       import is producing.
     - networkAccess: The networks the downloads may use.
   */
  init(modelContainer: ModelContainer, networkAccess: NavDataNetworkAccess) {
    writer = .init(modelContainer: modelContainer)
    self.networkAccess = networkAccess
  }

  /**
   The manifest of the newest published release.

   - Parameter networkAccess: The networks the request may use.
   */
  nonisolated static func fetchManifest(
    networkAccess: NavDataNetworkAccess
  ) async throws -> NavDataReleaseManifest {
    let session = URLSession(configuration: sessionConfiguration(for: networkAccess))
    defer { session.finishTasksAndInvalidate() }

    let data = try await withRetry(logger: logger, label: "download manifest") {
      let (data, response) = try await session.data(from: NavDataReleaseManifest.url)
      try checkStatus(of: response)
      return data
    }
    do {
      return try NavDataReleaseManifest.decoder().decode(NavDataReleaseManifest.self, from: data)
    } catch {
      throw NavDataError.decodingFailed(underlying: error)
    }
  }

  /// The session configuration every request here runs on.
  nonisolated private static func sessionConfiguration(
    for networkAccess: NavDataNetworkAccess
  ) -> URLSessionConfiguration {
    let configuration = networkAccess.sessionConfiguration
    configuration.timeoutIntervalForRequest = requestTimeoutSeconds
    configuration.timeoutIntervalForResource = resourceTimeoutSeconds
    return configuration
  }

  /// Gunzips, checks and decodes the downloaded release, off this actor's executor.
  @concurrent
  nonisolated private static func decode(
    _ compressed: Data,
    expecting uncompressedBytes: UInt
  ) async throws -> NavDataDocument {
    let data: Data
    do {
      data = try compressed.gunzipped()
    } catch {
      throw NavDataError.decompressionFailed(underlying: error)
    }
    try NavDataIntegrity.verifySize(of: data, expecting: uncompressedBytes)

    do {
      return try JSONDecoder().decode(NavDataDocument.self, from: data)
    } catch {
      throw NavDataError.decodingFailed(underlying: error)
    }
  }

  /// Reads the downloaded release and checks it against its manifest, off this actor's executor.
  @concurrent
  nonisolated private static func verifiedPayload(
    at url: URL,
    against file: NavDataReleaseManifest.DataFile
  ) async throws -> Data {
    let payload = try Data(contentsOf: url)
    try NavDataIntegrity.verify(payload, against: file)
    return payload
  }

  /// Throws the error a non-success HTTP status reports, for a response that has one.
  nonisolated private static func checkStatus(of response: URLResponse) throws {
    if let http = response as? HTTPURLResponse, !http.isSuccessful {
      throw NavDataError.httpError(statusCode: http.statusCode)
    }
  }

  nonisolated private static func fetch(
    from url: URL,
    configuration: URLSessionConfiguration,
    reportingTo continuation: AsyncStream<Float>.Continuation
  ) async throws -> URL {
    defer { continuation.finish() }
    let (fileURL, response) = try await downloadWithRetry(
      from: url,
      configuration: configuration,
      logger: logger,
      label: "download \(url.lastPathComponent)",
      reportingTo: continuation
    )
    do {
      try checkStatus(of: response)
    } catch {
      try? FileManager.default.removeItem(at: fileURL)
      throw error
    }
    return fileURL
  }

  /**
   A stream of ``State`` values, starting with the loader's current state and finishing when
   ``load(_:)`` returns or throws.

   Only one stream is live at a time; a second call finishes the previous one.
   */
  func stateUpdates() -> AsyncStream<State> {
    stateContinuation?.finish()
    let (stream, continuation) = AsyncStream.makeStream(
      of: State.self,
      bufferingPolicy: .bufferingNewest(1)
    )
    continuation.yield(state)
    stateContinuation = continuation
    return stream
  }

  /**
   Downloads the release `manifest` describes and writes it into this loader's store.

   - Parameter manifest: The release to import, from ``fetchManifest(networkAccess:)``.
   */
  func load(_ manifest: NavDataReleaseManifest) async throws {
    defer { stateContinuation?.finish() }

    state = .downloading(progress: 0)
    let payload = try await download(NavDataReleaseManifest.dataURL)
    defer { try? FileManager.default.removeItem(at: payload) }
    let compressed = try await Self.verifiedPayload(at: payload, against: manifest.data)

    state = .decompressing(progress: nil)
    let document = try await Self.decode(compressed, expecting: manifest.data.uncompressedBytes)

    state = .processing(progress: 0)
    try await write(document, release: manifest)

    state = .finished
  }

  /**
   Downloads the release to a temporary file, mirroring the transfer's progress onto ``state``.

   The transfer runs as a child task so this actor stays free to drain its progress; the stream
   closes when the transfer settles, ending the loop.
   */
  private func download(_ url: URL) async throws -> URL {
    let (progressUpdates, continuation) = AsyncStream<Float>.makeStream(
      of: Float.self,
      bufferingPolicy: .bufferingNewest(1)
    )
    async let downloaded = Self.fetch(
      from: url,
      configuration: Self.sessionConfiguration(for: networkAccess),
      reportingTo: continuation
    )
    for await completed in progressUpdates { reportDownloadProgress(completed) }

    return try await downloaded
  }

  private func reportDownloadProgress(_ progress: Float) {
    guard case .downloading(let reported) = state else { return }
    if let reported, abs(progress - reported) < Self.progressReportingStep { return }
    state = .downloading(progress: progress)
  }

  /**
   Writes the decoded dataset, mirroring the writer's progress onto ``state``.

   The write runs as a child task so this actor stays free to drain its progress; the stream
   closes when the write settles, ending the loop.
   */
  private func write(_ document: NavDataDocument, release: NavDataReleaseManifest) async throws {
    let (progressUpdates, continuation) = AsyncStream<Float>.makeStream(
      of: Float.self,
      bufferingPolicy: .bufferingNewest(1)
    )
    async let written = writer.write(document, release: release, reportingTo: continuation)
    for await completed in progressUpdates { state = .processing(progress: completed) }

    do {
      _ = try await written
    } catch is CancellationError {
      throw CancellationError()
    } catch {
      throw NavDataError.importFailed(underlying: error)
    }
  }

  /// How far an update has got, as the loading screen and the system's progress display show it.
  enum State: Equatable, Sendable {
    /// Nothing has started.
    case idle
    /// The dataset is being transferred, with the fraction received where it is known.
    case downloading(progress: Float?)
    /// The transfer is being expanded, with the fraction consumed where it is known.
    case decompressing(progress: Float?)
    /// The dataset is being written into the store, with the fraction written where it is known.
    case processing(progress: Float?)
    /// The update is installed, or there was nothing newer to install.
    case finished
  }
}
