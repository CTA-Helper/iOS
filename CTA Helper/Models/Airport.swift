import CoreLocation
import Foundation
import NavDataSchema

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
