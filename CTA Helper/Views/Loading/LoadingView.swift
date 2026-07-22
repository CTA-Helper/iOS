import SwiftUI

/**
 The first-run screen shown while the store is empty: it explains the one-time download and,
 once the pilot consents, shows import progress.
 */
struct LoadingView: View {
  @Bindable var viewModel: NavDataLoaderViewModel

  var body: some View {
    VStack {
      Spacer()

      VStack {
        Text("CTA Helper")
          .font(.largeTitle.bold())
        Text("Cold temperature altitude corrections for instrument approaches.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }

      Spacer()

      switch viewModel.state {
        case .idle:
          Button("Download Navigation Data") {
            viewModel.load()
          }
          .accessibilityIdentifier("downloadNavDataButton")
        default:
          LoadingProgressView(state: viewModel.state)
      }

      Spacer()
    }
    .padding()
    // A failed first-run download leaves the pilot with no data and nothing to do but retry, so
    // it blocks.
    .errorSheet($viewModel.error)
  }
}

#if DEBUG
  #Preview("Idle") {
    LoadingView(viewModel: NavDataLoaderViewModel(container: .preview))
  }

  #Preview("Downloading") {
    LoadingView(viewModel: .previewing(state: .downloading(progress: 0.6)))
  }

  #Preview("Error") {
    LoadingView(viewModel: .previewing(state: .idle, error: URLError(.notConnectedToInternet)))
  }
#endif
