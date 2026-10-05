import SwiftUI

/**
 The screen shown while the store is not fit to fly: it asks for the download the app needs and,
 once the pilot consents, follows the update through to the end.

 On first run the store is empty and the download is the only way past it. When the installed
 data is out of date, the same screen offers the update alongside the choice to fly the stored
 cycle for now.
 */
struct LoadingView: View {
  @Bindable var viewModel: NavDataLoaderViewModel

  var body: some View {
    Group {
      switch viewModel.state {
        case .idle:
          LoadingConsentView(viewModel: viewModel)
        default:
          LoadingProgressView(state: viewModel.state)
      }
    }
    // A failed first-run download leaves the pilot with no data and nothing to do but retry, so
    // it blocks. A failed update blocks the same way, and dismissing it returns them to the
    // choice to keep flying the cycle they already have.
    .errorSheet($viewModel.error)
  }
}

#if DEBUG
  #Preview(
    arguments: [
      NavDataLoaderViewModel.previewing(),
      .previewing(noData: false, canSkip: true),
      .previewing(error: URLError(.notConnectedToInternet))
    ]
  ) { viewModel in
    LoadingView(viewModel: viewModel)
  }
#endif
