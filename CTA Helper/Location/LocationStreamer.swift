import CoreLocation
import SwiftUI
import os

/**
 Whether Core Location is delivering the device's location, and if not, why.

 Core Location reports these conditions as diagnostic flags on every `CLLocationUpdate`, so a
 refusal arrives on the same stream as a fix rather than through a separate authorization
 callback.
 */
enum LocationAvailability: Sendable {
  /// The system is asking for authorization and has not yet received an answer.
  case requestingAuthorization

  /// A location is available.
  case available

  /// This app was denied access to location.
  case authorizationDenied

  /// Location Services is turned off for the whole device.
  case authorizationDeniedGlobally

  /// Authorization is prevented by parental restrictions or device management.
  case authorizationRestricted

  /**
   The device's location can't be determined right now.

   Covers both a location Core Location cannot fix and updates it is withholding because the app
   is not sufficiently in use. Neither is actionable, and the distinction is not one the pilot
   can act on: the Nearest tab is a foreground screen, so the app is in use whenever it shows.
   */
  case locationUnavailable

  /**
   Whether this is a refusal the pilot could lift, in Settings or otherwise.

   Drives the retry that runs when someone grants access and comes back to the app.
   */
  var deniesAuthorization: Bool {
    switch self {
      case .authorizationDenied, .authorizationDeniedGlobally, .authorizationRestricted: true
      case .requestingAuthorization, .available, .locationUnavailable: false
    }
  }

  /**
   Reads the refusal an update reports, or `nil` if Core Location is not refusing.

   `CLLocationUpdate.accuracyLimited` is deliberately not a refusal. It is the one flag that
   arrives with a valid location attached, and this app uses that location only as a sort key for
   a 50 NM airport search — never displayed, never flown. A position coarsened to a kilometre or
   two still names the same nearest fields.

   - Parameter update: the update whose diagnostic flags to interpret.
   */
  init?(refusing update: CLLocationUpdate) {
    if update.authorizationRequestInProgress {
      self = .requestingAuthorization
    } else if update.authorizationDeniedGlobally {
      self = .authorizationDeniedGlobally
    } else if update.authorizationDenied {
      self = .authorizationDenied
    } else if update.authorizationRestricted {
      self = .authorizationRestricted
    } else if update.locationUnavailable || update.insufficientlyInUse {
      self = .locationUnavailable
    } else {
      return nil
    }
  }
}

/**
 Streams device location updates, behind a protocol so previews and tests can inject a mock.

 Conformers are reference types so SwiftUI observes their state in place; a value type would be
 copied into the existential and its changes never seen.
 */
@MainActor
protocol LocationStreamer: AnyObject, Observable, Sendable {
  /// The most recent location, or `nil` if unavailable.
  var location: CLLocation? { get }
  /// Any error from location updates.
  var error: Error? { get }
  /// Whether a location is available, and if not why — or `nil` before the first update arrives.
  var availability: LocationAvailability? { get }

  /// Start receiving location updates.
  func start() async
  /// Stop receiving location updates.
  func stop() async
  /// Ask Core Location again after a refusal, without disturbing existing subscribers.
  func retry() async
  /// An async stream of location updates.
  func locationUpdates() -> AsyncStream<CLLocation>
}

/**
 A Core Location implementation of ``LocationStreamer``.

 It reference-counts `start()`/`stop()` so several callers can share it, republishes updates as
 an `AsyncStream`, and reads its authorization state off the update stream's own diagnostics.

 ## Authorization

 Core Location requests authorization when iteration over the update stream begins, and reports
 the outcome — a request still in flight, a denial, a device-wide switch-off — as flags on the
 updates themselves. So this type asks for nothing up front and polls nothing; it reads
 ``availability`` off the stream.

 ## Reference counting

 Every caller of ``start()`` counts as one listener, and so does every subscriber to
 ``locationUpdates()``. Updates only stop once each has balanced its start with a ``stop()`` and
 every subscription has ended.
 */
