import SwiftData
import SwiftUI

/**
 A selectable list of airports, or an empty-state message. Shared by the Favorites, Recents,
 Nearest and Search tabs.
 */
struct AirportList: View {
  let airports: [Airport]
  let emptyMessage: LocalizedStringKey

  @Binding var selection: Airport?

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
          AirportRow(airport: airport)
            .tag(airport)
        }
      }
    }
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
