import Foundation

/**
 The parts of an error, kept apart so a presenter can lay them out as distinct elements rather
 than concatenating them into one string.

 Reading them through the `NSError` bridge covers both this app's `LocalizedError` enums and
 framework errors, which populate the same keys. A part is `nil` when the error does not supply
 it — notably ``recoverySuggestion``, which the error types set only when the pilot can act.
 */
struct ErrorPresentation {
  /// What went wrong, in the error category's own terms. Suitable as a title.
  let description: String
  /// The specific failure within that category.
  let failureReason: String?
  /// What the pilot can do about it.
  let recoverySuggestion: String?

  init(_ error: any Error) {
    let error = error as NSError
    description = error.localizedDescription
    failureReason = error.localizedFailureReason
    recoverySuggestion = error.localizedRecoverySuggestion
  }
}
