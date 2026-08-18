import Foundation

/**
 The measurements the app is written in, and the arithmetic the correction engine does on them.

 Every altitude, height and correction is a `Measurement<UnitLength>` in feet, and every
 temperature a `Measurement<UnitTemperature>` in Celsius, from the moment a value leaves the
 store until it reaches the one control or formula that needs a bare number. Foundation already
 gives measurements `+`, `-` and the comparisons, so the engine adds and subtracts them
 directly; what it also needs — building one from the whole feet the store codes, and rounding
 one to a step — is here.
 */
extension Measurement where UnitType == UnitLength {
  /// A length in feet, the unit every US procedure publishes its altitudes in.
  static func feet(_ value: Double) -> Self { .init(value: value, unit: .feet) }

  /// A length in whole feet, as the nav data codes it and the store holds it.
  static func feet(_ value: Int) -> Self { .feet(Double(value)) }

  /**
   This length rounded to a multiple of `step`.

   - Parameters:
     - step: the multiple to round to, e.g. 100 ft to round to whole hundreds.
     - rule: how to resolve a length falling between two multiples; defaults to the same rule
       as `rounded()`.
   - Returns: the multiple of `step` that `rule` selects.
   */
  func rounded(
    toMultipleOf step: Self,
    rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero
  ) -> Self {
    let valueFt: Double = converted(to: .feet).value
    let stepFt: Double = step.converted(to: .feet).value
    return .feet(valueFt.rounded(toMultipleOf: stepFt, rule: rule))
  }
}

extension Measurement where UnitType == UnitTemperature {
  /// This temperature rounded to the whole degrees Celsius a METAR reports in.
  var roundedToWholeCelsius: Self { .celsius(converted(to: .celsius).value.rounded()) }

  /// A temperature in degrees Celsius, the unit the correction tables and every METAR speak.
  static func celsius(_ value: Double) -> Self { .init(value: value, unit: .celsius) }
}
