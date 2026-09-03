import CoreLocation
import Observation
import SwiftData
import os

/// Nautical miles per degree of latitude (1° = 60 NM).
private let nauticalMilesPerDegree = 60.0
/// A floor on cos(latitude) to avoid divide-by-zero near the poles.
private let minimumCosineLatitude = 0.000_01
/// The most nearest airports returned.
private let maximumNearestResults = 10

/**
 Finds the airports nearest the device, sorted by distance.

 It subscribes to ``LocationStreamer`` and, on each new position, fetches airport identifiers
 within a bounding box on a background context, then resolves them on the main context — so
 no `@Model` object crosses an actor boundary.
 */
@Observable
@MainActor
final class NearestAirportViewModel {
  private static let searchRadius = Measurement<UnitLength>(value: 50, unit: .nauticalMiles)

  private static let logger = Logger(subsystem: "codes.tim.CTA-Helper", category: "NearestAirport")

  private(set) var airports: [Airport] = []
  private(set) var error: Error?

  private let container: ModelContainer
  private let streamer: any LocationStreamer
  private var updateTask: Task<Void, Never>?
  private var fetchTask: Task<Void, Never>?

  private var location: CLLocation? {
    didSet { updateAirports() }
  }

  init(container: ModelContainer, locationStreamer: any LocationStreamer) {
    self.container = container
    self.streamer = locationStreamer
    updateTask = Task { [weak self] in
      guard let self else { return }
      // Subscribing is itself a listener, so the streamer needs no separate start.
      location = streamer.location
      error = streamer.error
      for await newLocation in streamer.locationUpdates() {
        if Task.isCancelled { break }
        location = newLocation
        error = nil
      }
    }
  }

  /**
   Ends the location subscription and any airport fetch still running. Call from the view's
   `onDisappear`.

   Releasing the view model is not enough: the update task holds the subscription open, and that
   is what keeps the streamer — and the GPS — running.
   */
  func cancel() {
    updateTask?.cancel()
    updateTask = nil
    fetchTask?.cancel()
    fetchTask = nil
  }

  private func updateAirports() {
    guard let location else {
      airports = []
      return
    }
    let box = BoundingBox(
      around: location.coordinate,
      radiusNM: Self.searchRadius.converted(to: .nauticalMiles).value
    )

    fetchTask?.cancel()
    fetchTask = Task { [weak self] in
      guard let self else { return }
      do {
        let ids = try await nearbyIDs(from: location, in: box)
        guard !Task.isCancelled else { return }
        let context = container.mainContext
        airports = ids.compactMap { context.model(for: $0) as? Airport }
      } catch {
        guard !Task.isCancelled else { return }
        Self.logger.error("Nearest airport fetch failed: \(error)")
        self.error = error
      }
    }
  }

  @concurrent
  private func nearbyIDs(from location: CLLocation, in box: BoundingBox) async throws
    -> [PersistentIdentifier]
  {
    let context = ModelContext(container)
    let (minimumLatitude, maximumLatitude, minimumLongitude, maximumLongitude, wrapsAntimeridian) =
      (
        box.minLatitude, box.maxLatitude, box.minLongitude, box.maxLongitude,
        box.wrapsAntimeridian
      )
    let predicate =
      wrapsAntimeridian
      ? #Predicate<Airport> {
        $0.latitude >= minimumLatitude && $0.latitude <= maximumLatitude
          && ($0.longitude >= minimumLongitude || $0.longitude <= maximumLongitude)
      }
      : #Predicate<Airport> {
        $0.latitude >= minimumLatitude && $0.latitude <= maximumLatitude
          && $0.longitude >= minimumLongitude && $0.longitude <= maximumLongitude
      }

    return try context.fetch(FetchDescriptor(predicate: predicate))
      .map { ($0.persistentModelID, location.distance(from: $0.location)) }
      .sorted { $0.1 < $1.1 }
      .prefix(maximumNearestResults)
      .map(\.0)
  }
}

/// A latitude/longitude bounding box around a point, for a coarse nearest-airport prefilter.
private struct BoundingBox {
  let minLatitude, maxLatitude, minLongitude, maxLongitude: Double
  let wrapsAntimeridian: Bool

  init(around center: CLLocationCoordinate2D, radiusNM: Double) {
    let latitudeDelta = radiusNM / nauticalMilesPerDegree
    minLatitude = max(-90, center.latitude - latitudeDelta)
    maxLatitude = min(90, center.latitude + latitudeDelta)

    let cosineLatitude = max(cos(center.latitude * .pi / 180), minimumCosineLatitude)
    let longitudeDelta = radiusNM / (nauticalMilesPerDegree * cosineLatitude)
    var westernLongitude = center.longitude - longitudeDelta
    var easternLongitude = center.longitude + longitudeDelta
    if westernLongitude < -180 { westernLongitude += 360 }
    if easternLongitude > 180 { easternLongitude -= 360 }
    minLongitude = westernLongitude
    maxLongitude = easternLongitude
    wrapsAntimeridian = westernLongitude >= easternLongitude
  }
}
