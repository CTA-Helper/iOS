import Foundation

/**
 The AIRAC calendar: back-to-back 28-day cycles, each named here for the UTC date it takes effect.

 Only this build's reckoning of which cycle is current — the published manifests are what say
 when a cycle is actually in force. It is used to know which manifests to ask for.
 */
enum AIRACCalendar {
  /// When AIRAC cycle 2001 took effect: 2 January 2020, 00:00 UTC.
  private static let epoch = Date(timeIntervalSince1970: 1_577_923_200)

  /// How long each cycle is in force, in seconds.
  static let cycleLength: TimeInterval = 28 * 24 * 60 * 60

  /**
   When the cycle in force at `date` took effect, followed by each cycle before it.

   - Parameters:
     - date: The moment to find the cycle in force at.
     - count: How many cycles to list, the current one included.
   - Returns: Effective dates, newest first.
   */
  static func effectiveDates(at date: Date, count: Int) -> [Date] {
    let current = (date.timeIntervalSince(epoch) / cycleLength).rounded(.down)
    return (0..<count).map { offset in
      epoch.addingTimeInterval((current - Double(offset)) * cycleLength)
    }
  }
}
