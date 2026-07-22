import Foundation

/**
 A single station's most recent METAR observation, reduced to the fields the app uses.

 The app auto-fills the reported airport temperature for cold-temperature altitude
 corrections, so ``temperature`` is the value that actually drives the UI; the observation
 ``date`` and ``rawText`` are retained for display and diagnostics.
 */
struct METARObservation: Sendable, Equatable {
  /// The ICAO identifier of the reporting station (for example, `"KMSO"`).
  let stationID: String

  /// The reported temperature in degrees Celsius, or `nil` if the METAR did not report one.
  let temperature: Measurement<UnitTemperature>?

  /// The time the observation was taken.
  let date: Date

  /// The raw METAR text, as published.
  let rawText: String
}
