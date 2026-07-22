import Foundation

/**
 The `manifest.json` published alongside each nav data release: cheap to poll to learn
 whether a newer AIRAC cycle is available before downloading the ~1.3 MB data file.
 */
struct NavDataManifest: Decodable, Sendable {
  let airacCycle: String
  let cycleEffective: Date
  let cycleExpires: Date
  let generatedAt: Date
  let data: DataFile

  struct DataFile: Decodable, Sendable {
    let filename: String
    let bytes: UInt
    let uncompressedBytes: UInt
    let sha256: String
  }
}

extension NavDataManifest {
  /// The URL of the newest published manifest.
  private static let releaseURL = URL(
    string: "https://github.com/CTA-Helper/Navdata/releases/latest/download/manifest.json"
  )!

  /// The URL of the newest published data file.
  private static let releaseDataURL = URL(
    string: "https://github.com/CTA-Helper/Navdata/releases/latest/download/cta-navdata.json.gz"
  )!

  /// Where the manifest is fetched from: the newest release, or the fixture a UI test serves.
  static var url: URL { UITestConfiguration.navData?.manifestURL ?? releaseURL }

  /// Where the data file is fetched from, following ``url``.
  static var dataURL: URL { UITestConfiguration.navData?.dataURL ?? releaseDataURL }

  /**
   A `JSONDecoder` configured for the manifest's ISO-8601 dates (`cycleEffective` is a plain
   date, `generatedAt` a full timestamp), so both parse.
   */
  static func decoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      let string = try decoder.singleValueContainer().decode(String.self)
      if let date = flexibleDate(from: string) { return date }
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: "Unrecognized date: \(string)")
      )
    }
    return decoder
  }

  private static func flexibleDate(from string: String) -> Date? {
    let withTime = ISO8601DateFormatter()
    if let date = withTime.date(from: string) { return date }
    let dateOnly = ISO8601DateFormatter()
    dateOnly.formatOptions = [.withFullDate]
    return dateOnly.date(from: string)
  }
}
