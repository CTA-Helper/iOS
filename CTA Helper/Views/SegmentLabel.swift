import Foundation

/**
 The segment names the fix and approach screens present, kept in the view layer because
 ``Segment`` itself is a coded classification with no display concern.
 */
extension Segment {
  /// The segment's name, as a correction summary line or a list of affected segments reads it.
  var label: String {
    switch self {
      case .initial: String(localized: "Initial")
      case .intermediate: String(localized: "Intermediate")
      case .final: String(localized: "Final")
      case .missed: String(localized: "Missed Approach")
    }
  }
}

extension FixGrouping.Group {
  /**
   The section header: the segment, and the transition its legs are flown on where the segment
   codes exactly one. A segment coding several is headed by its name alone, with the picker
   beside it naming the transition in force.
   */
  var label: String {
    guard transitions.count == 1, let name = transitions.first?.name else { return segment.label }
    return String(
      localized: "\(segment.label) · \(name)",
      comment: "Fix list section header: approach segment · transition name"
    )
  }
}
