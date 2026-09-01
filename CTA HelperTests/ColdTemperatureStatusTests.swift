import Foundation
import Testing

@testable import CTA_Helper

@Suite("Cold temperature status")
struct ColdTemperatureStatusTests {
  private static let restriction = ColdTemperatureRestriction(
    restrictionTemperatureC: -11,
    affectedSegments: [.initial, .intermediate, .final]
  )

  private static func status(at celsius: Double?) -> ColdTemperatureStatus {
    .init(
      restriction: restriction,
      reportedTemperature: celsius.map { .celsius($0) }
    )
  }

  @Test("A temperature at the restriction requires a correction")
  func atTheRestriction() {
    #expect(Self.status(at: -11) == .correctionRequired)
  }

  @Test("A temperature below the restriction requires a correction")
  func belowTheRestriction() {
    #expect(Self.status(at: -20) == .correctionRequired)
  }

  @Test("A temperature above the restriction requires nothing")
  func aboveTheRestriction() {
    #expect(Self.status(at: -10) == .aboveRestriction)
  }

  @Test("An unreported temperature is not an answer either way")
  func withoutATemperature() {
    #expect(Self.status(at: nil) == .noObservation)
  }
}
