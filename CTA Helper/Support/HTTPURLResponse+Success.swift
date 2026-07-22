import Foundation

/// The status codes that report a request the server accepted and answered.
private let successfulStatusCodes = 200..<300

extension HTTPURLResponse {
  /// Whether the server answered with a success (2xx) status code.
  var isSuccessful: Bool { successfulStatusCodes.contains(statusCode) }
}
