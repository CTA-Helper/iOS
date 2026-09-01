import SwiftData
import SwiftUI

/**
 The way a pilot puts an airport's plates on the device before they need them.

 A cache that fills only as plates are opened has nothing in it when the pilot is airborne, and
 guessing what to warm — favorites, recents, whatever was opened last — is guessing about a trip
 the app knows nothing about. So the pilot says. They are told how many plates and roughly how
 many bytes before anything is fetched, and nothing is fetched without them asking.
 */
struct AirportChartsButton: View {
  /// The airport whose approaches' plates are fetched.
  let airport: Airport

  @State private var downloader = AirportChartDownloader()
  @State private var isConfirming = false
  @State private var completed: AirportChartDownloader.Summary?

  /**
   The airports whose charts the pilot has downloaded.

   Kept so that the cycle purge, which discards every plate of a superseded cycle, can be
   offered back rather than silently undoing the download every 28 days. Site numbers for the
   reason ``AirportIDList`` gives: a list saved against `KPBI` would have gone dangling the day
   Palm Beach became `KDJT`.
   */
  @AppStorage(SettingsKey.chartAirports)
  private var chartAirports = AirportIDList()

  @Environment(\.chartStore)
  private var chartStore
  @Environment(\.networkMonitor)
  private var networkMonitor

  @Query private var cycles: [NavDataCycle]

  var body: some View {
    Group {
      if let progress = downloader.progress {
        DownloadProgress(progress: progress) { downloader.cancel() }
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
    .alert(
      "Charts Downloaded",
      isPresented: Binding {
        completed != nil
      } set: {
        if !$0 { completed = nil }
      },
      presenting: completed
    ) { _ in
      Button("OK") { completed = nil }
    } message: { summary in
      Text(Self.message(for: summary))
    }
    .errorSheet($downloader.error)
    .onChange(of: downloader.summary) { _, summary in
      guard let summary, !summary.wasCancelled, summary.downloaded > 0 else { return }
      completed = summary
      chartAirports = chartAirports.adding(airport.siteNumber)
    }
  }

  /// The plates to fetch: one per approach the navigation data publishes a chart for.
  private var ids: [ChartID] {
    airport.approaches.compactMap(\.chartID)
  }

  /**
   Whether there is any point offering the download.

   Both refusals are read off what the app already knows rather than discovered by a run that
   fails: with no network nothing can be fetched, and on a superseded cycle every plate's URL is
   already dead.
   */
  private var canDownload: Bool {
    chartStore != nil && networkMonitor?.isConnected == true && !(cycles.first?.hasExpired ?? true)
  }

  /// What a finished run came to, in the terms the pilot asked for it in.
  private static func message(for summary: AirportChartDownloader.Summary) -> String {
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

/// A run in flight: how far along it is, and the way to stop it.
private struct DownloadProgress: View {
  let progress: AirportChartDownloader.Progress
  let cancel: () -> Void

  var body: some View {
    HStack {
      ProgressView(value: progress.fraction)
        .progressViewStyle(.circular)
        .accessibilityLabel("Downloading charts")
        .accessibilityValue(
          "\(progress.completed, format: .number) of \(progress.total, format: .number)"
        )
      Button("Stop", systemImage: "stop.circle", action: cancel)
        .labelStyle(.iconOnly)
        .accessibilityIdentifier("cancelDownloadCharts")
    }
    .accessibilityIdentifier("chartDownloadProgress")
  }
}
