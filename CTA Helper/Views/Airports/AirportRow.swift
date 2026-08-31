import SwiftData
import SwiftUI

/**
 A row in an airport list: identifier, name and place, a Cold Temperature Airport badge when
 applicable, and an optional favorite toggle.
 */
struct AirportRow: View {
  let airport: Airport

  /**
   The station's latest observation, where the list resolved one. Rows do not fetch their own —
   see ``AirportList``, which resolves the whole list from a single call.
   */
  var observation: METARObservation?

  var showsFavoriteButton = true

  var body: some View {
    HStack {
      VStack(alignment: .leading) {
        HStack {
          Text(airport.displayIdentifier)
            .font(.headline)
          if let restriction = airport.coldTemperature {
            ColdTemperatureBadge(
              restriction: restriction,
              reportedTemperature: observation?.temperature
            )
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

#if DEBUG
  #Preview("No observations") {
    List {
      AirportRow(airport: PreviewData.missoula())
      AirportRow(airport: PreviewData.sanFrancisco())
    }
    .modelContainer(.preview)
  }

  #Preview("Cold enough today") {
    List {
      AirportRow(airport: PreviewData.missoula(), observation: .preview)
      AirportRow(airport: PreviewData.sanFrancisco())
    }
    .modelContainer(.preview)
  }
#endif
