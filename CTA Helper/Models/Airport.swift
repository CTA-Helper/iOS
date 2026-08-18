import CoreLocation
import Foundation
import SwiftData

/**
 An airport with coded approach procedures, and the datum every correction subtracts: its
 elevation.

 The ``siteNumber`` is the primary key. None of an airport's codes can be: the FAA reassigns
 them, and did so as recently as cycle 2607, when Palm Beach became `DJT`/`KDJT`. Anything
 that has to outlive a cycle — a favorite, a recently opened airport — is pinned to the site
 number, which the FAA does not move.
 */
@Model
final class Airport {
  // Each identifier is unique across every US landing facility, and the codes are checked
  // where they appear — SwiftData holds a constraint against the value, so the airports with
  // no ICAO code do not collide with one another.
  #Unique<Airport>([\.siteNumber], [\.faaIdentifier], [\.icaoIdentifier])

  /**
   The FAA landing facility site number and type code, e.g. `"03555.A"` — or `"00218.12A"`,
   carrying the sequence the FAA assigns when it inserts a facility rather than renumbering
   its neighbours. About a third of them do.

   The sequence is part of the key, not noise to be normalized away: `00218.7A` and
   `00218.12A` are different airports that collide the moment it is dropped. Match the whole
   string; never parse it into parts.
   */
  var siteNumber: String
  /// The FAA location identifier, e.g. `"MSO"`. Every airport in the database has one.
  var faaIdentifier: String
  /// The ICAO code, e.g. `"KMSO"` — `nil` for the quarter of airports that have none.
  var icaoIdentifier: String?
  var name: String
  var city: String?
  var state: String?
  var stateName: String?
  /// Airport elevation, in feet MSL.
  var elevationFt: Int
  var latitude: Double
  var longitude: Double
  var coldTemperature: ColdTemperatureRestriction?

  @Relationship(deleteRule: .cascade, inverse: \Approach.airport)
  var approaches: [Approach] = []

  init(
    siteNumber: String,
    faaIdentifier: String,
    icaoIdentifier: String?,
    name: String,
    city: String?,
    state: String?,
    stateName: String?,
    elevationFt: Int,
    latitude: Double,
    longitude: Double,
    coldTemperature: ColdTemperatureRestriction?
  ) {
    self.siteNumber = siteNumber
    self.faaIdentifier = faaIdentifier
    self.icaoIdentifier = icaoIdentifier
    self.name = name
    self.city = city
    self.state = state
    self.stateName = stateName
    self.elevationFt = elevationFt
    self.latitude = latitude
    self.longitude = longitude
    self.coldTemperature = coldTemperature
  }
}

extension Airport {
  /// The elevation every correction measures its reference height above.
  var elevation: Measurement<UnitLength> { .feet(elevationFt) }

  /**
   The identifier a pilot recognizes: the ICAO code where there is one, else the FAA
   location identifier — `"KMSO"`, but `"05U"`.
   */
  var displayIdentifier: String { icaoIdentifier ?? faaIdentifier }

  /**
   The station ID this airport's METARs are filed under.

   US observations use a four-character station ID: the ICAO code where the airport has one,
   and otherwise `K` prefixed to the FAA location identifier — Eureka files as `K05U`. Around
   250 airports with no ICAO code report that way, so falling back to the prefixed form is
   what finds them. Whether the station is actually reporting is the cache's answer, not this
   one's: ``METARLoader/observation(for:)`` returns `nil` for an ID it does not hold.
   */
  var metarStationID: String { icaoIdentifier ?? "K" + faaIdentifier }

  /// The airport's location, for distance and nearest queries.
  var location: CLLocation { CLLocation(latitude: latitude, longitude: longitude) }
}
