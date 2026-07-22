import Foundation
import Gzip
import Sentry
import SwiftMETAR
import os

/**
 Downloads and parses the national METAR cache, exposing the latest ``METARObservation`` per
 station.

 The Aviation Weather Center publishes every current US METAR as a single gzipped XML file.
 The loader fetches that file, decompresses it, streams it through `SwiftMETAR`, and keeps an
 in-memory `[stationID: METARObservation]` map. To respect the source, it reloads no more often
 than ``reloadInterval`` unless a caller forces a refresh. A transient network failure leaves
 any previously loaded observations in place rather than clearing them.
 */
actor METARLoader {
  /// The minimum time between downloads of the METAR cache.
  private static let reloadInterval: TimeInterval = 15 * 60

  /// The Aviation Weather Center's gzipped cache of all current US METARs.
  private static let cacheURL = URL(
    string: "https://aviationweather.gov/data/cache/metars.cache.xml.gz"
  )!

  private static let logger = Logger(
    subsystem: "codes.tim.CTA-Helper",
    category: "METARLoader"
  )

  private var observations: [String: METARObservation]

  private var lastLoad: Date?

  /**
   Whether the observations were handed in rather than downloaded, in which case there is
   nothing to reload.
   */
  private let isSeeded: Bool

  /// Creates a loader that downloads the published METAR cache.
  init() {
    observations = [:]
    isSeeded = false
  }

  /**
   Creates a loader that serves a fixed set of observations and never reaches the network, so
   that a test or preview showing weather does not depend on what is being reported now.

   - Parameter observations: the observations to serve, keyed by station ID.
   */
  init(serving observations: [String: METARObservation]) {
    self.observations = observations
    isSeeded = true
  }

  /**
   Whether a reload should proceed, given the last load time and whether it was forced.

   A forced reload always proceeds. Otherwise a reload proceeds only if the cache has never
   been loaded or the last load was at least ``reloadInterval`` ago.
   */
  static func shouldReload(force: Bool, lastLoad: Date?, now: Date) -> Bool {
    if force { return true }
    guard let lastLoad else { return true }
    return now.timeIntervalSince(lastLoad) >= reloadInterval
  }

  /**
   The latest observation for the given station, loading the cache first if it is stale.

   - Parameter stationID: the station's four-character ID (for example, an airport's
     ``Airport/metarStationID``). A station absent from the cache returns `nil`.
   - Returns: the station's most recent ``METARObservation``, or `nil` if it is not in the cache.
   */
  func observation(for stationID: String) async -> METARObservation? {
    await reload()
    return observations[stationID]
  }

  /**
   Refreshes the observation cache, subject to the reload interval.

   - Parameter force: when `true`, download even if the last load was within
     ``reloadInterval``.
   */
  func reload(force: Bool = false) async {
    guard !isSeeded else { return }
    guard Self.shouldReload(force: force, lastLoad: lastLoad, now: .now) else { return }

    do {
      let xml = try gunzip(await download())
      observations = await parse(xml)
      lastLoad = .now
      Self.logger.info("Loaded \(self.observations.count) METAR observations")
    } catch {
      Self.logger.error("Failed to load METARs: \(error)")
      report(error)
    }
  }

  /**
   Send a weather failure to crash reporting, under one fingerprint so they group into a single
   issue rather than one per status code.

   A server that is down is filtered out by ``WeatherError/isReportable``: weather is
   best-effort here, and nothing about an outage is actionable.

   `SwiftMETAR` exports its own concrete `Error`, so the protocol needs naming in full here.
   */
  private func report(_ error: any Swift.Error) {
    guard (error as? WeatherError)?.isReportable ?? true else { return }

    SentrySDK.capture(error: error) { scope in
      scope.setFingerprint(["weather", "reload"])
    }
  }

  private func download() async throws -> Data {
    try await withRetry(logger: Self.logger, label: "download METAR cache") {
      let (data, response) = try await URLSession.shared.data(from: Self.cacheURL)
      if let http = response as? HTTPURLResponse, !http.isSuccessful {
        throw WeatherError.httpError(statusCode: http.statusCode)
      }
      return data
    }
  }

  private func gunzip(_ compressed: Data) throws -> Data {
    do {
      return try compressed.gunzipped()
    } catch {
      throw WeatherError.decompressionFailed(underlying: error)
    }
  }

  private func parse(_ xml: Data) async -> [String: METARObservation] {
    var parsed: [String: METARObservation] = [:]
    for await result in SwiftMETAR.METAR.from(xml: xml) {
      guard case .success(let metar) = result else { continue }
      parsed[metar.stationID] = METARObservation(
        stationID: metar.stationID,
        temperature: metar.temperatureMeasurement,
        date: metar.date,
        rawText: metar.text ?? ""
      )
    }
    return parsed
  }
}
