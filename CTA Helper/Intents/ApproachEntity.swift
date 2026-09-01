import AppIntents
import Foundation

/**
 An approach's identity across cycles: the airport that publishes it, and its ARINC 424 code.

 The two are kept apart rather than joined into one opaque string, so the site number is still
 matched whole — ``Airport/siteNumber`` is never parsed into parts — and so the one place that
 splits the stored form is ``entityIdentifier(for:)``. A split that fails there silently drops a
 Shortcut the pilot saved, which is reason enough for there to be only one of them.
 */
struct ApproachID: Hashable, Sendable, EntityIdentifierConvertible {
  /// The separator, which neither a site number nor an ARINC 424 identifier can contain.
  private static let separator: Character = "/"

  let siteNumber: String
  let approachIdentifier: String

  var entityIdentifierString: String {
    "\(siteNumber)\(Self.separator)\(approachIdentifier)"
  }

  static func entityIdentifier(for entityIdentifierString: String) -> Self? {
    let parts = entityIdentifierString.split(separator: separator, maxSplits: 1)
    guard parts.count == 2 else { return nil }
    return .init(siteNumber: String(parts[0]), approachIdentifier: String(parts[1]))
  }
}

/// An instrument approach, as Shortcuts, Spotlight and Siri hold it.
struct ApproachEntity: AppEntity, IndexedEntity {
  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Approach"
  static let defaultQuery = ApproachEntityQuery()

  let id: ApproachID

  @Property(title: "Approach")
  var name: String

  @Property(title: "Airport")
  var airportIdentifier: String

  var displayRepresentation: DisplayRepresentation {
    .init(title: "\(name)", subtitle: "\(airportIdentifier)")
  }

  /// The screen this approach names: its cold temperature corrected fixes.
  var route: AirportRoute {
    .init(airportSiteNumber: id.siteNumber, approachIdentifier: id.approachIdentifier)
  }

  /// - Returns: `nil` for an approach the store holds without the airport that publishes it.
  init?(_ approach: Approach) {
    guard let airport = approach.airport else { return nil }
    id = .init(siteNumber: airport.siteNumber, approachIdentifier: approach.identifier)
    name = approach.name
    airportIdentifier = airport.displayIdentifier
  }
}
