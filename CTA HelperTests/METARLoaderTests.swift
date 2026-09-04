import Foundation
import Testing

@testable import CTA_Helper

/**
 The 15-minute reload gate is the loader's own logic, so it is pinned directly rather than by
 driving a real download.
 */
struct METARLoaderTests {
  private static let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

  @Test
  func `a forced reload always proceeds`() {
    #expect(METARLoader.shouldReload(force: true, lastLoad: Self.now, now: Self.now))
  }

  @Test
  func `the first reload proceeds when nothing has loaded yet`() {
    #expect(METARLoader.shouldReload(force: false, lastLoad: nil, now: Self.now))
  }

  @Test
  func `a reload within the interval is skipped`() {
    let lastLoad = Self.now.addingTimeInterval(-14 * 60)
    #expect(!METARLoader.shouldReload(force: false, lastLoad: lastLoad, now: Self.now))
  }

  @Test
  func `a reload past the interval proceeds`() {
    let lastLoad = Self.now.addingTimeInterval(-15 * 60)
    #expect(METARLoader.shouldReload(force: false, lastLoad: lastLoad, now: Self.now))
  }
}
