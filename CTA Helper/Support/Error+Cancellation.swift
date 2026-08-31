import Foundation

extension Error {
  /**
   Whether this error is a task that was cancelled rather than one that failed.

   A `URLSession` request cancelled with its task reports `URLError.Code.cancelled` rather than
   `CancellationError`, so both spellings count — a view that goes away mid-request is not a
   fault, and nothing about one is worth reporting.
   */
  var isCancellation: Bool {
    self is CancellationError || (self as? URLError)?.code == .cancelled
  }
}
