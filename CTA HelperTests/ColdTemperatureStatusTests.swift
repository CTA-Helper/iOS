import Foundation
import Testing

@testable import CTA_Helper

@Suite
struct `Cold temperature status` {
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

  @Test
  func `a temperature at the restriction requires a correction`() {
    #expect(Self.status(at: -11) == .correctionRequired)
  }

  @Test
  func `a temperature below the restriction requires a correction`() {
    #expect(Self.status(at: -20) == .correctionRequired)
  }

  @Test
  func `a temperature above the restriction requires nothing`() {
    #expect(Self.status(at: -10) == .aboveRestriction)
  }

  @Test
  func `an unreported temperature is not an answer either way`() {
    #expect(Self.status(at: nil) == .noObservation)
  }
}
