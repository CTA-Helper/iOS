import Foundation
import os

/**
 The `URLError` codes worth retrying: transient network failures rather than genuine
 client errors.
 */
private let transientURLErrorCodes: Set<URLError.Code> = [
  .cancelled,
  .cannotFindHost,
  .notConnectedToInternet,
  .networkConnectionLost,
  .timedOut,
  .dnsLookupFailed,
  .cannotConnectToHost,
  .internationalRoamingOff,
  .dataNotAllowed,
  .secureConnectionFailed
]

/// Whether an error is a transient network failure that a retry might clear.
func isTransientNetworkError(_ error: some Error) -> Bool {
  guard let urlError = error as? URLError else { return false }
  return transientURLErrorCodes.contains(urlError.code)
}

// periphery:ignore:parameters isolation
/**
 Retries an async operation with exponential backoff.

 `CancellationError` and `URLError.cancelled` always rethrow immediately. Other errors are
 tested with `shouldRetry`; transient errors are retried up to `maximumRetryCount` additional
 times with exponential backoff starting at `initialDelaySeconds`.
 */
func withRetry<T>(
  maximumRetryCount: Int = 3,
  initialDelaySeconds: Int = 2,
  logger: Logger,
  label: String,
  shouldRetry: (any Error) -> Bool = { isTransientNetworkError($0) },
  isolation: isolated (any Actor)? = #isolation,  // swiftlint:disable:this unused_parameter
  operation: () async throws -> T
) async throws -> T {
  for attempt in 0...maximumRetryCount {
    if attempt > 0 {
      let delaySeconds = initialDelaySeconds * (1 << (attempt - 1))
      logger.info(
        "\(label): retrying (attempt \(attempt + 1)/\(maximumRetryCount + 1), delay \(delaySeconds)s)"
      )
      try await Task.sleep(for: .seconds(delaySeconds))
    }

    do {
      return try await operation()
    } catch {
      if error is CancellationError { throw error }
      if let urlError = error as? URLError, urlError.code == .cancelled { throw urlError }
      if !shouldRetry(error) { throw error }
      if attempt == maximumRetryCount { throw error }
    }
  }

  fatalError("Retry loop exited without returning or throwing")
}
