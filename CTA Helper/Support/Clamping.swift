import Foundation

extension Comparable {
  /**
   This value pinned to a range: the nearer bound when it falls outside, and the value itself
   when it does not.

   - Parameter range: the range to pin to.
   - Returns: a value `range` contains.
   */
  func clamped(to range: ClosedRange<Self>) -> Self {
    min(max(self, range.lowerBound), range.upperBound)
  }
}
