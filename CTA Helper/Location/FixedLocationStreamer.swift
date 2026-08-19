import CoreLocation
import Observation

/**
 A ``LocationStreamer`` that reports an authorization and a position decided up front, for
 previews and UI tests.

 Neither has a location of its own, and neither can answer the system permission alert that
 asking for one raises — so the Nearest tab would show whichever state the host machine
 happened to be in. This reports the one it was built with instead, and streams its single
 position once.
 */
@MainActor
@Observable
final class FixedLocationStreamer: LocationStreamer {
  let authorizationStatus: CLAuthorizationStatus
  let location: CLLocation?
  let error: Error? = nil

  /**
   Creates a streamer reporting a fixed authorization and position.

   - Parameters:
     - authorizationStatus: what the Nearest tab is told about this app's location permission.
     - location: the position to stream, or `nil` to report none — as an authorization short of
       `CLAuthorizationStatus.authorizedWhenInUse` always would.
   */
  init(authorizationStatus: CLAuthorizationStatus, location: CLLocation? = nil) {
    self.authorizationStatus = authorizationStatus
    self.location = location
  }

  func start() {}

  func stop() {}

  func locationUpdates() -> AsyncStream<CLLocation> {
    AsyncStream { continuation in
      if let location { continuation.yield(location) }
      continuation.finish()
    }
  }
}
