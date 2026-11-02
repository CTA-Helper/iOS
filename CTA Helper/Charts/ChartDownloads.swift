import Foundation
import NavDataSchema
import Observation

/**
 The chart downloads the pilot has started, one per airport, and what each came to.

 They are held above the layout rather than by the approach list that starts them. A change of
 layout — opening or closing iPhone Duo, among other things — builds the approach list afresh, and
 a downloader it owned would carry on fetching out of sight while the new list offered the
 download again, with no progress and no way to stop the run. A run also outlives the list in the
 ordinary way, when the pilot goes back or on to another airport before it ends, so what a run
 finishing means is settled here too rather than by a view that may no longer be on screen.
 */
@Observable
@MainActor
final class ChartDownloads {
  /**
   What the last download to finish came to, until the pilot dismisses it.

   It is presented from above the layout as well. An alert presented by a view that is rebuilt is
   destroyed with it rather than queued, and SwiftUI writes the `nil` back through the binding —
   whether the view is the toolbar item, which swaps back to the button as the run ends, or the
   approach list, rebuilt when iPhone Duo opens or closes.
   */
  var finishedSummary: AirportChartDownloader.Summary?

  /// The downloaders handed out so far, by airport site number.
  @ObservationIgnored private var downloaders: [String: AirportChartDownloader] = [:]

  private let defaults: UserDefaults

  /// - Parameter defaults: where the airports whose charts were downloaded are recorded.
  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  /// The downloader for `airport`'s plates, made the first time the airport asks for one.
  func downloader(for airport: Airport) -> AirportChartDownloader {
    if let downloader = downloaders[airport.siteNumber] { return downloader }
    let siteNumber = airport.siteNumber
    let downloader = AirportChartDownloader { [weak self] summary in
      self?.finish(summary, at: siteNumber)
    }
    downloaders[siteNumber] = downloader
    return downloader
  }

  /**
   Settle a run that has ended: one that fetched anything records its airport and is reported.

   The airport is recorded so the cycle purge, which discards every plate of a superseded cycle,
   can offer the download back rather than silently undoing it every 28 days. A run the pilot
   stopped, or one that fetched nothing, records nothing and says nothing.
   */
  func finish(_ summary: AirportChartDownloader.Summary, at siteNumber: String) {
    guard !summary.wasCancelled, summary.downloaded > 0 else { return }
    let chartAirports = defaults.airportIDList(forKey: SettingsKey.chartAirports)
    defaults.set(chartAirports.adding(siteNumber), forKey: SettingsKey.chartAirports)
    finishedSummary = summary
  }
}
