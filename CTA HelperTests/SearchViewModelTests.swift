import SwiftData
import Testing

@testable import CTA_Helper

/**
 Airport search, over a store holding one airport with an ICAO code and one without.

 The ICAO code is optional on the model, and the query for it is compiled into SQL by
 SwiftData rather than run in Swift, so that it matches at all is worth pinning.
 */
@MainActor
@Suite(.serialized)
struct `Airport search` {
  private func search(_ query: String) async throws -> [String] {
    let container = ModelContainer.makeInMemory()
    container.mainContext.insert(PreviewData.missoula())
    container.mainContext.insert(PreviewData.eureka())
    // The search runs on its own context, which sees only what has been saved.
    try container.mainContext.save()

    let viewModel = SearchViewModel(container: container)
    viewModel.query = query
    try? await Task.sleep(for: .milliseconds(600))
    return viewModel.results.map(\.displayIdentifier)
  }

  @Test
  func `finds an airport by its ICAO code`() async throws {
    #expect(try await search("KMSO") == ["KMSO"])
  }

  @Test
  func `finds the same airport by its FAA location identifier`() async throws {
    #expect(try await search("MSO") == ["KMSO"])
  }

  @Test
  func `finds an airport that has no ICAO code by its location identifier`() async throws {
    #expect(try await search("05U") == ["05U"])
  }

  @Test
  func `finds an airport by city`() async throws {
    #expect(try await search("Eureka") == ["05U"])
  }
}
