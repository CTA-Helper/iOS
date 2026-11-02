import AppIntents
import NavDataSchema
import SwiftData
import SwiftUI

/**
 The app root: the loading screen until the store holds data, then the airport → approach →
 fixes split view.
 */
struct ContentView: View {
  @Environment(NavDataLoaderViewModel.self)
  private var loaderViewModel

  @State private var router = AirportRouter()

  var body: some View {
    Group {
      if loaderViewModel.showLoader {
        LoadingView(viewModel: loaderViewModel)
      } else {
        AirportSplitView()
      }
    }
    .environment(router)
    .task { await loaderViewModel.start() }
    .onAppIntentExecution(OpenAirportIntent.self) { router.route(to: $0.target.route) }
    .onAppIntentExecution(OpenApproachIntent.self) { router.route(to: $0.target.route) }
  }
}

/**
 The airport → approach → fixes navigation, in the shape the width allows: two panes side by
 side where there is room for them, and a single drill-down stack on iPhone.

 Both layouts push off the router's selections, so choosing an airport clears the approach chosen
 under the previous one — and records the airport as recently viewed — no matter which of them is
 on screen. What the pilot has set on the fix list is held here too, and so is the display's wake
 lock, since whichever layout is showing is torn down and rebuilt each time the width crosses
 between them. A route the router is holding is applied here, and only here: this view is drawn
 once the store holds data, which is the condition a route has to wait for, and the same
 condition the Spotlight donation waits on.
 */
private struct AirportSplitView: View {
  @Environment(\.horizontalSizeClass)
  private var horizontalSizeClass
  @Environment(\.modelContext)
  private var modelContext
  @Environment(AirportRouter.self)
  private var router

  /**
   What the pilot has set on the fix list, for as long as an approach is open. Leaving it — back
   to the approach list, or to another airport — starts the next one afresh.
   */
  @State private var fixList = FixListViewModel()
  @State private var chartDownloads = ChartDownloads()

  @AppStorage(SettingsKey.favoriteAirports)
  private var favorites = AirportIDList()
  @AppStorage(SettingsKey.recentAirports)
  private var recents = AirportIDList()

  /**
   The airports Spotlight holds, in an order re-opening one of them cannot change.

   A set, and sorted: opening an airport the pilot has opened before moves it to the end of the
   recents without changing what is indexed at all, and a task keyed on the two lists themselves
   would rebuild the whole index on every airport they tap.
   */
  private var indexedAirports: [String] {
    Set(favorites.ids).union(recents.ids).sorted()
  }

  var body: some View {
    Group {
      if horizontalSizeClass == .compact {
        CompactAirportNavigation(router: router, fixList: fixList, chartDownloads: chartDownloads)
      } else {
        AirportPanes(router: router, fixList: fixList, chartDownloads: chartDownloads)
      }
    }
    .keepsScreenAwake(router.approach != nil)
    .alert("Charts Downloaded", item: $chartDownloads.finishedSummary) { _ in
      Button("OK") {}
    } message: { summary in
      Text(AirportChartsButton.message(for: summary))
    }
    .onChange(of: router.approach == nil) { _, isClosed in
      if isClosed { fixList = FixListViewModel() }
    }
    .task(id: router.pendingRoute) { applyPendingRoute() }
    .task(id: indexedAirports) {
      await EntitySpotlightIndex.shared.donate(
        airports: indexedAirports,
        from: modelContext.container
      )
    }
  }

  /// Show the held route's screen, dropping a route the populated store cannot resolve.
  private func applyPendingRoute() {
    guard let route = router.pendingRoute else { return }
    defer { router.clearPendingRoute() }
    guard let resolved = try? route.resolve(in: modelContext) else { return }
    router.show(resolved.approach, at: resolved.airport)
  }
}

/**
 The iPhone layout: one stack the pilot drills airport → approach → fixes down, and pops back
 up.

 The stack is this view's own rather than a collapsed `NavigationSplitView`'s: a column whose
 content is a `NavigationStack` is not a selection the collapse can drive, and a
 `NavigationLink` in a bare column has no stack to push onto — it overwrites the column,
 leaving the selection out of step with what is on screen and every later selection ignored.
 */
