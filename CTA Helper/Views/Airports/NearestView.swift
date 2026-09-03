import CoreLocation
import SwiftData
import SwiftUI

/// Airports nearest the device, or an account of why there are none to list.
struct NearestView: View {
  @Binding var selection: Airport?

  @Environment(\.modelContext)
  private var modelContext
  @Environment(\.locationStreamer)
  private var locationStreamer
  @Environment(\.scenePhase)
  private var scenePhase

  @State private var viewModel: NearestAirportViewModel?

  var body: some View {
    NearestContent(
      availability: locationStreamer.availability,
      airports: viewModel?.airports ?? [],
      selection: $selection
    )
    .task {
      await locationStreamer.start()
      // `task` cancellation is cooperative, so a tab visited and left within one runloop turn
      // runs its `onDisappear` before this resumes: the release lands before the acquire, where
      // the floor in `stop()` swallows it. Balance the listener here rather than leave the GPS
      // running with the tab off screen.
      guard !Task.isCancelled else {
        await locationStreamer.stop()
        return
      }
      viewModel = NearestAirportViewModel(
        container: modelContext.container,
        locationStreamer: locationStreamer
      )
    }
    .onDisappear {
      viewModel?.cancel()
      viewModel = nil
      Task { await locationStreamer.stop() }
    }
    .onChange(of: scenePhase) { _, phase in
      // A pilot who allowed location in Settings comes back to a refusal that is no longer true,
      // and Core Location only revises it on a fresh stream. A stream that failed gets its one
      // chance to recover here too.
      guard phase == .active, locationStreamer.needsFreshStream else { return }
      Task { await locationStreamer.retry() }
    }
  }
}

/**
 What the Nearest tab shows for a given location availability: the airports themselves once a fix
 has arrived, and otherwise why there are none to show.

 The empty states are not interchangeable. A question still being asked resolves itself, a
 refusal the pilot can lift asks them to go to Settings, and one they cannot lift asks them to
 stop waiting — so each says which it is.
 */
private struct NearestContent: View {
  let availability: LocationAvailability?
  let airports: [Airport]

  @Binding var selection: Airport?

  var body: some View {
    switch availability {
      case nil:
        ProgressView("Finding your location…")
      case .requestingAuthorization:
        ContentUnavailableView {
          Label("Nearby Airports", systemImage: "location")
        } description: {
          Text("Allow location access to see airports near you.")
        }
        .accessibilityIdentifier("locationPromptNotice")
      case .authorizationDenied:
        LocationRefusedView(reason: .app)
      case .authorizationDeniedGlobally:
        LocationRefusedView(reason: .deviceWide)
      case .authorizationRestricted:
        LocationRefusedView(reason: .restricted)
      case .locationUnavailable:
        ContentUnavailableView {
          Label("Location Unavailable", systemImage: "location.slash")
        } description: {
          Text("Your position can’t be determined right now.")
        }
        .accessibilityIdentifier("locationUnavailableNotice")
      case .available:
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
    .environment(\.locationStreamer, FixedLocationStreamer(availability: .authorizationDenied))
  }

  #Preview("Location Services Off") {
    @Previewable @State var selection: Airport?
    NavigationStack {
      NearestView(selection: $selection)
    }
    .modelContainer(.preview)
    .environment(
      \.locationStreamer,
      FixedLocationStreamer(availability: .authorizationDeniedGlobally)
    )
  }

  #Preview("Awaiting Permission") {
    @Previewable @State var selection: Airport?
    NavigationStack {
      NearestView(selection: $selection)
    }
    .modelContainer(.preview)
    .environment(
      \.locationStreamer,
      FixedLocationStreamer(availability: .requestingAuthorization)
    )
  }

  #Preview("Authorized") {
    @Previewable @State var selection: Airport?
    NavigationStack {
      NearestView(selection: $selection)
    }
    .modelContainer(.preview)
    .environment(
      \.locationStreamer,
      FixedLocationStreamer(availability: .available, location: .nearMissoula)
    )
  }
#endif
