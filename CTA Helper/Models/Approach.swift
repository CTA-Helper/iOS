import Foundation
import SwiftData

/// A published instrument approach procedure and its fixes.
@Model
final class Approach {
  /// The ARINC 424 identifier, e.g. `"R12-Y"`.
  var identifier: String
  /// The name as charted, e.g. `"RNAV (GPS) Y RWY 12"`.
  var name: String
  /// The runway served, e.g. `"12"`, or `nil` for a circling-only procedure.
  var runway: String?
  /// The approach plate's URL, or `nil` when no chart matched.
  var chartURL: URL?
  /// The altitude each correction method enters the calculation with.
  var referenceAltitudes: ReferenceAltitudes

  var airport: Airport?

  @Relationship(deleteRule: .cascade, inverse: \Fix.approach)
  var fixes: [Fix] = []

  init(
    identifier: String,
    name: String,
    runway: String?,
    chartURL: URL?,
    referenceAltitudes: ReferenceAltitudes
  ) {
    self.identifier = identifier
    self.name = name
    self.runway = runway
    self.chartURL = chartURL
    self.referenceAltitudes = referenceAltitudes
  }
}
