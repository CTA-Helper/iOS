import Foundation

/**
 The measurements the app is written in.

 Every altitude, height and correction is a `Measurement<UnitLength>` in feet, and every
 temperature a `Measurement<UnitTemperature>` in Celsius, from the moment a value leaves the
 store until it reaches the one control or formula that needs a bare number. Building one from
 the whole feet the store codes is what the app names for itself; the arithmetic the correction
 engine does on them comes from Foundation and MeasurementKit.
 */
extension Measurement where UnitType == UnitLength {
  /// A length in feet, the unit every US procedure publishes its altitudes in.
  static func feet(_ value: Double) -> Self { .init(value: value, unit: .feet) }

  /// A length in whole feet, as the nav data codes it and the store holds it.
  static func feet(_ value: Int) -> Self { .feet(Double(value)) }
}

extension Measurement where UnitType == UnitTemperature {
  /// This temperature rounded to the whole degrees Celsius a METAR reports in.
  var roundedToWholeCelsius: Self { .celsius(converted(to: .celsius).value.rounded()) }

  /// A temperature in degrees Celsius, the unit the correction tables and every METAR speak.
  static func celsius(_ value: Double) -> Self { .init(value: value, unit: .celsius) }
}
