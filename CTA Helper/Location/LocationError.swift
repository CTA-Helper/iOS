import Foundation

/**
 An error raised while streaming the device location for the Nearest tab.

 Denied permission is the one failure the pilot can act on, so it is the only case carrying a
 ``recoverySuggestion``.
 */
enum LocationError: LocalizedError {
  /// Location permission was denied or restricted.
  case permissionDenied

  var errorDescription: String? {
    String(localized: "Couldn’t find nearby airports.")
  }

  var failureReason: String? {
    switch self {
      case .permissionDenied:
        String(localized: "CTA Helper doesn’t have permission to use your location.")
    }
  }

  var recoverySuggestion: String? {
    switch self {
      case .permissionDenied:
        String(localized: "Allow location access for CTA Helper in Settings.")
    }
  }
}
