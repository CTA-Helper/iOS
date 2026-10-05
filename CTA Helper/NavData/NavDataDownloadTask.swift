import BackgroundTasks
import Foundation
import os

/**
 Keeps a nav data update the pilot started running after they leave the app.

 A plain `Task` gets seconds of runtime once the app is backgrounded, and the transfer would
 restart from nothing. A continued-processing task buys that time, and gives the system a
 progress and cancel affordance the app does not have to draw.

 The system expires these tasks on changing conditions, and cancels them outright when the app is
 swiped out of the switcher, without telling the app. That is safe because an update writes a
 generation nothing is reading: a task the system cancels costs a file, not the dataset in use.

 Failing to get a task is not an error. The update runs either way; it just runs unprotected.
 */
@MainActor
final class NavDataDownloadTask {
  /**
   The identifier this task is registered and submitted under.

   One fixed string, advertised verbatim in `BGTaskSchedulerPermittedIdentifiers`. A handler has
   to be registered while launching, so the identifier it answers for has to be known then —
   which rules out naming each submission after the update it belongs to.
   */
  nonisolated static let identifier = "codes.tim.CTA-Helper.navdata-download"

  /// The shared task broker.
  static let shared = NavDataDownloadTask()

  private let logger = Logger(subsystem: "codes.tim.CTA-Helper", category: "NavDataDownloadTask")

  private var isRegistered = false

  /**
   Resumed when the system hands over a task or the request is refused, carrying nothing:
   `BGContinuedProcessingTask` is not `Sendable`, and it never has to leave this actor to be
   handed back.
   */
  private var pendingStart: CheckedContinuation<Void, Never>?
  private var startedTask: BGContinuedProcessingTask?

  /**
   Whether a background task should be asked for at all.

   Inert under UI testing, so XCTest's wait-for-idle never stalls on system-owned work and no
   request is submitted during a test run.
   */
  private var isEnabled: Bool { !UITestConfiguration.isRunning }

  private init() {}

  /**
   Registers the launch handler.

   Called while the app is launching. Registering later is refused — the permitted identifiers
   are read once, and a handler offered afterwards is not matched against them.
   */
  func registerHandler() {
    guard isEnabled, !isRegistered else { return }

    isRegistered = BGTaskScheduler.shared.register(
      forTaskWithIdentifier: Self.identifier,
      using: .main
    ) { [weak self] task in
      MainActor.assumeIsolated {
        guard let continuedProcessing = task as? BGContinuedProcessingTask else {
          task.setTaskCompleted(success: false)
          return
        }
        self?.start(continuedProcessing)
      }
    }

    if !isRegistered {
      logger.error(
        "Couldn’t register \(Self.identifier, privacy: .public); is it permitted in Info.plist?"
      )
    }
  }

  /**
   Asks the system to let the update keep running when the app is backgrounded.

   - Parameters:
     - title: What the system should call this work.
     - subtitle: The phase to show beneath it.
   - Returns: The task to report progress to, or `nil` if the system would not start one — in
     which case the caller carries on unprotected. A caller that arrives while another's request
     is pending gets `nil` too: ``NavDataUpdater`` runs one update for both, and the pending
     request protects it.
   */
  func begin(title: String, subtitle: String) async -> BGContinuedProcessingTask? {
    guard isEnabled, isRegistered, pendingStart == nil else { return nil }

    // The launch handler can run as soon as the request is in, so the continuation it resumes has
    // to be parked before submission starts, not after it returns.
    await withCheckedContinuation { continuation in
      pendingStart = continuation
      Task { await submitRequest(title: title, subtitle: subtitle) }
    }
    defer { startedTask = nil }
    return startedTask
  }

  /// Submits the request off the main actor, which the scheduler asks of its callers.
  @concurrent
  nonisolated private func submitRequest(title: String, subtitle: String) async {
    let request = BGContinuedProcessingTaskRequest(
      identifier: Self.identifier,
      title: title,
      subtitle: subtitle
    )
    // Start now or not at all: a queued request waits on system load, and the update would rather
    // run unprotected than wait to begin.
    request.strategy = .fail

    do {
      try await BGTaskScheduler.shared.submitTaskRequest(request)
    } catch {
      await submissionFailed(error)
    }
  }

  private func submissionFailed(_ error: any Error) {
    logger.notice("Running the update unprotected: \(error.localizedDescription)")
    pendingStart?.resume()
    pendingStart = nil
  }

  private func start(_ task: BGContinuedProcessingTask) {
    guard let continuation = pendingStart else {
      // Nothing is waiting for this — most likely a request that outlived its update.
      task.setTaskCompleted(success: false)
      return
    }
    pendingStart = nil
    startedTask = task
    continuation.resume()
  }
}
