import Foundation

@preconcurrency import Network

/**
 Observes network reachability so the UI can decide whether to auto-fill weather data.

 The monitor wraps `NWPathMonitor`, starting in ``init()`` on a background queue and publishing
 reachability changes to ``isConnected`` on the main actor.
 */
@MainActor
@Observable
final class NetworkMonitor {
  /// Whether the device currently has a usable network path.
  private(set) var isConnected = false

  /**
   Whether the current path is one iOS treats as metered or constrained — cellular, a personal
   hotspot, Low Data Mode — where a large download is worth a warning first.
   */
  private(set) var isExpensive = false

  private let monitor = NWPathMonitor()

  private let queue = DispatchQueue(label: "codes.tim.CTA-Helper.NetworkMonitor")

  /// Starts monitoring network reachability immediately.
  init() {
    monitor.pathUpdateHandler = { [weak self] path in
      let connected = path.status == .satisfied,
        expensive = path.isExpensive || path.isConstrained
      Task { @MainActor in
        self?.isConnected = connected
        self?.isExpensive = expensive
      }
    }
    monitor.start(queue: queue)
  }

  /**
   Creates a monitor that reports a fixed reachability and never observes the network, so that
   a test served seeded weather does not depend on the host's own connectivity.

   - Parameters:
     - isConnected: the reachability to report.
     - isExpensive: whether to report the path as metered.
   */
  init(reporting isConnected: Bool, isExpensive: Bool = false) {
    self.isConnected = isConnected
    self.isExpensive = isExpensive
  }

  deinit {
    monitor.cancel()
  }
}
