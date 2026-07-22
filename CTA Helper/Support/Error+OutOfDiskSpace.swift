import Foundation

extension Error {
  /**
   Whether this error, or any error in its `NSUnderlyingErrorKey` chain, is a POSIX `ENOSPC`
   "No space left on device".

   SwiftData reports a failed write as a `CocoaError` wrapping the SQLite layer's own `NSError`,
   so the condition has to be looked for down the chain rather than on the error handed back.
   */
  var isOutOfDiskSpace: Bool {
    let nsError = self as NSError
    if nsError.domain == NSPOSIXErrorDomain, nsError.code == Int(ENOSPC) { return true }
    if let posix = self as? POSIXError, posix.code == .ENOSPC { return true }
    if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? any Error {
      return underlying.isOutOfDiskSpace
    }
    return false
  }
}
