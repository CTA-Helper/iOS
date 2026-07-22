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

  private let monitor = NWPathMonitor()

  private let queue = DispatchQueue(label: "codes.tim.CTA-Helper.NetworkMonitor")

  /// Starts monitoring network reachability immediately.
  init() {
    monitor.pathUpdateHandler = { [weak self] path in
      let connected = path.status == .satisfied
      Task { @MainActor in self?.isConnected = connected }
    }
    monitor.start(queue: queue)
  }

  /**
   Creates a monitor that reports a fixed reachability and never observes the network, so that
   a test served seeded weather does not depend on the host's own connectivity.

   - Parameter isConnected: the reachability to report.
   */
  init(reporting isConnected: Bool) {
    self.isConnected = isConnected
  }

  deinit {
    monitor.cancel()
  }
}
