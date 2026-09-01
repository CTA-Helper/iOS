import SwiftData
import SwiftUI

/**
 The approach plate, with the corrected altitudes laid over it.

 A plate viewer on its own would duplicate what the pilot already has open, and worse than that
 app does it. What this screen is for is the column down its trailing edge: the published
 procedure and what cold air does to its altitudes, read together, which is the one thing no
 chart app can show.

 It is pushed rather than presented, so on iPad it takes the detail pane the fix list was in.
 That costs nothing precisely because the overlay carries the altitudes across with it.
 */
struct ChartScreen: View {
  /// The approach whose plate is drawn.
  let approach: Approach
  /// The correction in force, rebuilt by the fix list from its own controls.
  let corrector: ApproachCorrector
  /// The transition each segment is showing, as the pilot chose it on the fix list.
  let transitions: [Segment: String]
  /// The DA or MDA the pilot entered, or `nil` until they enter one.
  let minimums: Measurement<UnitLength>?

  @State private var plate: URL?
  @State private var error: (any Error)?
  @State private var isFetching = false
  @State private var isShowingAltitudes = true

  @Environment(\.chartStore)
  private var chartStore
  @Environment(\.networkMonitor)
  private var networkMonitor
  @Environment(\.accessibilityReduceMotion)
  private var reduceMotion

  @Query private var cycles: [NavDataCycle]

  var body: some View {
    Group {
      if let plate {
        Plate(plate: plate, sections: sections, isShowingAltitudes: isShowingAltitudes)
      } else if isFetching {
        ProgressView("Downloading Chart")
          .accessibilityIdentifier("chartProgress")
      } else {
        ChartUnavailableView(reason: unavailableReason, retry: retry)
      }
    }
    .navigationTitle(approach.name)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if plate != nil {
        ToolbarItem(placement: .topBarTrailing) {
          // `sidebar.trailing` rather than `sidebar.right`: the panel is on the trailing edge,
          // which is the leading one in a right-to-left layout. There is no filled variant, and
          // none is wanted — the panel's own presence says which way the toggle is set, and the
          // label says it to VoiceOver.
          Button(action: toggleAltitudes) {
            Label(
              isShowingAltitudes ? "Hide Corrected Altitudes" : "Show Corrected Altitudes",
              systemImage: "sidebar.trailing"
            )
          }
          .accessibilityIdentifier("correctedAltitudesToggle")
        }
      }
    }
    // No `keepsScreenAwake()` of its own. The fix list this is pushed from has not gone
    // anywhere and is still holding the display on; adding a second hold here would restore
    // the auto-lock on the way back, leaving the screen the pilot returned to asleep.
    .safeAreaInset(edge: .bottom) { ChartDisclaimer() }
    .task(id: approach.identifier) { await load() }
  }

  /// The panel's sections, rebuilt whenever the correction the fix list handed down changes.
  private var sections: [ChartAltitudes.Section] {
    ChartAltitudes.sections(
      of: approach,
      corrector: corrector,
      transitions: transitions,
      minimums: minimums
    )
  }

  /// Whether the imported cycle has been superseded, so this approach's plate URL is dead.
  private var cycleHasExpired: Bool {
    cycles.first?.hasExpired ?? true
  }

  /// Why there is no plate, once it is settled that there is none.
  private var unavailableReason: ChartUnavailableView.Reason {
    if let error { return .failed(error) }
    guard approach.chartID != nil else { return .unpublished }
    if cycleHasExpired { return .supersededCycle }
    return .offline
  }

  /// Fetching again is worth offering only where a fetch was tried and failed.
  private var retry: (() -> Void)? {
    guard error != nil else { return nil }
    return { Task { await load(force: true) } }
  }

  /**
   Show or hide the corrected altitudes.

   Reduce Motion takes the animation away rather than shortening it. A pilot who has asked the
   system for no motion is not asking for less of it.
   */
  private func toggleAltitudes() {
    withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
      isShowingAltitudes.toggle()
    }
  }

  /**
   Draw the plate from the cache, fetching it only when there is a network to fetch it over.

   Reachability is read off the monitor rather than discovered by a request that fails, so a
   chart that cannot be fetched says so instead of spending a timeout finding out.
   */
  private func load(force: Bool = false) async {
    guard let chartStore, let id = approach.chartID else { return }
    if force { error = nil }

    if let cached = await chartStore.cachedPlate(for: id) {
      plate = cached
      return
    }

    guard let networkMonitor, networkMonitor.isConnected, !cycleHasExpired else { return }

    isFetching = true
    defer { isFetching = false }
    do {
      plate = try await chartStore.plate(for: id)
    } catch {
      guard !error.isCancellation else { return }
      self.error = error
    }
  }
}

/// The plate and the panel of corrected altitudes over it.
private struct Plate: View {
  let plate: URL
  let sections: [ChartAltitudes.Section]
  let isShowingAltitudes: Bool

  var body: some View {
    PlateView(plate: plate)
      .accessibilityIdentifier("approachPlate")
      .overlay(alignment: .topTrailing) {
        if isShowingAltitudes {
          CorrectedAltitudeOverlay(sections: sections)
        }
      }
  }
}

/**
 The disclaimer, standing under the plate wherever the plate is showing.

 It costs chart area, and it is meant to. A viewer convenient enough that the pilot stops
 noticing it is a convenience is the one failure this screen could cause, and the words are the
 same ones ``AboutView`` carries.
 */
private struct ChartDisclaimer: View {
  var body: some View {
    Text(
      "This app is for situational awareness and planning only. It is not for primary navigation. Always verify every correction independently, and read the DA/MDA and all altitudes from the official approach plate before you fly them."
    )
    .font(.caption2)
    .multilineTextAlignment(.center)
    .padding(.horizontal)
    .padding(.vertical, 6)
    .frame(maxWidth: .infinity)
    .background(.bar)
    .accessibilityIdentifier("chartDisclaimer")
  }
}

#if DEBUG
  #Preview("No chart published") {
    let airport = PreviewData.missoula()
    NavigationStack {
      ChartScreen(
        approach: airport.approaches[1],
        corrector: .preview(for: airport),
        transitions: [:],
        minimums: nil
      )
    }
    .modelContainer(.preview)
    .environment(\.networkMonitor, NetworkMonitor(reporting: true))
  }

  #Preview("Offline, not downloaded") {
    let airport = PreviewData.missoula()
    NavigationStack {
      ChartScreen(
        approach: airport.approaches[0],
        corrector: .preview(for: airport),
        transitions: [:],
        minimums: nil
      )
    }
    .modelContainer(.preview)
    .environment(\.networkMonitor, NetworkMonitor(reporting: false))
  }
#endif
