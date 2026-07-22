import Foundation
import Testing

@testable import CTA_Helper

/**
 The 15-minute reload gate is the loader's own logic, so it is pinned directly rather than by
 driving a real download.
 */
struct METARLoaderTests {
  private static let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

  @Test("A forced reload always proceeds")
  func forcedReloadProceeds() {
    #expect(METARLoader.shouldReload(force: true, lastLoad: Self.now, now: Self.now))
  }

  @Test("The first reload proceeds when nothing has loaded yet")
  func firstReloadProceeds() {
    #expect(METARLoader.shouldReload(force: false, lastLoad: nil, now: Self.now))
  }

  @Test("A reload within the interval is skipped")
  func recentReloadSkipped() {
    let lastLoad = Self.now.addingTimeInterval(-14 * 60)
    #expect(!METARLoader.shouldReload(force: false, lastLoad: lastLoad, now: Self.now))
  }

  @Test("A reload past the interval proceeds")
  func staleReloadProceeds() {
    let lastLoad = Self.now.addingTimeInterval(-15 * 60)
    #expect(METARLoader.shouldReload(force: false, lastLoad: lastLoad, now: Self.now))
  }
}
