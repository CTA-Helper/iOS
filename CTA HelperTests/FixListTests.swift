import Testing

@testable import CTA_Helper

/// A minimal stand-in for a fix, so grouping is tested without SwiftData.
private struct Leg {
  let name: String
  let segment: Segment
  let transition: String?
  let sequence: UInt

  init(_ name: String, _ segment: Segment, transition: String? = nil, sequence: UInt) {
    self.name = name
    self.segment = segment
    self.transition = transition
    self.sequence = sequence
  }
}

@Suite("Fix grouping")
struct FixGroupingTests {
  private func groups(_ legs: [Leg]) -> [FixGrouping.Group<Leg>] {
    FixGrouping.groups(
      legs,
      segment: \.segment,
      transition: \.transition,
      sequence: \.sequence
    )
  }

  @Test("Orders sections by segment, omitting the segments no fix falls in")
  func ordersSectionsBySegment() {
    let result = groups([
      Leg("JENKI", .missed, sequence: 90),
      Leg("SUPPY", .intermediate, sequence: 30),
      Leg("LANNY", .initial, sequence: 10)
    ])

    #expect(result.map(\.segment) == [.initial, .intermediate, .missed])
  }

  /**
   The legs arrive from an unordered SwiftData relationship, so the order they come in must not
   decide which transition a section opens on — the same approach would show a different route
   between launches. These legs are deliberately given in an order first appearance would sort
   the other way.
   */
  @Test("Collects a segment's transitions by name, whatever order its legs arrive in")
  func collectsTransitionsByName() {
    let result = groups([
      Leg("ODIRE", .initial, transition: "JENKI", sequence: 20),
      Leg("DENIM", .initial, transition: "DENIM", sequence: 10),
      Leg("LANNY", .initial, transition: "JENKI", sequence: 10)
    ])

    #expect(result.count == 1)
    #expect(result[0].transitions.map(\.name) == ["DENIM", "JENKI"])
    #expect(result[0].transitions[0].elements.map(\.name) == ["DENIM"])
    #expect(result[0].transitions[1].elements.map(\.name) == ["LANNY", "ODIRE"])
  }

  @Test("Flies the selected transition's legs before the legs they converge onto")
  func fliesTheTransitionBeforeTheCommonRoute() {
    let result = groups([
      Leg("ODIRE", .initial, sequence: 10),
      Leg("LANNY", .initial, transition: "JENKI", sequence: 40),
      Leg("CHARL", .initial, transition: "CHARL", sequence: 10)
    ])

    #expect(result[0].commonElements.map(\.name) == ["ODIRE"])
    #expect(result[0].elements(via: "JENKI").map(\.name) == ["LANNY", "ODIRE"])
    #expect(result[0].elements(via: "CHARL").map(\.name) == ["CHARL", "ODIRE"])
  }

  @Test("Sorts a segment with no transitions by sequence alone")
  func sortsBySequence() {
    let result = groups([
      Leg("RW12", .final, sequence: 50),
      Leg("BEGPE", .final, sequence: 40),
      Leg("Minimums", .final, sequence: .max)
    ])

    #expect(result.count == 1)
    #expect(result[0].transitions.isEmpty)
    #expect(result[0].elements(via: nil).map(\.name) == ["BEGPE", "RW12", "Minimums"])
  }
}

@Suite("Leg instructions")
struct LegInstructionTests {
  @Test(
    "Reads the instruction off the leg's path terminator",
    arguments: [
      (LegType.courseToAltitude, "Climb to"),
      (LegType.headingToAltitude, "Climb to"),
      (LegType.fixToAltitude, "Climb to"),
      (LegType.holdToManualTermination, "Hold at"),
      (LegType.holdToFix, "Hold at"),
      (LegType.holdToAltitude, "Hold at"),
      (LegType.procedureTurn, "Procedure turn at"),
      (LegType.headingToIntercept, "Turn to intercept"),
      (LegType.courseToRadial, "Turn to intercept"),
      (LegType.headingToDME, "Proceed to"),
      (LegType.arcToFix, "Arc to"),
      (LegType.headingToManualTermination, "Proceed from")
    ]
  )
  func instructsFromLegType(legType: LegType, expected: String) {
    #expect(LegInstruction.instruction(for: legType) == expected)
  }

  @Test(
    "Instructs nothing for a leg that only tracks to its fix",
    arguments: [LegType.initialFix, .trackToFix, .courseToFix, .directToFix]
  )
  func instructsNothingForATrackToAFix(legType: LegType) {
    #expect(LegInstruction.instruction(for: legType) == nil)
  }

  @Test("Instructs nothing for a leg type the app does not recognize")
  func instructsNothingForUnknownLegType() {
    #expect(LegInstruction.instruction(for: nil) == nil)
  }
}
