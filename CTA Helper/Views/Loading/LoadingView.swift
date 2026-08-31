import SwiftUI

/**
 The screen shown while the store is not fit to fly: it explains the download the app needs and,
 once the pilot consents, shows import progress.

 On first run the store is empty and the download is the only way past it. When the imported cycle
 has expired, the same screen offers the update alongside the choice to fly the stored cycle for
 now.
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
          LoadingConsentView(viewModel: viewModel)
        default:
          LoadingProgressView(state: viewModel.state)
      }

      Spacer()
    }
    .padding()
    // A failed first-run download leaves the pilot with no data and nothing to do but retry, so
    // it blocks. A failed update blocks the same way, and dismissing it returns them to the
    // choice to keep flying the cycle they already have.
    .errorSheet($viewModel.error)
  }
}

/**
 The consent prompt: the download the app is asking for, and what the pilot may do about it.

 An expired cycle that is still imported can be flown for now, so it offers that too; an empty
 store leaves the download as the only choice.
 */
private struct LoadingConsentView: View {
  let viewModel: NavDataLoaderViewModel

  var body: some View {
    VStack {
      if viewModel.canSkip {
        Text("Your navigation data has expired. Download the current cycle?")
          .multilineTextAlignment(.center)
          .padding(.bottom)
      }

      HStack(spacing: 20) {
        Button("Download Navigation Data") {
          viewModel.load()
        }
        .accessibilityIdentifier("downloadNavDataButton")

        if viewModel.canSkip {
          Button("Defer Until Later") {
            viewModel.loadLater()
          }
          .accessibilityIdentifier("deferNavDataButton")
        }
      }
    }
  }
}

#if DEBUG
  #Preview("Idle") {
    LoadingView(viewModel: NavDataLoaderViewModel(container: .preview))
  }

  #Preview("Out of Date") {
    LoadingView(viewModel: .previewing(state: .idle, hasData: true))
  }

  #Preview("Downloading") {
    LoadingView(viewModel: .previewing(state: .downloading(progress: 0.6)))
  }

  #Preview("Error") {
    LoadingView(viewModel: .previewing(state: .idle, error: URLError(.notConnectedToInternet)))
  }
#endif
