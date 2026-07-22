import CoreLocation
import SwiftData
import SwiftUI

/// Airports nearest the device, or a prompt to enable location.
struct NearestView: View {
  @Binding var selection: Airport?

  @Environment(\.modelContext)
  private var modelContext
  @Environment(\.locationStreamer)
  private var locationStreamer

  @State private var viewModel: NearestAirportViewModel?

  var body: some View {
    NearestContent(
      authorization: locationStreamer.authorizationStatus,
      airports: viewModel?.airports ?? [],
      selection: $selection
    )
    .task { startIfAuthorized() }
    .onDisappear {
      let viewModel = viewModel
      Task { await viewModel?.stop() }
    }
  }

  private var isAuthorized: Bool {
    switch locationStreamer.authorizationStatus {
      case .authorizedWhenInUse, .authorizedAlways: true
      default: false
    }
  }

  private func startIfAuthorized() {
    guard viewModel == nil, isAuthorized else { return }
    viewModel = NearestAirportViewModel(
      container: modelContext.container,
      locationStreamer: locationStreamer
    )
  }
}

/**
 What the Nearest tab shows for a given location authorization: the airports themselves once
 the pilot has allowed location, and otherwise an explanation of why the list is empty that
 distinguishes a decision not yet made from one made against us.
 */
private struct NearestContent: View {
  let authorization: CLAuthorizationStatus
  let airports: [Airport]

  @Binding var selection: Airport?

  var body: some View {
    switch authorization {
      case .denied, .restricted:
        ContentUnavailableView {
          Label("Location Off", systemImage: "location.slash")
        } description: {
          Text("Enable location access in Settings to see nearby airports.")
        }
        .accessibilityIdentifier("locationOffNotice")
      case .notDetermined:
        ContentUnavailableView {
          Label("Nearby Airports", systemImage: "location")
        } description: {
          Text("Allow location access to see airports near you.")
        }
        .accessibilityIdentifier("locationPromptNotice")
      default:
        AirportList(
          airports: airports,
          emptyMessage: "No airports within 50 NM.",
          selection: $selection
        )
    }
  }
}

#if DEBUG
  #Preview("Location Off") {
    @Previewable @State var selection: Airport?
    NavigationStack {
      NearestView(selection: $selection)
    }
    .modelContainer(.preview)
    .environment(\.locationStreamer, FixedLocationStreamer(authorizationStatus: .denied))
  }

  #Preview("Not Determined") {
    @Previewable @State var selection: Airport?
    NavigationStack {
      NearestView(selection: $selection)
    }
    .modelContainer(.preview)
    .environment(\.locationStreamer, FixedLocationStreamer(authorizationStatus: .notDetermined))
  }

  #Preview("Authorized") {
    @Previewable @State var selection: Airport?
    NavigationStack {
      NearestView(selection: $selection)
    }
    .modelContainer(.preview)
    .environment(
      \.locationStreamer,
      FixedLocationStreamer(authorizationStatus: .authorizedWhenInUse, location: .nearMissoula)
    )
  }
#endif
