import SwiftData
import SwiftUI

/// Search airports by identifier, name or city.
struct SearchView: View {
  @Binding var selection: Airport?

  @Environment(\.modelContext)
  private var modelContext
  @State private var viewModel: SearchViewModel?

  var body: some View {
    Group {
      if let viewModel {
        SearchResults(viewModel: viewModel, selection: $selection)
      } else {
        Color.clear
      }
    }
    .onAppear {
      if viewModel == nil {
        viewModel = SearchViewModel(container: modelContext.container)
      }
    }
  }
}

private struct SearchResults: View {
  @Bindable var viewModel: SearchViewModel

  @Binding var selection: Airport?

  var body: some View {
    AirportList(
      airports: viewModel.results,
      emptyMessage: "Search by identifier, name or city.",
      selection: $selection
    )
    .searchable(text: $viewModel.query, prompt: "Airport or city")
    .textInputAutocapitalization(.characters)
    .autocorrectionDisabled()
  }
}

#if DEBUG
  #Preview {
    @Previewable @State var selection: Airport?
    NavigationStack {
      SearchView(selection: $selection)
    }
    .modelContainer(.preview)
  }
#endif
