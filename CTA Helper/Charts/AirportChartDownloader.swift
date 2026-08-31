import Foundation
import Observation
import Sentry
import os

/**
 Downloads every plate an airport's approaches publish, at the pilot's request.

 A cache that only fills as plates are opened pre-fetches nothing, so airborne with no network
 the chart button is dead unless that exact plate happened to be opened on the ground. Rather
 than guess — warming favorites over Wi-Fi, say, and hoping the guess matches the trip — the
 pilot names the airport they are flying to and is told what it costs, and nothing downloads
 behind their back.
 */
@MainActor
@Observable
final class AirportChartDownloader {
  /// How many plates are fetched at once. The chart server is somebody else's; four is polite.
  private static let concurrencyLimit = 4

  /// What one plate is assumed to weigh, for the estimate shown before the pilot commits.
  private static let estimatedBytesPerPlate: UInt64 = 1_100_000

  nonisolated private static let logger = Logger(
    subsystem: "codes.tim.CTA-Helper",
    category: "AirportChartDownloader"
  )

  /// The run in progress, or `nil` when nothing is downloading.
  private(set) var progress: Progress?

  /// How the last run ended, or `nil` until one has.
  private(set) var summary: Summary?

  /// The failure to show the pilot, when a whole run failed.
  var error: (any Error)?

  private var run: Task<Void, Never>?

  /// Roughly what fetching this many plates costs, for the prompt shown before it starts.
  static func estimatedBytes(forPlates count: Int) -> UInt64 {
    UInt64(count) * estimatedBytesPerPlate
  }

  /**
   Fetch one plate, reporting how it went rather than throwing — one plate's failure is not the
   run's.

   What comes back names only what a summary needs, so nothing carrying an `any Error` has to
   cross the task group's boundary. The error itself is logged here, where it still exists.
   */
  nonisolated private static func fetch(_ id: ChartID, using store: ChartStore) async -> Outcome {
    if await store.cachedPlate(for: id) != nil { return .alreadyCached }

    do {
      let plate = try await store.plate(for: id)
      let bytes = (try? plate.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
      return .downloaded(bytes: UInt64(bytes))
    } catch {
      if case let .cycleSuperseded(cycle) = error as? ChartError {
        return .supersededCycle(cycle: cycle)
      }
      logger.warning("Could not download \(id.name): \(error)")
      return .failed(isOutOfDiskSpace: error.isOutOfDiskSpace)
    }
  }

  /**
   Fetch every plate in `ids`, keeping a bounded number in flight.

   Plates already cached are counted and skipped rather than fetched again. One plate failing
   does not end the run — the summary says how many did — but the first superseded cycle does,
   since every remaining plate of that cycle can only 404 too.
   */
  func start(_ ids: [ChartID], using store: ChartStore) {
    guard run == nil else { return }

    error = nil
    summary = nil
    progress = Progress(completed: 0, total: ids.count, bytesDownloaded: 0)

    run = Task {
      let tally = await fetch(ids, using: store)
      finish(with: tally)
    }
  }

  /// Stop the run. Plates already in flight finish and are filed; nothing further is started.
  func cancel() {
    run?.cancel()
  }

  private func fetch(_ ids: [ChartID], using store: ChartStore) async -> Tally {
    var tally = Tally()
    var remaining = ids.makeIterator()

    await withTaskGroup(of: Outcome.self) { group in
      for _ in 0..<Self.concurrencyLimit {
        guard let next = remaining.next() else { break }
        group.addTask { await Self.fetch(next, using: store) }
      }

      for await outcome in group {
        tally.record(outcome)
        publish(tally)

        if case .supersededCycle = outcome {
          group.cancelAll()
          break
        }
        guard !Task.isCancelled, let next = remaining.next() else { continue }
        group.addTask { await Self.fetch(next, using: store) }
      }
    }

    tally.wasCancelled = Task.isCancelled
    return tally
  }

  /// Publish how far along the run is.
  private func publish(_ tally: Tally) {
    progress = Progress(
      completed: tally.completed,
      total: progress?.total ?? tally.completed,
      bytesDownloaded: tally.bytesDownloaded
    )
  }

  /**
   Publish how the run ended.

   A run in which anything worked reports its tally and says nothing more; only one in which
   nothing did raises an error, and a cancelled one raises nothing at all.
   */
  private func finish(with tally: Tally) {
    run = nil
    progress = nil
    summary = tally.summary

    guard !tally.wasCancelled, tally.downloaded == 0, tally.alreadyCached == 0, tally.failed > 0
    else { return }

    let failure = tally.failure
    error = failure
    report(failure)
  }

  /**
   Send a failed run to crash reporting, under one fingerprint so every chart failure groups into
   a single issue rather than one per underlying cause.

   A failure the pilot's own environment caused — no network, a full disk, a cycle they have not
   updated — is not a defect and is filtered out here, so it does not bury the failures that are.
   */
  private func report(_ error: ChartError) {
    guard error.isReportable else { return }

    SentrySDK.capture(error: error) { scope in
      scope.setFingerprint(["charts", "download"])
    }
  }

  /// A bulk download in flight.
  struct Progress: Equatable, Sendable {
    /// How many plates have been settled, whether downloaded, skipped, or failed.
    let completed: Int
    /// How many plates the run started with.
    let total: Int
    /// How many bytes have arrived so far.
    let bytesDownloaded: UInt64

    /// How far along the run is, for a determinate progress view.
    var fraction: Double {
      total == 0 ? 0 : Double(completed) / Double(total)
    }
  }

  /// How a bulk download ended.
  struct Summary: Equatable, Sendable {
    /// How many plates were fetched.
    let downloaded: Int
    /// How many were already on disk.
    let alreadyCached: Int
    /// How many could not be fetched.
    let failed: Int
    /// How many bytes arrived.
    let bytesDownloaded: UInt64
    /// Whether the pilot stopped the run.
    let wasCancelled: Bool
  }

  /// How one plate's fetch went, in the only detail that has to leave the task that ran it.
  private enum Outcome: Sendable {
    case downloaded(bytes: UInt64)
    case alreadyCached
    case failed(isOutOfDiskSpace: Bool)
    case supersededCycle(cycle: String)
  }

  /// What a run accumulates while it runs.
  private struct Tally {
    var downloaded = 0
    var alreadyCached = 0
    var failed = 0
    var bytesDownloaded: UInt64 = 0
    var wasCancelled = false
    var supersededCycle: String?
    var ranOutOfDiskSpace = false

    var completed: Int { downloaded + alreadyCached + failed }

    var summary: AirportChartDownloader.Summary {
      .init(
        downloaded: downloaded,
        alreadyCached: alreadyCached,
        failed: failed,
        bytesDownloaded: bytesDownloaded,
        wasCancelled: wasCancelled
      )
    }

    /// What to tell the pilot when nothing at all arrived.
    var failure: ChartError {
      if let supersededCycle { return .cycleSuperseded(cycle: supersededCycle) }
      if ranOutOfDiskSpace { return .writeFailed(underlying: POSIXError(.ENOSPC)) }
      return .batchFailed
    }

    mutating func record(_ outcome: Outcome) {
      switch outcome {
        case let .downloaded(bytes):
          downloaded += 1
          bytesDownloaded += bytes
        case .alreadyCached:
          alreadyCached += 1
        case let .failed(isOutOfDiskSpace):
          failed += 1
          ranOutOfDiskSpace = ranOutOfDiskSpace || isOutOfDiskSpace
        case let .supersededCycle(cycle):
          failed += 1
          supersededCycle = supersededCycle ?? cycle
      }
    }
  }
}
