import Foundation
import NavDataSchema

extension ColdTemperatureRestriction {
  /// The temperature at or below which a correction is mandatory.
  var restrictionTemperature: Measurement<UnitTemperature> {
    .celsius(Double(restrictionTemperatureC))
  }
}
