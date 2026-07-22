import Foundation
import SwiftData

/**
 The AIRAC cycle of the currently imported nav data. A single row records which cycle is in
 the store, so the loader can tell whether the published release is newer.
 */
@Model
final class NavDataCycle {
  var airacCycle: String
  var effectiveDate: Date
  var expirationDate: Date
  /**
   The SHA-256 of the imported data file, compared against the manifest to detect a new
   cycle even within the same AIRAC identifier.
   */
  var sha256: String
  var importedAt: Date

  init(
    airacCycle: String,
    effectiveDate: Date,
    expirationDate: Date,
    sha256: String,
    importedAt: Date
  ) {
    self.airacCycle = airacCycle
    self.effectiveDate = effectiveDate
    self.expirationDate = expirationDate
    self.sha256 = sha256
    self.importedAt = importedAt
  }
}
