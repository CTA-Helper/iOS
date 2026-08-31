import Foundation

/**
 Everything the chart subsystem needs to fetch and file one approach plate, read off the URL
 the nav data publishes.

 ``Approach`` is a SwiftData model and so cannot cross into ``ChartStore``; this is the value
 that does. It is also the guard on the two strings that go on to name a directory and a file
 this app creates, which is why ``init(chartURL:)`` validates the whole shape of the URL rather
 than reaching into it by index.
 */
struct ChartID: Hashable, Sendable {
  /// The single path prefix every published plate URL carries.
  private static let pathPrefix = "d-tpp"

  /// How many characters an AIRAC cycle is written in, e.g. `"2608"`.
  private static let cycleLength = 4

  /**
   The characters an FAA plate name is spelled with.

   Underscore is in the set because one plate in the published cycle uses it
   (`00459IY24SAC1_2`); a set of letters and digits alone would drop that approach's chart.
   */
  private static let nameCharacters = CharacterSet(
    charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
  )

  /// The AIRAC cycle the plate was published in, e.g. `"2608"`.
  let cycle: String

  /// The plate's published name, without its extension, e.g. `"00266RY12"`.
  let name: String

  /// The URL the nav data published for the plate.
  let source: URL

  /// Where the plate is filed under the cache's root directory.
  var cachePath: String { "\(cycle)/\(name).pdf" }

  /// Where the plate is fetched from: the published URL, or the fixture a UI test serves.
  var fetchURL: URL { UITestConfiguration.charts?.url(for: self) ?? source }

  /**
   Reads the cycle and plate name out of a published chart URL.

   - Parameter chartURL: the URL the nav data published, which must be of the form
     `…/d-tpp/<cycle>/<NAME>.PDF`.
   - Returns: `nil` when the URL is not that shape — which is what keeps a name carrying a
     path separator, a relative segment, or whitespace from ever naming a file.
   */
  init?(chartURL: URL) {
    let components = chartURL.pathComponents
    guard components.count == 4,
      components[1] == Self.pathPrefix,
      Self.isCycle(components[2]),
      let name = Self.plateName(from: components[3])
    else { return nil }

    cycle = components[2]
    self.name = name
    source = chartURL
  }

  /// Whether a path component is an AIRAC cycle: four ASCII digits and nothing else.
  private static func isCycle(_ component: String) -> Bool {
    component.count == cycleLength && component.allSatisfy { $0.isASCII && $0.isNumber }
  }

  /// The plate name a `<NAME>.PDF` path component spells, or `nil` if it spells something else.
  private static func plateName(from component: String) -> String? {
    let url = URL(fileURLWithPath: component)
    guard url.pathExtension.caseInsensitiveCompare("PDF") == .orderedSame else { return nil }

    let name = url.deletingPathExtension().lastPathComponent
    guard !name.isEmpty,
      CharacterSet(charactersIn: name).isSubset(of: nameCharacters)
    else { return nil }

    return name
  }
}

extension Approach {
  /// The plate to fetch for this approach, or `nil` where the nav data published none.
  var chartID: ChartID? { chartURL.flatMap(ChartID.init(chartURL:)) }
}
