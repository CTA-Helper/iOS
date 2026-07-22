import Foundation

extension FormatStyle where Self == Measurement<UnitTemperature>.FormatStyle {
  /**
   A reported temperature, in whole degrees Celsius.

   Pinned with `usage: .asProvided` so a locale that prefers Fahrenheit cannot silently
   convert it: the correction tables, the slider and the METAR all speak Celsius.
   */
  static var reportedTemperature: Self {
    .measurement(
      width: .abbreviated,
      usage: .asProvided,
      numberFormatStyle: .number.precision(.fractionLength(0))
    )
  }
}

extension FormatStyle where Self == Measurement<UnitLength>.FormatStyle {
  /**
   An altitude, in whole feet.

   Pinned with `usage: .asProvided` for the same reason as ``reportedTemperature``: every
   altitude in a US procedure is published in feet, and converting one to metres would be a
   value the pilot cannot find on the plate.
   */
  static var altitude: Self {
    .measurement(
      width: .abbreviated,
      usage: .asProvided,
      numberFormatStyle: .number.precision(.fractionLength(0))
    )
  }
}

/**
 An altitude rendered as its digits alone, in whole feet.

 `Measurement<UnitLength>.FormatStyle` always writes a unit, and a fix list that repeated "ft"
 down every altitude in every row reads as noise — the plate the column mirrors prints digits.
 The conversion is still pinned to feet, so the value a locale preferring metres shows is the
 one on the plate.
 */
struct AltitudeDigitsFormatStyle: FormatStyle {
  func format(_ altitude: Measurement<UnitLength>) -> String {
    altitude.converted(to: .feet).value.formatted(.number.precision(.fractionLength(0)))
  }
}

extension FormatStyle where Self == AltitudeDigitsFormatStyle {
  /// An altitude's digits alone, for a column whose unit is established by its surroundings.
  static var altitudeDigits: Self { AltitudeDigitsFormatStyle() }
}
