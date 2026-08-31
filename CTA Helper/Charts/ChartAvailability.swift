import Foundation

/**
 What can be done about an approach's plate, resolved before the pilot taps anything.

 The app is built for the no-network case, so a chart button that looks alike whether or not it
 can open a chart would be a promise it cannot keep. Every state here is decided from what the
 store and the cache already hold — never from a request that has failed — so the button says
 which case it is in before it is pressed.
 */
enum ChartAvailability: Equatable, Sendable {
  /// The nav data publishes no chart for this approach, as it does for 584 of them.
  case unpublished
  /// The plate is on disk and opens with or without a network.
  case cached(URL)
  /// The plate is not cached, and there is a network to fetch it over.
  case downloadable
  /// The plate is not cached and there is no network, so nothing can be done until there is.
  case unavailableOffline
  /// The imported cycle has been superseded, so the URL the plate would be fetched from is dead.
  case supersededCycle

  /**
   Resolves what can be done about a plate.

   - Parameters:
     - id: the plate to fetch, or `nil` where the approach publishes no chart.
     - cachedPlate: where the plate is already filed, or `nil` when it is not.
     - isConnected: whether the device has a usable network path.
     - cycleHasExpired: whether the imported AIRAC cycle has been superseded.

   A cached plate wins over an expired cycle: a pilot who deferred the update at launch is
   flying the stored cycle, and the plate on disk is that cycle's. An expired cycle wins over
   everything else, because offering a download that can only 404 is worse than saying why.
   */
  static func resolve(
    id: ChartID?,
    cachedPlate: URL?,
    isConnected: Bool,
    cycleHasExpired: Bool
  ) -> Self {
    guard id != nil else { return .unpublished }
    if let cachedPlate { return .cached(cachedPlate) }
    if cycleHasExpired { return .supersededCycle }
    return isConnected ? .downloadable : .unavailableOffline
  }
}
