import Foundation

/**
 An error raised while downloading the national METAR cache.

 Weather is best-effort: ``METARLoader`` logs these and keeps whatever observations it already
 holds, so none of them reach the pilot as an alert. That is why no case carries a
 ``recoverySuggestion`` — there is no action to offer for a failure nobody is shown.
 */
enum WeatherError: LocalizedError {
  /// The weather server returned a non-success HTTP status.
  case httpError(statusCode: Int)
  /// The downloaded METAR cache could not be gunzipped.
  case decompressionFailed(underlying: any Error)

  /**
   Whether this failure is worth reporting to crash reporting.

   A weather server that is down or rate-limiting is neither a defect nor actionable, and the
   app already degrades gracefully around it; reporting every one would drown out the case that
   does mean something — a cache that no longer decompresses, which is the publisher changing
   the format out from under the app.
   */
  var isReportable: Bool {
    switch self {
      case .httpError: false
      case .decompressionFailed: true
    }
  }

  var errorDescription: String? {
    String(localized: "Couldn’t load the latest weather.")
  }

  var failureReason: String? {
    switch self {
      case .httpError(let statusCode):
        // A status code is an identifier, not a quantity — interpolate it literally.
        String(localized: "The weather server returned HTTP error \(String(statusCode)).")
      case .decompressionFailed:
        String(localized: "The weather data could not be decompressed.")
    }
  }
}
