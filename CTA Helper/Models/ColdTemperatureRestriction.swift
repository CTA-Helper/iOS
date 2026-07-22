import Foundation

/**
 An airport's Cold Temperature Airport restriction, from the FAA Cold Temperature Airports
 list: below ``restrictionTemperatureC`` a correction is mandatory on the
 ``affectedSegments`` (AIP ENR 1.8 4, 5.a).
 */
struct ColdTemperatureRestriction: Codable, Hashable, Sendable {
  var restrictionTemperatureC: Int
  var affectedSegments: Set<Segment>

  /// The temperature at or below which a correction is mandatory.
  var restrictionTemperature: Measurement<UnitTemperature> {
    .init(value: Double(restrictionTemperatureC), unit: .celsius)
  }
}
