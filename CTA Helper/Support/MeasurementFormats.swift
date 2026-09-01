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

  /**
   An altitude with its unit spelled out, for a value VoiceOver reads rather than one the pilot
   sees.

   The fix list establishes feet by its column and prints digits alone; speech has no column, so
   an unqualified number read out of a row is a number with no unit at all.
   */
  static var spokenAltitude: Self {
    .measurement(
      width: .wide,
      usage: .asProvided,
      numberFormatStyle: .number.precision(.fractionLength(0))
    )
  }

  /**
   A cold temperature correction, signed, with its unit spelled out.

   The sign is written rather than implied: the addend is the one number on the row a sighted
   pilot works out by subtracting two others, so the direction it moves the altitude is part of
   the value rather than something to infer from it.
   */
  static var spokenCorrection: Self {
    .measurement(
      width: .wide,
      usage: .asProvided,
      numberFormatStyle: .number.precision(.fractionLength(0)).sign(strategy: .always())
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
