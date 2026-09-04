import CoreLocation
import Observation

/**
 A ``LocationStreamer`` that reports an availability and a position decided up front, for
 previews and UI tests.

 Neither has a location of its own, and neither can answer the system permission alert that
 asking for one raises — so the Nearest tab would show whichever state the host machine happened
 to be in. This reports the one it was built with instead, and streams its single position once.
 */
@MainActor
@Observable
final class FixedLocationStreamer: LocationStreamer {
  var availability: LocationAvailability?

  let location: CLLocation?
  let error: (any Error)? = nil

  /**
   Creates a streamer reporting a fixed availability and position.

   - Parameters:
     - availability: what the Nearest tab is told about this app's access to location.
     - location: the position to stream, or `nil` to report none — as anything short of
       ``LocationAvailability/available`` always would.
   */
  init(availability: LocationAvailability = .available, location: CLLocation? = nil) {
    self.availability = availability
    self.location = location
  }

  func start() {}

  func stop() {}

  /**
   Leaves the reported availability standing.

   The real streamer asks Core Location again, which is worth doing because the answer can have
   changed. This one's answer is the fixture, and a test that asked to see a refusal explained
   would otherwise watch it resolve itself the moment the app came to the foreground.
   */
  func retry() {}

  func locationUpdates() -> AsyncStream<CLLocation> {
    AsyncStream { continuation in
      if let location { continuation.yield(location) }
      continuation.finish()
    }
  }
}
