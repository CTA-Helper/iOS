import Foundation

/**
 The cold temperature altitude correction of AIP ENR 1.8, computed from the ICAO Doc 8168
 linear-approximation formula rather than by looking up the published table (TBL ENR 1.8-1).

 The table is a printout of this formula: evaluating it at all 98 of the table's grid points
 and rounding each result up to the next 10 ft reproduces every published cell exactly. The
 formula is

 ```
 ΔH = H · (15 − t) / (273 + t − ½·L₀·H)
 ```

 where `t` is the reported airport temperature in °C, `H` is the height above the airport in
 feet, and `L₀` is the ISA lapse rate. The `273` (not `273.15`) and the halved lapse term are
 what make the result match the FAA's table — see ``ColdTemperatureCorrectionTests``.
 */
enum ColdTemperatureCorrection {
  /// ISA temperature lapse rate, in °C per foot.
  private static let lapseRatePerFoot = 0.00198

  /// ISA sea-level temperature, in °C.
  private static let isaSeaLevelTemperatureC = 15.0

  /// The formula's absolute-temperature offset. The FAA's table uses 273, not 273.15.
  private static let absoluteZeroOffsetC = 273.0

  /**
   The height above the airport at which the published table stops; ENR 1.8 5.e permits
   using this column for any greater height rather than extrapolating.
   */
  static let tableCeilingFt = 5000.0

  /// ``tableCeilingFt`` as the measurement the engine compares a segment's height against.
  static let tableCeiling = Measurement<UnitLength>.feet(tableCeilingFt)

  /**
   The uncorrected altitude error for a reported temperature and height above the airport.

   This is the engine's way in: it holds measurements, and the scalars the formula is written
   in go no further up than ``correctionFt(reportedTemperatureC:heightAboveAirportFt:extrapolateAboveTable:)``
   below it.

   - Parameters:
     - reportedTemperature: the reported airport temperature.
     - heightAboveAirport: the height of the altitude being corrected above the airport.
     - extrapolateAboveTable: when `false`, heights above ``tableCeiling`` are treated as
       ``tableCeiling``, matching the FAA's worked example; when `true`, the formula is
       evaluated at the true height.
   - Returns: the correction to add to the published altitude, never negative.
   */
  static func correction(
    reportedTemperature: Measurement<UnitTemperature>,
    heightAboveAirport: Measurement<UnitLength>,
    extrapolateAboveTable: Bool = false
  ) -> Measurement<UnitLength> {
    .feet(
      correctionFt(
        reportedTemperatureC: reportedTemperature.converted(to: .celsius).value,
        heightAboveAirportFt: heightAboveAirport.converted(to: .feet).value,
        extrapolateAboveTable: extrapolateAboveTable
      )
    )
  }

  /**
   The uncorrected altitude error, in feet, for a reported temperature and height above the
   airport.

   - Parameters:
     - reportedTemperatureC: the reported airport temperature, in °C.
     - heightAboveAirportFt: the height of the altitude being corrected above the airport,
       in feet.
     - extrapolateAboveTable: when `false`, heights above ``tableCeilingFt`` are treated as
       ``tableCeilingFt``, matching the FAA's worked example; when `true`, the formula is
       evaluated at the true height.
   - Returns: the correction to add to the published altitude, in feet, never negative. A
     temperature at or above ISA (15 °C) yields zero — ENR 1.8 corrects for cold only.
   */
  static func correctionFt(
    reportedTemperatureC: Double,
    heightAboveAirportFt: Double,
    extrapolateAboveTable: Bool = false
  ) -> Double {
    let heightFt = clampedHeightFt(
      heightAboveAirportFt,
      extrapolateAboveTable: extrapolateAboveTable
    )
    guard heightFt > 0 else { return 0 }

    let numerator = heightFt * (isaSeaLevelTemperatureC - reportedTemperatureC)
    let denominator =
      absoluteZeroOffsetC + reportedTemperatureC - 0.5 * lapseRatePerFoot * heightFt
    return max(0, numerator / denominator)
  }

  private static func clampedHeightFt(_ heightFt: Double, extrapolateAboveTable: Bool) -> Double {
    extrapolateAboveTable ? heightFt : min(heightFt, tableCeilingFt)
  }
}
