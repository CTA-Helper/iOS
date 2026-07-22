import Testing

@testable import CTA_Helper

/**
 The correction math is the part that must be right, so it is pinned against the FAA's own
 published table (TBL ENR 1.8-1). The table is the ICAO Doc 8168 formula rounded up to the
 next 10 ft, so reproducing every one of its 98 cells is the strongest available check.
 */
struct ColdTemperatureCorrectionTests {
  /// The reported-temperature rows of TBL ENR 1.8-1, in °C.
  private static let temperaturesC = [10.0, 0, -10, -20, -30, -40, -50]

  /// The height-above-airport columns of TBL ENR 1.8-1, in feet.
  private static let heightsFt = [
    200.0, 300, 400, 500, 600, 700, 800, 900, 1000, 1500, 2000, 3000, 4000, 5000
  ]

  /// The published correction cells, one row per temperature, one column per height.
  private static let cellsFt: [[Int]] = [
    [10, 10, 10, 10, 20, 20, 20, 20, 20, 30, 40, 60, 80, 90],
    [20, 20, 30, 30, 40, 40, 50, 50, 60, 90, 120, 170, 230, 280],
    [20, 30, 40, 50, 60, 70, 80, 90, 100, 150, 200, 290, 390, 490],
    [30, 50, 60, 70, 90, 100, 120, 130, 140, 210, 280, 420, 570, 710],
    [40, 60, 80, 100, 120, 140, 150, 170, 190, 280, 380, 570, 760, 950],
    [50, 80, 100, 120, 150, 170, 190, 220, 240, 360, 480, 720, 970, 1210],
    [60, 90, 120, 150, 180, 210, 240, 270, 300, 450, 590, 890, 1190, 1500]
  ]

  @Test("The formula reproduces every cell of the ICAO table, rounded up to 10 ft")
  func reproducesTheTable() {
    for (row, temperatureC) in Self.temperaturesC.enumerated() {
      for (column, heightFt) in Self.heightsFt.enumerated() {
        let rawFt = ColdTemperatureCorrection.correctionFt(
          reportedTemperatureC: temperatureC,
          heightAboveAirportFt: heightFt
        )
        let roundedUpToTenFt = Int((rawFt / 10).rounded(.up) * 10)
        #expect(
          roundedUpToTenFt == Self.cellsFt[row][column],
          "t=\(temperatureC)°C, H=\(heightFt) ft gave \(rawFt) → \(roundedUpToTenFt), table \(Self.cellsFt[row][column])"
        )
      }
    }
  }

  @Test("A temperature at or above ISA needs no correction")
  func warmYieldsZero() {
    #expect(
      ColdTemperatureCorrection.correctionFt(reportedTemperatureC: 15, heightAboveAirportFt: 3000)
        == 0
    )
    #expect(
      ColdTemperatureCorrection.correctionFt(reportedTemperatureC: 25, heightAboveAirportFt: 3000)
        == 0
    )
  }

  @Test("Zero height needs no correction")
  func zeroHeightYieldsZero() {
    #expect(
      ColdTemperatureCorrection.correctionFt(reportedTemperatureC: -40, heightAboveAirportFt: 0)
        == 0
    )
  }

  @Test("Heights above the table are capped by default and extrapolated on request")
  func heightAboveTheTable() {
    let cappedFt = ColdTemperatureCorrection.correctionFt(
      reportedTemperatureC: -12,
      heightAboveAirportFt: 8794
    )
    let atCeilingFt = ColdTemperatureCorrection.correctionFt(
      reportedTemperatureC: -12,
      heightAboveAirportFt: 5000
    )
    #expect(cappedFt == atCeilingFt)

    let extrapolatedFt = ColdTemperatureCorrection.correctionFt(
      reportedTemperatureC: -12,
      heightAboveAirportFt: 8794,
      extrapolateAboveTable: true
    )
    #expect(extrapolatedFt > atCeilingFt)
  }
}
