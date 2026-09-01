import AppIntents
import CoreSpotlight
import Foundation

/**
 An airport, as Shortcuts, Spotlight and Siri hold it.

 Keyed by ``Airport/siteNumber`` and never by an identifier: a Shortcut the pilot saves outlives
 the cycle in which Palm Beach became `KDJT`, which is why ``AirportIDList`` is keyed the same
 way.
 */
struct AirportEntity: AppEntity, IndexedEntity {
  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Airport"
  static let defaultQuery = AirportEntityQuery()

  /// The FAA landing facility site number, which the FAA does not reassign.
  let id: String

  @Property(title: "Identifier")
  var identifier: String

  @Property(title: "Name")
  var name: String

  @Property(title: "City", indexingKey: \.city)
  var city: String?

  var displayRepresentation: DisplayRepresentation {
    .init(title: "\(identifier)", subtitle: "\(name)")
  }

  /// The screen this airport names: its approach list.
  var route: AirportRoute {
    .init(airportSiteNumber: id, approachIdentifier: nil)
  }

  init(_ airport: Airport) {
    id = airport.siteNumber
    identifier = airport.displayIdentifier
    name = airport.name
    city = airport.city
  }
}
