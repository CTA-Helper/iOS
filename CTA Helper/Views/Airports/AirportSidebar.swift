import CoreLocation
import SwiftData
import SwiftUI

/**
 The airport picker in the split view's leading column: a Favorites / Recents / Nearest /
 Search segmented control over the matching list.
 */
struct AirportSidebar: View {
  @Binding var selection: Airport?

  @State private var tab: AirportTab = .favorites
  @State private var showsNearest = false
  @State private var showsSettings = false

  var body: some View {
    VStack(spacing: 0) {
      Picker("Airports", selection: $tab) {
        ForEach(AirportTab.allCases) { tab in
          if tab != .nearest || showsNearest {
            Text(tab.label)
              .tag(tab)
              .accessibilityIdentifier("airportTab-\(tab.rawValue)")
          }
        }
      }
      .pickerStyle(.segmented)
      .padding([.horizontal, .bottom])
      .accessibilityIdentifier("airportTabPicker")

      SelectedAirportTab(tab: tab, selection: $selection)
    }
    .navigationTitle("Airports")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          showsSettings = true
        } label: {
          Label("Settings", systemImage: "gearshape")
        }
        .accessibilityIdentifier("settingsButton")
      }
    }
    .sheet(isPresented: $showsSettings) {
      SettingsView()
    }
    // Resolved here rather than through the environment's streamer, which the pilot has not yet
    // asked for: reading it would build a `CLLocationManager` and raise the permission alert
    // before they have opened the tab that needs one.
    .task {
      // `locationServicesEnabled()` blocks, so resolve availability off the main actor.
      showsNearest = await Task.detached {
        CLLocationManager.locationServicesEnabled()
      }.value
    }
  }
}

/**
 The airport list the picker's current tab names.

 Each tab sources its airports differently — a favorites list, a recents list, a location
 stream, a search query — but all four pick into the same binding, so the sidebar hands the
 selection straight through and only the tab decides which list is on screen.
 */
private struct SelectedAirportTab: View {
  let tab: AirportTab

  @Binding var selection: Airport?

  var body: some View {
    switch tab {
      case .favorites: FavoritesView(selection: $selection)
      case .recents: RecentsView(selection: $selection)
      case .nearest: NearestView(selection: $selection)
      case .search: SearchView(selection: $selection)
    }
  }
}

/// The airport picker's tabs.
enum AirportTab: String, CaseIterable, Identifiable {
  case favorites, recents, nearest, search

  var id: Self { self }

  var label: String {
    switch self {
      case .favorites: String(localized: "Favorites")
      case .recents: String(localized: "Recents")
      case .nearest: String(localized: "Nearest")
      case .search: String(localized: "Search")
    }
  }
}

#if DEBUG
  #Preview {
    @Previewable @State var selection: Airport?
    NavigationStack {
      AirportSidebar(selection: $selection)
    }
    .modelContainer(.preview)
  }
#endif
