import Foundation
import Testing

@testable import CTA_Helper

@Suite
struct `Chart identity` {
  private func id(_ url: String) -> ChartID? {
    URL(string: url).flatMap(ChartID.init(chartURL:))
  }

  @Test
  func `reads the cycle and plate name off a published chart URL`() throws {
    let chart = try #require(id("https://aeronav.faa.gov/d-tpp/2608/00266RY12.PDF"))
    #expect(chart.cycle == "2608")
    #expect(chart.name == "00266RY12")
    #expect(chart.cachePath == "2608/00266RY12.pdf")
  }

  /// One plate in the published cycle is named this way; a letters-and-digits rule would drop it.
  @Test
  func `accepts a plate name carrying an underscore`() throws {
    let chart = try #require(id("https://aeronav.faa.gov/d-tpp/2607/00459IY24SAC1_2.PDF"))
    #expect(chart.name == "00459IY24SAC1_2")
  }

  /**
   The cycle and the plate name go on to name a directory and a file the app creates, so a URL
   that is not the shape the nav data publishes must resolve to nothing at all rather than to a
   path.
   */
  @Test(arguments: [
    "https://aeronav.faa.gov/d-tpp/2608/../../etc/passwd.PDF",
    "https://aeronav.faa.gov/d-tpp/../2608/00266RY12.PDF",
    "https://aeronav.faa.gov/d-tpp/2608/plate%2F..%2Fescape.PDF",
    "https://aeronav.faa.gov/d-tpp/2608/spaced out.PDF"
  ])
  func `refuses a URL that could name a file outside the cache`(url: String) {
    #expect(id(url) == nil)
  }

  @Test(arguments: [
    "https://aeronav.faa.gov/d-tpp/2608/00266RY12.HTML",
    "https://aeronav.faa.gov/d-tpp/26081/00266RY12.PDF",
    "https://aeronav.faa.gov/d-tpp/26O8/00266RY12.PDF",
    "https://aeronav.faa.gov/other/2608/00266RY12.PDF",
    "https://aeronav.faa.gov/d-tpp/2608/.PDF",
    "https://aeronav.faa.gov/d-tpp/2608/extra/00266RY12.PDF"
  ])
  func `refuses a URL that is not a published plate`(url: String) {
    #expect(id(url) == nil)
  }
}

@Suite
struct `Chart availability` {
  private static let id = ChartID(
    chartURL: URL(string: "https://aeronav.faa.gov/d-tpp/2608/00266RY12.PDF")!
  )
  private static let plate = URL(fileURLWithPath: "/tmp/2608/00266RY12.pdf")

  private func resolve(
    hasChart: Bool = true,
    cached: Bool = false,
    isConnected: Bool = true,
    cycleHasExpired: Bool = false
  ) -> ChartAvailability {
    .resolve(
      id: hasChart ? Self.id : nil,
      cachedPlate: cached ? Self.plate : nil,
      isConnected: isConnected,
      cycleHasExpired: cycleHasExpired
    )
  }

  @Test
  func `an approach the nav data publishes no chart for offers nothing`() {
    #expect(resolve(hasChart: false) == .unpublished)
    // Nothing else can override it: there is no chart to have.
    #expect(resolve(hasChart: false, cached: true, isConnected: false) == .unpublished)
  }

  /**
   A pilot who deferred the update at launch is flying the stored cycle, and the plate on disk
   is that cycle's. Hiding it behind "your data is out of date" would withhold the right chart.
   */
  @Test
  func `a cached plate opens even on a superseded cycle`() {
    #expect(resolve(cached: true, isConnected: false, cycleHasExpired: true) == .cached(Self.plate))
  }

  /**
   Every plate URL embeds the cycle it was published in, so on a superseded cycle the fetch can
   only 404. Offering the download anyway would be a promise the app already knows it cannot
   keep.
   */
  @Test
  func `a superseded cycle is named, not offered as a download`() {
    #expect(resolve(isConnected: true, cycleHasExpired: true) == .supersededCycle)
  }

  @Test
  func `an uncached plate is downloadable only while there is a network`() {
    #expect(resolve(isConnected: true) == .downloadable)
    #expect(resolve(isConnected: false) == .unavailableOffline)
  }
}

@Suite
struct `Chart cache eviction` {
  private static let megabyte: UInt64 = 1_000_000

