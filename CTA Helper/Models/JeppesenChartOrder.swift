import Foundation

/**
 The chart-type digit of a Jeppesen chart index number — the second digit of an index like
 `11-1`, which is what sequences an airport's approach charts.

 Jeppesen files the approach with the greatest precision and the lowest minimums first, so the
 digit doubles as a sort rank: the ILS ahead of the RNAV (GPS), which is ahead of the VOR. The
 digits the legend defines for procedures the FAA's coded database does not carry — `4`
 (TACAN), `5` (reserved), `7` (DF) and `8` (PAR, ASR, SRA, SRE) — have no case here; anything
 unrecognized files under `9` and sorts last.
 */
enum JeppesenChartType: Int, Comparable, Sendable {
  /// `1` — ILS, LOC, LDA, SDF, and the localizer back course.
  case ils = 1
  /// `2` — GPS, which is where the RNAV (GPS) and RNAV (RNP) procedures file.
  case gps = 2
  /// `3` — VOR, with or without DME.
  case vor = 3
  /// `6` — NDB, with or without DME.
  case ndb = 6
  /// `9` — what the other digits do not cover.
  case other = 9

  /**
   The chart type a procedure files under, read from its ARINC 424 route type — the first
   character of the approach identifier, the `R` of `R12-Y`.
   */
  init(arincIdentifier: String) {
    self =
      switch arincIdentifier.first {
        case "I", "L", "B", "X", "U": .ils
        case "P", "R", "H": .gps
        case "V", "D", "S": .vor
        case "N", "Q": .ndb
        default: .other
      }
  }

  static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// An instrument approach, as Jeppesen's chart filing order sees it.
protocol ChartedProcedure {
  /// The ARINC 424 identifier, e.g. `"R12-Y"`.
  var identifier: String { get }
  /// The name as charted, e.g. `"RNAV (GPS) Y RWY 12"`.
  var name: String { get }
}

extension Approach: ChartedProcedure {}

extension Array where Element: ChartedProcedure {
  /**
   The procedures in the order Jeppesen files their charts: by chart type, most precise
   first, and within a type by charted name, so an RNAV (GPS) Y precedes its Z.
   */
  func inJeppesenChartOrder() -> [Element] {
    sorted { first, second in
      let firstType = JeppesenChartType(arincIdentifier: first.identifier)
      let secondType = JeppesenChartType(arincIdentifier: second.identifier)
      guard firstType == secondType else { return firstType < secondType }
      return first.name.localizedStandardCompare(second.name) == .orderedAscending
    }
  }
}
