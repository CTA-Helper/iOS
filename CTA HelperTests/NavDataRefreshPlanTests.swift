import Foundation
import Testing

@testable import CTA_Helper

/**
 The background refresh spends a pilot's data and replaces their dataset unattended, so when it
 may run is the decision worth pinning down: never before the pilot has chosen to load anything,
 straight away once what they have is out of date, and otherwise not until it lapses.
 */
struct `Nav data refresh plan` {
  private static let expiry = Date(timeIntervalSinceReferenceDate: 800_000_000)

  private static func state(
    noData: Bool = false,
    needsLoad: Bool = false,
    cycleExpires: Date? = expiry
  ) -> NavDataState {
    .init(noData: noData, needsLoad: needsLoad, canSkip: !noData, cycleExpires: cycleExpires)
  }

  @Test
  func `leaves the first load to the pilot`() {
    #expect(NavDataRefreshPlan(Self.state(noData: true, needsLoad: true)) == .none)
  }

  @Test
  func `waits for a current cycle to expire`() {
    #expect(NavDataRefreshPlan(Self.state()) == .at(Self.expiry))
  }

  @Test
  func `refreshes a lapsed dataset straight away`() {
    #expect(NavDataRefreshPlan(Self.state(needsLoad: true)) == .now)
  }

  @Test
  func `refreshes a dataset with no cycle straight away`() {
    #expect(NavDataRefreshPlan(Self.state(needsLoad: true, cycleExpires: nil)) == .now)
  }
}
