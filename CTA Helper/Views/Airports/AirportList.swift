import SwiftData
import SwiftUI

/**
 A selectable list of airports, or an empty-state message. Shared by the Favorites, Recents,
 Nearest and Search tabs.

 It is also where weather is resolved for a row's Cold Temperature Airport badge. All four tabs
 render through here, so one throttled call serves every one of them, and a row never fetches on
 its own behalf.
 */
struct AirportList: View {
  let airports: [Airport]
  let emptyMessage: LocalizedStringKey

  @Binding var selection: Airport?

  /// The latest observation per station, once resolved. Empty until then, and offline.
  @State private var observations: [String: METARObservation] = [:]

  @Environment(\.metarLoader)
  private var metarLoader
  @Environment(\.networkMonitor)
  private var networkMonitor

  var body: some View {
    if airports.isEmpty {
      ContentUnavailableView {
        Label("No Airports", systemImage: "circle.slash")
      } description: {
        Text(emptyMessage)
      }
    } else {
      List(selection: $selection) {
        ForEach(airports) { airport in
          AirportRow(airport: airport, observation: observations[airport.metarStationID])
            .tag(airport)
        }
      }
      .task { await loadObservations() }
    }
  }

  /**
   Fetch the whole observation cache when the network is available, so every badge on screen is
   answered at once.

   Unkeyed, so it runs once per appearance rather than every time the airports change under it: a
   search narrowing to its next result, or a nearest list moving, reads the map it already holds.
   */
  private func loadObservations() async {
    guard let metarLoader, let networkMonitor, networkMonitor.isConnected else { return }
    observations = await metarLoader.allObservations()
  }
}

#if DEBUG
  #Preview("Populated") {
    @Previewable @State var selection: Airport?
    NavigationStack {
      AirportList(
        airports: [PreviewData.missoula(), PreviewData.sanFrancisco()],
        emptyMessage: "No airports.",
        selection: $selection
      )
    }
    .modelContainer(.preview)
  }

  #Preview("Empty") {
    @Previewable @State var selection: Airport?
    NavigationStack {
      AirportList(airports: [], emptyMessage: "No favorite airports yet.", selection: $selection)
    }
    .modelContainer(.preview)
  }
#endif

// Previews the badge states the weather decides, which the seeded store alone cannot show: KMSO
// is reporting well below its restriction, Eureka reports nothing, and KSFO is not a CTA at all.
#if DEBUG
  #Preview("Reporting") {
    @Previewable @State var selection: Airport?
    NavigationStack {
      AirportList(
        airports: [PreviewData.missoula(), PreviewData.eureka(), PreviewData.sanFrancisco()],
        emptyMessage: "No airports.",
        selection: $selection
      )
    }
    .modelContainer(.preview)
    .environment(
      \.metarLoader,
      METARLoader(serving: ["KMSO": .preview, "K05U": .previewWithoutTemperature])
    )
    .environment(\.networkMonitor, NetworkMonitor(reporting: true))
  }

  #Preview("Warmer than the restriction") {
    @Previewable @State var selection: Airport?
    NavigationStack {
      AirportList(
        airports: [PreviewData.missoula()],
        emptyMessage: "No airports.",
        selection: $selection
      )
    }
    .modelContainer(.preview)
    .environment(\.metarLoader, METARLoader(serving: ["KMSO": .previewWarm]))
    .environment(\.networkMonitor, NetworkMonitor(reporting: true))
  }
#endif
