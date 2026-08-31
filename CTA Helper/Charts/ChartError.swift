import Foundation

/**
 An error raised while fetching or storing an approach plate.

 Every case shares one ``errorDescription`` — the category the pilot sees as the alert title.
 ``failureReason`` names the specific failure, and ``recoverySuggestion`` is present only where
 the pilot can actually do something about it.
 */
enum ChartError: LocalizedError {
  /// The plate is no longer published, which means the imported cycle has been superseded.
  case cycleSuperseded(cycle: String)
  /// The chart server returned some other non-success HTTP status.
  case httpError(statusCode: Int)
  /// The server answered, but with something that is not a PDF.
  case notAPDF(contentType: String?)
  /// The download failed after its retries were exhausted.
  case downloadFailed(underlying: any Error)
  /// The plate could not be written to the cache.
  case writeFailed(underlying: any Error)
  /// A whole airport's download finished without a single plate arriving.
  case batchFailed

  /**
   Whether this failure is worth reporting to crash reporting.

   Almost none of them are. The chart server belongs to the FAA rather than to this project, so
   a bad status or a failed download says something about the pilot's network or somebody
   else's server, and a full disk is the pilot's own environment — nothing in a report about any
   of those is actionable, and sending them buries the failures that are.

   The exception is a successful response that is not a PDF and not HTML. HTML is a captive
   portal or an error page, which is the pilot's environment again; anything else means the FAA
   changed the wire format under the app, which is worth knowing about.
   */
  var isReportable: Bool {
    switch self {
      case let .notAPDF(contentType): !Self.isHTML(contentType)
      case let .writeFailed(underlying): !underlying.isOutOfDiskSpace
      case .cycleSuperseded, .httpError, .downloadFailed, .batchFailed: false
    }
  }

  var errorDescription: String? {
    String(localized: "Couldn’t load the approach plate.")
  }

  var failureReason: String? {
    switch self {
      case let .cycleSuperseded(cycle):
        String(localized: "The chart for cycle \(cycle) is no longer published.")
      case let .httpError(statusCode):
        // A status code is an identifier, not a quantity: interpolate it literally so it never
        // picks up grouping separators (both `\(code)` and `.number` would render 1001 as 1,001).
        String(localized: "The chart server returned HTTP error \(String(statusCode)).")
      case .notAPDF:
        String(localized: "The chart server did not return a PDF.")
      case .downloadFailed:
        String(localized: "The chart could not be downloaded.")
      case .writeFailed:
        String(localized: "The chart could not be saved to your device.")
      case .batchFailed:
        String(localized: "None of this airport’s charts could be downloaded.")
    }
  }

  var recoverySuggestion: String? {
    switch self {
      case .cycleSuperseded:
        String(localized: "Update your navigation data, then try again.")
      case .httpError, .downloadFailed, .batchFailed:
        String(localized: "Check your network connection and try again.")
      case .writeFailed:
        String(localized: "Make sure your device has enough free storage, then try again.")
      case .notAPDF:
        // The FAA serving something other than a chart is not something the pilot can act on.
        nil
    }
  }

  /// Whether a response's content type names HTML, which a captive portal or error page returns.
  private static func isHTML(_ contentType: String?) -> Bool {
    contentType?.localizedCaseInsensitiveContains("html") ?? false
  }
}
