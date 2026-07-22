import SwiftData
import SwiftUI

/// The most recently opened airports, newest first.
struct RecentsView: View {
  @Binding var selection: Airport?

  @AppStorage(SettingsKey.recentAirports)
  private var recents = AirportIDList()

  var body: some View {
    RecentsList(ids: recents.ids, selection: $selection)
  }
}

private struct RecentsList: View {
  @Query private var airports: [Airport]

  @Binding var selection: Airport?

  private let order: [String]

  var body: some View {
    AirportList(
      airports: sortedByRecency,
      emptyMessage: "Airports you open appear here.",
      selection: $selection
    )
  }

  /// Newest first: the stored list appends the most recent last.
  private var sortedByRecency: [Airport] {
    airports.sorted { first, second in
      (order.firstIndex(of: first.siteNumber) ?? -1)
        > (order.firstIndex(of: second.siteNumber) ?? -1)
    }
  }

  init(ids: [String], selection: Binding<Airport?>) {
    _airports = Query(filter: #Predicate { ids.contains($0.siteNumber) })
    order = ids
    _selection = selection
  }
}

#if DEBUG
  #Preview("Empty") {
    @Previewable @State var selection: Airport?
    NavigationStack {
      RecentsView(selection: $selection)
    }
    .modelContainer(.preview)
  }
#endif

// Previews the list directly rather than ``RecentsView``: the ids come from `@AppStorage`, which a
// preview starts empty, so the view itself can only ever show the empty state. KMSO is passed
// first — the older visit — so the rows render in the opposite order, KSFO above KMSO, which is
// the recency sort the list exists to do.
#if DEBUG
  #Preview("Populated") {
    @Previewable @State var selection: Airport?
    NavigationStack {
      RecentsList(ids: ["12453.A", "02187.A"], selection: $selection)
    }
    .modelContainer(.preview)
  }
#endif
