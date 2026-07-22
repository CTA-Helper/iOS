import SwiftData
import SwiftUI

/**
 A row in an airport list: identifier, name and place, a Cold Temperature Airport badge when
 applicable, and an optional favorite toggle.
 */
struct AirportRow: View {
  let airport: Airport
  var showsFavoriteButton = true

  var body: some View {
    HStack {
      VStack(alignment: .leading) {
        HStack {
          Text(airport.displayIdentifier)
            .font(.headline)
          if let restriction = airport.coldTemperature {
            ColdTemperatureBadge(restriction: restriction)
          }
        }
        Text(airport.name.capitalized)
          .font(.subheadline)
      }
      // Identified here rather than on the row: an identifier carries down the whole subtree it
      // is set on, and a row-wide one would rename the star along with everything else.
      .accessibilityIdentifier("airportRow-\(airport.displayIdentifier)")

      Spacer()

      if showsFavoriteButton {
        FavoriteButton(siteNumber: airport.siteNumber)
          .accessibilityIdentifier("favoriteButton-\(airport.displayIdentifier)")
      }
    }
    .contentShape(.rect)
  }
}

/**
 The star that favorites an airport, holding the favorites list itself so that only the star
 redraws when the pilot taps it — a row's identifier, name and badge do not depend on the
 list, and a list of them has no reason to re-render because one airport changed.
 */
private struct FavoriteButton: View {
  /// The airport this star favorites, by the site number the favorites list stores.
  let siteNumber: String

  @AppStorage(SettingsKey.favoriteAirports)
  private var favorites = AirportIDList()

  private var isFavorite: Bool { favorites.contains(siteNumber) }

  var body: some View {
    Button {
      favorites = favorites.toggling(siteNumber)
    } label: {
      Image(systemName: isFavorite ? "star.fill" : "star")
        .foregroundStyle(isFavorite ? .yellow : .secondary)
    }
    .buttonStyle(.borderless)
    .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
  }
}

/// The snowflake and restriction temperature shown for a Cold Temperature Airport.
struct ColdTemperatureBadge: View {
  let restriction: ColdTemperatureRestriction

  @ScaledMetric(relativeTo: .body)
  private var size = 14.0

  var body: some View {
    Label {
      Text(
        restriction.restrictionTemperature,
        format: .measurement(width: .narrow, usage: .asProvided)
      )
    } icon: {
      Image(systemName: "snowflake")
    }
    .labelStyle(.narrow)
    .font(.system(size: size))
    .foregroundStyle(.blue)
    .accessibilityLabel(
      "Cold temperature airport, \(restriction.restrictionTemperature, format: .measurement(width: .wide, usage: .asProvided))"
    )
  }
}

#if DEBUG
  #Preview {
    List {
      AirportRow(airport: PreviewData.missoula())
      AirportRow(airport: PreviewData.sanFrancisco())
    }
    .modelContainer(.preview)
  }
#endif
