import Testing

@testable import CTA_Helper

/// A minimal stand-in for an approach, so chart order is tested without SwiftData.
private struct Procedure: ChartedProcedure {
  let identifier: String
  let name: String
}

@Suite("Jeppesen chart order")
struct JeppesenChartOrderTests {
  @Test(
    "Reads the chart type from the ARINC 424 route type",
    arguments: [
      ("I12", JeppesenChartType.ils),
      ("L30", .ils),
      ("B12", .ils),
      ("X26L", .ils),
      ("U08", .ils),
      ("R12-Y", .gps),
      ("P16", .gps),
      ("H35-Z", .gps),
      ("V-A", .vor),
      ("D22", .vor),
      ("S04", .vor),
      ("N30", .ndb),
      ("Q17", .ndb),
      ("", .other),
      ("ZZZ", .other)
    ]
  )
  func readsChartType(identifier: String, expected: JeppesenChartType) {
    #expect(JeppesenChartType(arincIdentifier: identifier) == expected)
  }

  @Test("Files the most precise approach first, whatever order they arrive in")
  func filesMostPreciseFirst() {
    let ordered = [
      Procedure(identifier: "N12", name: "NDB RWY 12"),
      Procedure(identifier: "V12", name: "VOR RWY 12"),
      Procedure(identifier: "R12-Y", name: "RNAV (GPS) Y RWY 12"),
      Procedure(identifier: "I12", name: "ILS OR LOC RWY 12")
    ].inJeppesenChartOrder()

    #expect(
      ordered.map(\.identifier) == ["I12", "R12-Y", "V12", "N12"]
    )
  }

  @Test("Sequences same-type charts by charted name")
  func sequencesSameTypeByName() {
    let ordered = [
      Procedure(identifier: "R12-Z", name: "RNAV (GPS) Z RWY 12"),
      Procedure(identifier: "R12-Y", name: "RNAV (GPS) Y RWY 12"),
      Procedure(identifier: "R12-X", name: "RNAV (GPS) X RWY 12")
    ].inJeppesenChartOrder()

    #expect(ordered.map(\.identifier) == ["R12-X", "R12-Y", "R12-Z"])
  }

  @Test("Sorts an unrecognized route type last")
  func sortsUnrecognizedLast() {
    let ordered = [
      Procedure(identifier: "?12", name: "SOMETHING RWY 12"),
      Procedure(identifier: "N12", name: "NDB RWY 12")
    ].inJeppesenChartOrder()

    #expect(ordered.map(\.identifier) == ["N12", "?12"])
  }
}
