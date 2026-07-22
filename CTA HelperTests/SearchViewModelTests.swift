import SwiftData
import Testing

@testable import CTA_Helper

/**
 Airport search, over a store holding one airport with an ICAO code and one without.

 The ICAO code is optional on the model, and the query for it is compiled into SQL by
 SwiftData rather than run in Swift, so that it matches at all is worth pinning.
 */
@MainActor
@Suite("Airport search", .serialized)
struct SearchViewModelTests {
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

  @Test("Finds an airport by its ICAO code")
  func findsByICAOCode() async throws {
    #expect(try await search("KMSO") == ["KMSO"])
  }

  @Test("Finds the same airport by its FAA location identifier")
  func findsByFAAIdentifier() async throws {
    #expect(try await search("MSO") == ["KMSO"])
  }

  @Test("Finds an airport that has no ICAO code by its location identifier")
  func findsAnAirportWithoutAnICAOCode() async throws {
    #expect(try await search("05U") == ["05U"])
  }

  @Test("Finds an airport by city")
  func findsByCity() async throws {
    #expect(try await search("Eureka") == ["05U"])
  }
}