private struct CompactAirportNavigation: View {
  @Bindable var router: AirportRouter
  let fixList: FixListViewModel
  let chartDownloads: ChartDownloads

  var body: some View {
    NavigationStack {
      AirportPane(router: router) { airport in
        ApproachListView(airport: airport, selection: $router.approach, downloads: chartDownloads)
          .navigationDestination(item: $router.approach) { approach in
            FixListView(
              airport: airport,
              approach: approach,
              model: fixList,
              destination: $router.fixListDestination
            )
          }
      }
    }
  }
}

/**
 The iPad layout: the airport picker and its approaches in the leading pane, the chosen
 approach's fixes in the trailing one.

 Each pane carries a `NavigationStack` of its own, so pushing within a pane — the approaches
 over the airport picker, the weather over the fix list — stays inside that pane instead of
 replacing the column.
 */
private struct AirportPanes: View {
  @Bindable var router: AirportRouter
  let fixList: FixListViewModel
  let chartDownloads: ChartDownloads

  var body: some View {
    NavigationSplitView {
      NavigationStack {
        AirportPane(router: router) {
          ApproachListView(airport: $0, selection: $router.approach, downloads: chartDownloads)
        }
      }
    } detail: {
      NavigationStack {
        SelectedApproachDetail(
          airport: router.airport,
          approach: router.approach,
          fixList: fixList,
          destination: $router.fixListDestination
        )
      }
    }
  }
}

/// The leading pane: the airport picker, pushing the chosen airport's approaches.
private struct AirportPane<Approaches: View>: View {
  /**
   Holds the chosen airport — both what the picker marks and what the pane has pushed — and the
   picker's tab and search.
   */
  @Bindable var router: AirportRouter
  /**
   The approach list to push, given the chosen airport — the one place the two layouts differ,
   since only the drill-down stack pushes the fixes from it too.
   */
  @ViewBuilder let approaches: (Airport) -> Approaches

  var body: some View {
    AirportSidebar(
      selection: $router.airport,
      tab: $router.airportTab,
      searchQuery: $router.airportSearchQuery
    )
    .navigationDestination(item: $router.airport, destination: approaches)
  }
}

/**
 The trailing pane: the selected approach's corrected fixes, or a prompt to pick one until an
 airport and an approach have both been chosen.
 */
private struct SelectedApproachDetail: View {
  let airport: Airport?
  let approach: Approach?
  let fixList: FixListViewModel
  @Binding var destination: FixListDestination?

  var body: some View {
    if let airport, let approach {
      FixListView(
        airport: airport,
        approach: approach,
        model: fixList,
        destination: $destination
      )
    } else {
      ContentUnavailableView("Select an Approach", systemImage: "square.dashed")
    }
  }
}

#if DEBUG
  #Preview {
    ContentView()
      .environment(NavDataLoaderViewModel(container: .preview))
      .modelContainer(.preview)
  }

  #Preview("Drill-down stack") {
    @Previewable @State var router = AirportRouter()
    CompactAirportNavigation(
      router: router,
      fixList: FixListViewModel(),
      chartDownloads: ChartDownloads()
    )
    .modelContainer(.preview)
  }

  #Preview("Side-by-side panes") {
    @Previewable @State var router = AirportRouter()
    AirportPanes(router: router, fixList: FixListViewModel(), chartDownloads: ChartDownloads())
      .modelContainer(.preview)
  }

  #Preview("Approach selected") {
    NavigationStack {
      let airport = PreviewData.missoula()
      SelectedApproachDetail(
        airport: airport,
        approach: airport.approaches[0],
        fixList: FixListViewModel(),
        destination: .constant(nil)
      )
    }
    .modelContainer(.preview)
  }

  #Preview("No approach selected") {
    NavigationStack {
      SelectedApproachDetail(
        airport: nil,
        approach: nil,
        fixList: FixListViewModel(),
        destination: .constant(nil)
      )
    }
    .modelContainer(.preview)
  }
#endif
