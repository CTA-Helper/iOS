import Foundation
import Observation
import SwiftData

/**
 A screen named from outside the view hierarchy: an App Intent today, a deep link or a restored
 session later.

 The airport is named by site number and the approach by its ARINC 424 identifier, for the reason
 ``AirportIDList`` is keyed the same way: a route saved against `KPBI` would have gone dangling
 the day Palm Beach became `KDJT`.
 */
struct AirportRoute: Equatable, Sendable {
  /// The FAA landing facility site number of the airport to show.
  let airportSiteNumber: String
  /// The ARINC 424 identifier of the approach to show, or `nil` to stop at the approach list.
  let approachIdentifier: String?
}

extension AirportRoute {
  /**
   The airport this route names and the approach under it, as the store holds them.

   - Parameter context: the context to read.
   - Returns: the airport and its approach, or `nil` when the store holds no such airport.
   - Throws: whatever the fetch throws.
   */
  func resolve(in context: ModelContext) throws -> (airport: Airport, approach: Approach?)? {
    guard let airport = try airport(in: context) else { return nil }
    return (airport, approach(at: airport))
  }

  private func airport(in context: ModelContext) throws -> Airport? {
    let siteNumber = airportSiteNumber
    var descriptor = FetchDescriptor<Airport>(
      predicate: #Predicate { $0.siteNumber == siteNumber }
    )
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
  }

  private func approach(at airport: Airport) -> Approach? {
    guard let approachIdentifier else { return nil }
    return airport.approaches.first { $0.identifier == approachIdentifier }
  }
}

/**
 The airport → approach selection both layouts push off, and the one address a screen has from
 outside the view hierarchy.

 Choosing an airport clears the approach chosen under the previous one and records the airport as
 recently viewed. That belongs to the property rather than to an `onChange` in the view, because
 ``show(_:at:)`` sets both selections at once: an observer of the airport would fire after both
 were set and clear the very approach the route had just named.
 */
@Observable
@MainActor
final class AirportRouter {
  /// The chosen airport, which is both what the picker marks and what the leading pane pushes.
  var airport: Airport? {
    didSet {
      guard airport != oldValue else { return }
      approach = nil
      if let airport { recordRecent(airport) }
    }
  }

  /// The chosen approach at ``airport``, whose fixes the trailing pane corrects.
  var approach: Approach?

  /// A route waiting for a populated store to resolve it against, or `nil` when there is none.
  private(set) var pendingRoute: AirportRoute?

  private let defaults: UserDefaults

  /// - Parameter defaults: where the recently opened airports are kept.
  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  /// Show an approach at an airport, leaving standing the approach it names.
  func show(_ approach: Approach?, at airport: Airport) {
    self.airport = airport
    self.approach = approach
  }

  /**
   Hold a route until a view can resolve it.

   A route can arrive before the first AIRAC cycle has been imported, and resolving it then would
   land on an empty store. `AirportSplitView` is drawn only once the store holds data, so
   holding the route until it appears is all the gating this needs.
   */
  func route(to route: AirportRoute) {
    pendingRoute = route
  }

  /// Forget the held route, once it has been applied or found unresolvable.
  func clearPendingRoute() {
    pendingRoute = nil
  }

  private func recordRecent(_ airport: Airport) {
    let recents = defaults.airportIDList(forKey: SettingsKey.recentAirports)
    defaults.set(recents.appendingRecent(airport.siteNumber), forKey: SettingsKey.recentAirports)
  }
}
