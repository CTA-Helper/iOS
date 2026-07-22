import Foundation

/**
 An error raised while downloading or importing the nav data.

 Every case shares one ``errorDescription`` — the category the pilot sees as the alert title.
 ``failureReason`` names the specific failure, interpolating context where there is any, and
 ``recoverySuggestion`` is present only where the pilot can actually do something about it.
 */
enum NavDataError: LocalizedError {
  /// The download server returned a non-success HTTP status.
  case httpError(statusCode: Int)
  /// The downloaded data file could not be gunzipped.
  case decompressionFailed(underlying: any Error)
  /// The manifest or data file could not be decoded.
  case decodingFailed(underlying: any Error)
  /// The decoded airports could not be saved to the store.
  case importFailed(underlying: any Error)
  /// The downloaded data file did not hash to the SHA-256 the manifest published.
  case checksumMismatch(expected: String, actual: String)
  /// The downloaded data file was not the size the manifest published.
  case sizeMismatch(expectedBytes: UInt, actualBytes: UInt)

  /**
   Whether this failure is worth reporting to crash reporting.

   A full disk is the pilot's own environment rather than a defect, and nothing in a report
   about one is actionable — sending them buries the failures that are.
   */
  var isReportable: Bool {
    switch self {
      case .importFailed(let underlying): !underlying.isOutOfDiskSpace
      default: true
    }
  }

  var errorDescription: String? {
    String(localized: "Couldn’t update the navigation data.")
  }

  var failureReason: String? {
    switch self {
      case .httpError(let statusCode):
        // A status code is an identifier, not a quantity: interpolate it literally so it never
        // picks up grouping separators (both `\(code)` and `.number` would render 1001 as 1,001).
        String(localized: "The server returned HTTP error \(String(statusCode)).")
      case .decompressionFailed:
        String(localized: "The downloaded data could not be decompressed.")
      case .decodingFailed:
        String(localized: "The downloaded data was not in the expected format.")
      case .importFailed:
        String(localized: "The navigation data could not be saved to your device.")
      case .checksumMismatch:
        // The digests themselves are 64 hex characters and mean nothing to a pilot; they go to
        // the log, which is where anyone who can act on them will look.
        String(localized: "The downloaded data did not match the published checksum.")
      case let .sizeMismatch(expectedBytes, actualBytes):
        String(
          localized:
            "The download was \(actualBytes, format: .number) bytes, but \(expectedBytes, format: .number) were published."
        )
    }
  }

  var recoverySuggestion: String? {
    switch self {
      case .httpError:
        String(localized: "Check your network connection and try again.")
      case .decompressionFailed, .checksumMismatch, .sizeMismatch:
        String(localized: "The download may be incomplete. Try updating again.")
      case .importFailed:
        String(localized: "Make sure your device has enough free storage, then try again.")
      case .decodingFailed:
        // A malformed published release is not something the pilot can act on.
        nil
    }
  }
}
