import NavDataSchema
import SwiftData
import SwiftUI

/// Search airports by identifier, name or city.
struct SearchView: View {
  @Binding var selection: Airport?
  /**
   What the pilot has typed, held above the layout: the view model is this view's own and is
   built again whenever a change of layout rebuilds the view, so it starts from this.
   */
  @Binding var query: String

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
        let viewModel = SearchViewModel(container: modelContext.container)
        viewModel.query = query
        self.viewModel = viewModel
      }
    }
    .onChange(of: viewModel?.query) { _, typed in
      if let typed { query = typed }
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
    @Previewable @State var query = ""
    NavigationStack {
      SearchView(selection: $selection, query: $query)
    }
    .modelContainer(.preview)
  }
#endif
