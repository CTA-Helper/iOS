import NavDataSchema
import SwiftData
import SwiftUI

/**
 The way a pilot puts an airport's plates on the device before they need them.

 A cache that fills only as plates are opened has nothing in it when the pilot is airborne, and
 guessing what to warm — favorites, recents, whatever was opened last — is guessing about a trip
 the app knows nothing about. So the pilot says. They are told how many plates and roughly how
 many bytes before anything is fetched, and nothing is fetched without them asking.

 While a run is in flight the button stops it instead. How far along the run is goes in a toolbar
 item of its own, ``ChartDownloadProgress``. SwiftUI lays a custom view out only along a
 horizontal bar, so where the bar is vertical — iPhone Duo's outer display — a Stop button sharing
 the progress ring's item would be held out of the bar with it, rather than standing in the bar
 with the back button.
 */
struct AirportChartsButton: View {
  /// The airport whose approaches' plates are fetched.
  let airport: Airport

  /// The run this button starts and stops.
  @Bindable var downloader: AirportChartDownloader
  @State private var isConfirming = false

  @Environment(\.chartStore)
  private var chartStore
  @Environment(\.networkMonitor)
  private var networkMonitor

  @Query private var cycles: [NavDataCycle]

  var body: some View {
    Group {
      if downloader.progress != nil {
        Button("Stop Downloading Charts", systemImage: "stop.circle") { downloader.cancel() }
          .accessibilityIdentifier("cancelDownloadCharts")
      } else if !ids.isEmpty {
        Button {
          isConfirming = true
        } label: {
          Label("Download Charts", systemImage: "arrow.down.circle")
        }
        .disabled(!canDownload)
        .accessibilityIdentifier("downloadChartsButton")
      }
    }
    .confirmationDialog(
      "Download \(ids.count, format: .number) charts?",
      isPresented: $isConfirming,
      titleVisibility: .visible
    ) {
      Button("Download") { start() }
        .accessibilityIdentifier("confirmDownloadCharts")
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "About \(Int64(AirportChartDownloader.estimatedBytes(forPlates: ids.count)), format: .byteCount(style: .file)). Older charts may be removed to make room."
      )
    }
    .errorSheet($downloader.error)
  }

  /// The plates to fetch: one per approach the navigation data publishes a chart for.
  private var ids: [ChartID] {
    airport.approaches.compactMap(\.chartID)
  }

  /**
   The plates this airport publishes that are not on the device yet.

   Read off the store rather than off the list ``ChartDownloads`` keeps of the airports the pilot
   asked for, which outlives the plates themselves: the cycle purge discards a superseded plate
   without touching the list, so a list that still names the airport says nothing about whether
   there is anything left to fetch.
   */
  private var missing: [ChartID] {
    guard let chartStore else { return ids }
    return ids.filter { !chartStore.hasPlate(for: $0) }
  }

  /**
   Whether there is any point offering the download.

   Every refusal is read off what the app already knows rather than discovered by a run that
   fails: with no network nothing can be fetched, on a superseded cycle every plate's URL is
   already dead, and with every plate on the device there is nothing to ask for — a run there
   would fetch nothing and finish with nothing to report, which reads as the button doing
   nothing at all.
   */
  private var canDownload: Bool {
    chartStore != nil && networkMonitor?.isConnected == true
      && !(cycles.first?.hasExpired ?? true) && !missing.isEmpty
  }

  /// What a finished run came to, in the terms the pilot asked for it in.
  static func message(for summary: AirportChartDownloader.Summary) -> String {
    var parts = [
      String(
        localized:
          "\(summary.downloaded, format: .number) downloaded (\(Int64(summary.bytesDownloaded), format: .byteCount(style: .file)))."
      )
    ]
    if summary.alreadyCached > 0 {
      parts.append(
        String(localized: "\(summary.alreadyCached, format: .number) were already on your device.")
      )
    }
    if summary.failed > 0 {
      parts.append(String(localized: "\(summary.failed, format: .number) could not be downloaded."))
    }
    return parts.joined(separator: " ")
  }

  private func start() {
    guard let chartStore else { return }
    downloader.start(ids, using: chartStore)
  }
}

/// How far along a run in flight is.
struct ChartDownloadProgress: View {
  let progress: AirportChartDownloader.Progress

  var body: some View {
    ProgressView(value: progress.fraction)
      .progressViewStyle(.circular)
      .accessibilityLabel("Downloading charts")
      .accessibilityValue(
        "\(progress.completed, format: .number) of \(progress.total, format: .number)"
      )
      .accessibilityIdentifier("chartDownloadProgress")
  }
}
