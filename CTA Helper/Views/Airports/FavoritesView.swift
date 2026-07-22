import SwiftData
import SwiftUI

/// The pilot's favorited airports, alphabetical.
struct FavoritesView: View {
  @Binding var selection: Airport?

  @AppStorage(SettingsKey.favoriteAirports)
  private var favorites = AirportIDList()

  var body: some View {
    FavoritesList(ids: favorites.ids, selection: $selection)
  }
}

private struct FavoritesList: View {
  @Query private var airports: [Airport]

  @Binding var selection: Airport?

  var body: some View {
    AirportList(
      airports: sortedByIdentifier,
      emptyMessage: "Airports you favorite appear here.",
      selection: $selection
    )
  }

  /// Alphabetical by the identifier each row shows, which no stored property holds.
  private var sortedByIdentifier: [Airport] {
    airports.sorted { $0.displayIdentifier < $1.displayIdentifier }
  }

  init(ids: [String], selection: Binding<Airport?>) {
    _airports = Query(filter: #Predicate { ids.contains($0.siteNumber) })
    _selection = selection
  }
}

#if DEBUG
  #Preview("Empty") {
    @Previewable @State var selection: Airport?
    NavigationStack {
      FavoritesView(selection: $selection)
    }
    .modelContainer(.preview)
  }
#endif

// Previews the list directly rather than ``FavoritesView``: the ids come from `@AppStorage`, which
// a preview starts empty, so the view itself can only ever show the empty state. The ids arrive
// reverse-alphabetical to show the rows coming back sorted by identifier — KMSO above KSFO.
#if DEBUG
  #Preview("Populated") {
    @Previewable @State var selection: Airport?
    NavigationStack {
      FavoritesList(ids: ["02187.A", "12453.A"], selection: $selection)
    }
    .modelContainer(.preview)
  }
#endif
