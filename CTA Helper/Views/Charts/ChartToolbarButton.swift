import SwiftData
import SwiftUI

/**
 The way through to an approach's plate, from the fix list.

 The button says which case it is in before it is pressed. The app is built for the no-network
 case, and a control that looked the same whether or not it could produce a chart would be
 making a promise it cannot keep — so a plate already on the device reads differently from one
 that would have to be fetched, and both read differently from one that cannot be had at all.

 An approach the navigation data publishes no chart for shows no button at all. 584 of them
 publish none, so this is an ordinary case rather than an edge.
 */
struct ChartToolbarButton: View {
  /// The approach whose plate the button opens.
  let approach: Approach
  /// The correction in force, handed to the chart screen so the overlay stays in step.
  let corrector: ApproachCorrector
  /// The transition each segment is showing.
  let transitions: [Segment: String]
  /// The DA or MDA the pilot entered, or `nil` until they enter one.
  let minimums: Measurement<UnitLength>?

  /// Where the plate is already filed, once the cache has been asked.
  @State private var cachedPlate: URL?

  @Environment(\.chartStore)
  private var chartStore
  @Environment(\.networkMonitor)
  private var networkMonitor

  @Query private var cycles: [NavDataCycle]

  var body: some View {
    Group {
      if approach.chartID != nil {
        NavigationLink {
          ChartScreen(
            approach: approach,
            corrector: corrector,
            transitions: transitions,
            minimums: minimums
          )
        } label: {
          Label(label, systemImage: icon)
        }
        .accessibilityIdentifier("chartButton")
      }
    }
    .task(id: approach.identifier) { await findCachedPlate() }
  }

  /**
   What can be done about the plate, from what the app already holds.

   Everything but the cache lookup is known synchronously, so the button is right from its first
   frame rather than after a hop — which matters, since a toolbar item with nothing in it is one
   SwiftUI never builds, and a button that waited to know itself would never appear at all.
   */
  private var availability: ChartAvailability {
    .resolve(
      id: approach.chartID,
      cachedPlate: cachedPlate,
      isConnected: networkMonitor?.isConnected ?? false,
      cycleHasExpired: cycles.first?.hasExpired ?? true
    )
  }

  /// What the button says it will do, which is not the same in all four states.
  private var label: String {
    switch availability {
      case .downloadable: String(localized: "Download Approach Plate")
      case .unavailableOffline: String(localized: "Approach Plate — Not Downloaded")
      case .supersededCycle: String(localized: "Approach Plate — Navigation Data Out of Date")
      case .cached, .unpublished: String(localized: "Approach Plate")
    }
  }

  private var icon: String {
    switch availability {
      case .downloadable: "arrow.down.doc"
      case .unavailableOffline, .supersededCycle: "doc.badge.ellipsis"
      case .cached, .unpublished: "doc.text"
    }
  }

  private func findCachedPlate() async {
    guard let chartStore, let id = approach.chartID else { return }
    cachedPlate = await chartStore.cachedPlate(for: id)
  }
}
