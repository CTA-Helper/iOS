import CoreLocation
import SwiftUI
import os

/// Streams device location updates, behind a protocol so previews and tests can inject a mock.
@MainActor
protocol LocationStreamer: Sendable {
  /// Whether this app may use location, and whether the pilot has been asked yet.
  var authorizationStatus: CLAuthorizationStatus { get }
  /// The most recent location, or `nil` if unavailable.
  var location: CLLocation? { get }
  /// Any error from location updates.
  var error: Error? { get }

  /// Start receiving location updates.
  func start() async
  /// Stop receiving location updates.
  func stop() async
  /// An async stream of location updates.
  func locationUpdates() -> AsyncStream<CLLocation>
}

/**
 A Core Location implementation of ``LocationStreamer``.

 It requests "when in use" authorization, reference-counts `start()`/`stop()` so several
 callers can share it, and republishes updates as an `AsyncStream`.
 */
@MainActor
@Observable
final class CoreLocationStreamer: NSObject, LocationStreamer {
  private static let logger = Logger(subsystem: "codes.tim.CTA-Helper", category: "Location")

  private(set) var location: CLLocation?
  private(set) var error: Error?

  var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }

  private let manager = CLLocationManager()
  private var updateTask: Task<Void, Never>?
  private var listenerCount = 0
  private var continuations = [UUID: AsyncStream<CLLocation>.Continuation]()

  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyBest
    manager.requestWhenInUseAuthorization()
  }

  func start() {
    listenerCount += 1
    if listenerCount == 1 { beginUpdates() }
  }

  func stop() {
    listenerCount -= 1
    if listenerCount == 0 { endUpdates() }
  }

  func locationUpdates() -> AsyncStream<CLLocation> {
    AsyncStream { continuation in
      let id = UUID()
      Task { @MainActor in
        continuations[id] = continuation
        if let location { continuation.yield(location) }
        if listenerCount == 0 { start() }
        continuation.onTermination = { _ in
          Task { @MainActor in self.removeContinuation(id) }
        }
      }
    }
  }

  private func beginUpdates() {
    guard updateTask == nil else { return }
    switch manager.authorizationStatus {
      case .denied, .restricted:
        error = LocationError.permissionDenied
        return
      case .notDetermined:
        return
      default:
        break
    }
    updateTask = Task { await streamUpdates() }
  }

  private func streamUpdates() async {
    do {
      for try await update in CLLocationUpdate.liveUpdates(.airborne) where !Task.isCancelled {
        guard let newLocation = update.location else { continue }
        location = newLocation
        error = nil
        for continuation in continuations.values { continuation.yield(newLocation) }
      }
    } catch {
      Self.logger.error("Location streaming failed: \(error)")
      self.error = error
    }
  }

  private func endUpdates() {
    updateTask?.cancel()
    updateTask = nil
    for continuation in continuations.values { continuation.finish() }
    continuations.removeAll()
  }

  private func removeContinuation(_ id: UUID) {
    continuations.removeValue(forKey: id)
    if continuations.isEmpty && listenerCount == 0 { endUpdates() }
  }

  private func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
    switch status {
      case .authorizedWhenInUse, .authorizedAlways:
        if listenerCount > 0 && updateTask == nil { beginUpdates() }
      case .denied, .restricted:
        error = LocationError.permissionDenied
        endUpdates()
      default:
        break
    }
  }
}

extension CoreLocationStreamer: CLLocationManagerDelegate {
  nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    let status = manager.authorizationStatus
    Task { @MainActor in handleAuthorizationChange(status) }
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
