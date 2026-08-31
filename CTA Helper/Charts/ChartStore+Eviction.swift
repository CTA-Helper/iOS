import Foundation

/**
 The eviction arithmetic, kept apart from the filesystem that feeds it.

 Which plates go is the one piece of policy in ``ChartStore`` worth pinning down, and over plain
 values it can be pinned down without writing a single file.
 */
extension ChartStore {
  /**
   Which plates to evict so that `incoming` more bytes fit inside `budget`.

   - Parameters:
     - entries: every cached plate.
     - incoming: how many bytes are about to be written.
     - budget: how many bytes the store may occupy.
   - Returns: the plates to remove, least recently opened first, and no more of them than it
     takes to fit. Empty when what is coming already fits.
   */
  static func evictions(
    from entries: [CacheEntry],
    toFit incoming: UInt64,
    budget: UInt64
  ) -> [CacheEntry] {
    var occupied = entries.reduce(UInt64(0)) { $0 + $1.bytes }
    guard occupied + incoming > budget else { return [] }

    var evictions: [CacheEntry] = []
    for entry in entries.sorted(by: { $0.lastOpened < $1.lastOpened }) {
      evictions.append(entry)
      occupied -= min(occupied, entry.bytes)
      if occupied + incoming <= budget { break }
    }
    return evictions
  }

  /// One cached plate, as eviction sees it.
  struct CacheEntry: Equatable, Sendable {
    /// Where the plate is filed.
    let url: URL
    /// How much disk it occupies.
    let bytes: UInt64
    /// When it was last opened, which is the order plates are evicted in.
    let lastOpened: Date
  }
}