@MainActor
@Observable
final class CoreLocationStreamer: LocationStreamer {
  private static let logger = Logger(subsystem: "codes.tim.CTA-Helper", category: "Location")

  private(set) var location: CLLocation?
  private(set) var error: Error?
  private(set) var availability: LocationAvailability?

  private var updateTask: Task<Void, Never>?
  private var listenerCount = 0
  private var continuations = [UUID: AsyncStream<CLLocation>.Continuation]()

  /// Identifies the current stream, so a finishing one cannot disown its replacement.
  private var streamGeneration = 0

  func start() {
    listenerCount += 1
    if listenerCount == 1 { beginUpdates() }
  }

  func stop() {
    // A release can arrive before its acquire: a view that appears and disappears within one
    // runloop turn has its `task` cancelled before it ever starts. Counting that release would
    // leave the tally below zero, where `start()` can never bring it back to one — and the
    // stream would never run again for the life of the process.
    guard listenerCount > 0 else { return }
    listenerCount -= 1
    if listenerCount == 0 { endUpdates() }
  }

  /**
   Restarts the update stream after a refusal.

   Someone who grants access in Settings and comes back gets their list without leaving the
   screen. Subscribers are left connected, so this is not a ``stop()`` followed by a ``start()``.
   */
  func retry() {
    guard listenerCount > 0 else { return }
    updateTask?.cancel()
    updateTask = nil
    availability = nil
    beginUpdates()
  }

  func locationUpdates() -> AsyncStream<CLLocation> {
    AsyncStream { continuation in
      let id = UUID()
      Task { @MainActor in
        continuations[id] = continuation
        if let location { continuation.yield(location) }
        start()
        continuation.onTermination = { _ in
          Task { @MainActor in
            // `endUpdates()` clears the map before finishing the continuations in it, so a
            // termination it caused must not decrement the count a second time.
            guard self.continuations.removeValue(forKey: id) != nil else { return }
            self.stop()
          }
        }
      }
    }
  }

  private func beginUpdates() {
    guard updateTask == nil else { return }

    streamGeneration += 1
    let generation = streamGeneration

    updateTask = Task {
      // Only clear the handle if this is still the live stream: ``retry()`` may already have
      // replaced it, and nilling it then would strand a running task.
      defer { if generation == streamGeneration { updateTask = nil } }
      do {
        for try await update in CLLocationUpdate.liveUpdates(.airborne) {
          if Task.isCancelled { break }
          apply(update)
        }
      } catch {
        Self.logger.error("Location streaming failed: \(error)")
        self.error = error
      }
    }
  }

  private func endUpdates() {
    updateTask?.cancel()
    updateTask = nil
    availability = nil

    let finishing = continuations.values
    continuations.removeAll()
    for continuation in finishing { continuation.finish() }
  }

  /**
   Publishes what an update carries: a refusal, or a fix.

   The diagnostics are read before the location is, because an update reporting a refusal has no
   location on it. Taking the location first and skipping the updates that have none would
   discard exactly the ones that say why — and a permission revoked mid-flight would leave the
   list frozen on its last fix with nothing on screen to say so.
   */
  private func apply(_ update: CLLocationUpdate) {
    if let refusal = LocationAvailability(refusing: update) {
      availability = refusal
      return
    }

    // No refusal and no fix yet: Core Location is still acquiring one, and the tab waits rather
    // than reading as an airport-free world.
    guard let newLocation = update.location else { return }

    availability = .available
    location = newLocation
    error = nil
    for continuation in continuations.values { continuation.yield(newLocation) }
  }
}

private struct LocationStreamerKey: EnvironmentKey {
  static let defaultValue: any LocationStreamer = MainActor.assumeIsolated {
    CoreLocationStreamer()
  }
}

extension EnvironmentValues {
  var locationStreamer: any LocationStreamer {
    get { self[LocationStreamerKey.self] }
    set { self[LocationStreamerKey.self] = newValue }
  }
}
