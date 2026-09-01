import Foundation

/**
 What a ``ColdTemperatureRestriction`` means at the temperature a station is reporting now.

 The restriction alone says only that an airport is a Cold Temperature Airport and at what
 threshold; pairing it with the reported temperature says whether that threshold is in force
 today. The three cases are unequal on purpose: no observation is not the same answer as a
 temperature above the restriction, and must never be shown as though it were.
 */
enum ColdTemperatureStatus: Sendable {
  /// At or below the restriction: a correction is mandatory on the affected segments.
  case correctionRequired

  /// Above the restriction: nothing to correct at the reported temperature.
  case aboveRestriction

  /**
   No temperature to compare against, so whether the restriction applies is unknown — either the
   station is absent from the METAR cache, or its latest observation filed no temperature.
   */
  case noObservation

  /**
   Resolves what a restriction means at a reported temperature.

   - Parameters:
     - restriction: the airport's Cold Temperature Airport restriction.
     - reportedTemperature: the station's latest reported temperature, or `nil` where none was
       reported.
   */
  init(
    restriction: ColdTemperatureRestriction,
    reportedTemperature: Measurement<UnitTemperature>?
  ) {
    guard let reportedTemperature else {
      self = .noObservation
      return
    }
    self =
      reportedTemperature <= restriction.restrictionTemperature
      ? .correctionRequired : .aboveRestriction
  }
}