  private func entry(_ name: String, megabytes: UInt64, agedDays: Int) -> ChartStore.CacheEntry {
    .init(
      url: URL(fileURLWithPath: "/tmp/2608/\(name).pdf"),
      bytes: megabytes * Self.megabyte,
      lastOpened: .now.addingTimeInterval(-Double(agedDays) * 86_400)
    )
  }

  private func names(_ evictions: [ChartStore.CacheEntry]) -> [String] {
    evictions.map { $0.url.deletingPathExtension().lastPathComponent }
  }

  @Test
  func `evicts nothing when the incoming plate already fits`() {
    let entries = [entry("a", megabytes: 3, agedDays: 9), entry("b", megabytes: 3, agedDays: 1)]
    #expect(
      ChartStore.evictions(from: entries, toFit: 2 * Self.megabyte, budget: 10 * Self.megabyte)
        .isEmpty
    )
  }

  @Test
  func `evicts the least recently opened first, and only as many as it takes`() {
    let entries = [
      entry("newest", megabytes: 3, agedDays: 1),
      entry("oldest", megabytes: 3, agedDays: 30),
      entry("middle", megabytes: 3, agedDays: 10)
    ]

    let evictions = ChartStore.evictions(
      from: entries,
      toFit: 3 * Self.megabyte,
      budget: 10 * Self.megabyte
    )

    #expect(names(evictions) == ["oldest"])
  }

  @Test
  func `evicts more than one plate when one is not enough`() {
    let entries = (1...4).map { entry("plate\($0)", megabytes: 3, agedDays: 40 - $0) }

    let evictions = ChartStore.evictions(
      from: entries,
      toFit: 6 * Self.megabyte,
      budget: 12 * Self.megabyte
    )

    #expect(names(evictions) == ["plate1", "plate2"])
  }

  /// A plate too large for the budget empties the cache rather than looping over it forever.
  @Test
  func `stops after clearing everything, even when the incoming plate still will not fit`() {
    let entries = [entry("a", megabytes: 3, agedDays: 2), entry("b", megabytes: 3, agedDays: 1)]

    let evictions = ChartStore.evictions(
      from: entries,
      toFit: 50 * Self.megabyte,
      budget: 10 * Self.megabyte
    )

    #expect(evictions.count == entries.count)
  }
}

@Suite
struct `Chart response validation` {
  /**
   The chart server answers a superseded cycle with an HTML page, and an FBO's captive portal
   answers everything with a login page — sometimes labelled `application/pdf`. The body's own
   first bytes are the only thing that can tell PDFKit what it is about to be handed.
   */
  @Test
  func `rejects a body that is not a PDF, whatever it claims to be`() {
    #expect(!ChartStore.isPDF(Data("<!DOCTYPE html><html><body>Not found".utf8)))
    #expect(!ChartStore.isPDF(Data("%PD".utf8)))
    #expect(!ChartStore.isPDF(Data()))
  }

  @Test
  func `accepts a PDF`() {
    #expect(ChartStore.isPDF(Data("%PDF-1.7\n%âãÏÓ".utf8)))
  }
}

@Suite
struct `Chart errors` {
  /**
   A full disk is the pilot's own environment rather than a defect, and an HTML body is a
   captive portal. Neither is actionable; reporting them would bury the failures that are.
   */
  @Test
  func `does not report a failure the pilot's own environment caused`() {
    #expect(!ChartError.writeFailed(underlying: POSIXError(.ENOSPC)).isReportable)
    #expect(!ChartError.notAPDF(contentType: "text/html; charset=utf-8").isReportable)
    #expect(!ChartError.cycleSuperseded(cycle: "2601").isReportable)
    #expect(!ChartError.httpError(statusCode: 503).isReportable)
  }

  /// A successful response that is neither a PDF nor HTML means the wire format changed.
  @Test
  func `reports a response that is neither a chart nor an error page`() {
    #expect(ChartError.notAPDF(contentType: "application/zip").isReportable)
    #expect(ChartError.notAPDF(contentType: nil).isReportable)
  }

  @Test
  func `reports a write that failed for a reason other than a full disk`() {
    #expect(ChartError.writeFailed(underlying: POSIXError(.EACCES)).isReportable)
  }
}
