import SwiftUI

/// The progress indicator shown while the nav data is being checked, downloaded, or imported.
struct LoadingProgressView: View {
  let state: NavDataLoader.State

  var body: some View {
    VStack {
      Text(label)
        .padding(.bottom)

      if let fraction {
        ProgressView(value: fraction)
          .progressViewStyle(.linear)
      } else {
        ProgressView()
      }
    }
    .frame(maxWidth: 320)
  }

  private var label: String {
    switch state {
      case .idle, .finished: ""
      case .checking: String(localized: "Checking for the latest data…")
      case .downloading: String(localized: "Downloading navigation data…")
      case .importing: String(localized: "Importing airports…")
    }
  }

  private var fraction: Double? {
    switch state {
      case .downloading(let progress), .importing(let progress): progress
      default: nil
    }
  }
}

#if DEBUG
  #Preview("Importing") {
    LoadingProgressView(state: .importing(progress: 0.4))
  }

  #Preview("Checking") {
    LoadingProgressView(state: .checking)
  }
#endif
