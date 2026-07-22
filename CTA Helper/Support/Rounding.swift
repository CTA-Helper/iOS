import Foundation

extension Double {
  /**
   This value rounded to a multiple of `step`.

   The standard library rounds only to an integral value, so rounding to hundreds of feet
   goes through the step: divide, round, multiply back.

   - Parameters:
     - step: the multiple to round to, e.g. `100` to round to whole hundreds.
     - rule: how to resolve a value falling between two multiples; defaults to the same rule
       as `rounded()`.
   - Returns: the multiple of `step` that `rule` selects.
   */
  func rounded(
    toMultipleOf step: Double,
    rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero
  ) -> Double {
    (self / step).rounded(rule) * step
  }
}
