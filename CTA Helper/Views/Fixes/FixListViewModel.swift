import Foundation
import MeasurementKit
import NavDataSchema
import Observation
import SwiftData

/**
 What the pilot has set on the fix list: the reported temperature and the METAR it was filled
 from, the DA/MDA they typed, and the transitions they chose.

 It is held above the layout rather than by the fix list. The fix list is built afresh whenever
 the width crosses between the drill-down stack and the side-by-side panes — opening or closing
 iPhone Duo, rotating a large iPhone, resizing an iPad window — and state it owned would go with
 it: the minimums blank, and the temperature back to the METAR's, or to 0 °C with no network.

 Nothing here outlives the approach being open: leaving it for the approach list or another
 airport starts the next with a model of its own. While it is open, what survives depends on whose
 it is: the minimums and the chosen transitions belong to the approach, so another approach starts
 them over, while the reported temperature belongs to the airport and stands across every approach
 to it.
 */
@Observable
@MainActor
final class FixListViewModel {
  /**
   The temperatures the reported-temperature slider spans.

   The correction tables stop at −50 °C, and above +10 °C no US Cold Temperature Airport
   restriction is in force. An observation outside that span is pinned to the nearer end rather
   than left off the track, where the slider could not show it.
   */
  static let reportedTemperatureRange =
    Measurement<UnitTemperature>.celsius(-50)...Measurement<UnitTemperature>.celsius(10)

  /// The temperature the correction is computed for, filled from the METAR until the pilot sets it.
  var reportedTemperature: Measurement<UnitTemperature>
  /// The DA or MDA the pilot entered, or `nil` until they enter one.
  var minimums: Measurement<UnitLength>?
  /**
   The transition each segment is showing, where the pilot has chosen one. A segment with no
   entry shows the first transition it codes.
   */
  var selectedTransitions: [Segment: String] = [:]

  /**
   The station's latest METAR, once fetched — the source of the reported temperature, and the
   subject of the weather screen.
   */
  private(set) var observation: METARObservation?

  /**
   The approach the typed minimums and chosen transitions belong to.

   They are the approach's own: a DA/MDA is the one charted for this procedure, and a transition
   is one this procedure codes. Opening another approach starts both over. The identity is the
   persistent one rather than the ARINC identifier, which two airports can both publish.
   */
  private var preparedApproach: PersistentIdentifier?

  /**
   The airport the reported temperature was filled from a METAR for.

   The temperature is the airport's weather rather than the approach's — it is the station's
   reading the pilot is overriding — so it goes on standing when they open another approach to
   the same field. Filling it per approach would pull the slider back to the METAR every time they
   compared two approaches at one airport, discarding a reading they had deliberately set.
   */
  private var filledFromAirport: PersistentIdentifier?

  /**
   The fetch filling the temperature for ``filledFromAirport``.

   It is the model's rather than the fix list's, so a fix list torn down by a change of layout
   part-way through the fetch does not take the fetch with it. The fix list that replaces it finds
   the airport already being filled, and would otherwise be left at the slider's starting value.
   */
  private var fill: Task<Void, Never>?

  /// - Parameter reportedTemperature: the temperature the slider starts at, until a METAR fills it.
  init(reportedTemperature: Measurement<UnitTemperature> = .celsius(0)) {
    self.reportedTemperature = reportedTemperature
  }

  /**
   Start the fix list on an approach: drop what belonged to the one before it, and fill the
   reported temperature from the station's latest METAR.

   The two halves are keyed apart because they belong to different things — the entries to the
   approach, the temperature to the airport — so switching approaches at one field clears the
   minimums without disturbing the reading they are corrected against.

   Both are guarded rather than run on sight, because the fix list prepares every time it appears:
   when the plate pushed over it is dismissed, and when a change of layout rebuilds it. Left
   unguarded, either would blank the minimums the pilot typed and pull the temperature back to the
   METAR's.

   - Parameters:
     - approach: the approach the fix list is showing.
     - airport: the airport it serves, whose station the temperature is filled from.
     - metarLoader: where the METAR comes from, or `nil` where weather is unavailable.
     - networkMonitor: whether there is a network to fetch it over, or `nil` likewise.
   */
  func prepare(
    _ approach: Approach,
    at airport: Airport,
    metarLoader: METARLoader?,
    networkMonitor: NetworkMonitor?
  ) async {
    if preparedApproach != approach.persistentModelID {
      preparedApproach = approach.persistentModelID
      minimums = nil
      selectedTransitions = [:]
    }

    if filledFromAirport != airport.persistentModelID {
      filledFromAirport = airport.persistentModelID
      observation = nil
      fill?.cancel()
      fill = Task {
        await fillTemperature(at: airport, metarLoader: metarLoader, networkMonitor: networkMonitor)
      }
    }
    await fill?.value
  }

  /**
   Fetch the airport's latest METAR when the network is available, and fill the reported
   temperature from it.

   An observation warmer or colder than the slider spans is pinned to the nearer end. Off the
   track the thumb is unreadable and the value is one the control cannot express, and a
   temperature above the span is warmer than any restriction — so the pinned reading and the true
   one call for the same correction: none.
   */
  private func fillTemperature(
    at airport: Airport,
    metarLoader: METARLoader?,
    networkMonitor: NetworkMonitor?
  ) async {
    guard let metarLoader, let networkMonitor, networkMonitor.isConnected else { return }
    let observation = await metarLoader.observation(for: airport.metarStationID)
    guard !Task.isCancelled else { return }

    self.observation = observation
    guard let temperature = observation?.temperature else { return }
    reportedTemperature = temperature.roundedToWholeCelsius.clamped(
      to: Self.reportedTemperatureRange
    )
  }
}
