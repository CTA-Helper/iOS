import SwiftUI

/// The progress indicator shown while the nav data is being downloaded, decompressed, or written.
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
      case .downloading: String(localized: "Downloading navigation data…")
      case .decompressing: String(localized: "Decompressing navigation data…")
      case .processing: String(localized: "Importing airports…")
    }
  }

  private var fraction: Float? {
    switch state {
      case .downloading(let progress), .decompressing(let progress), .processing(let progress):
        progress
      default: nil
    }
  }
}

#if DEBUG
  #Preview("Downloading") {
    LoadingProgressView(state: .downloading(progress: nil))
  }

  #Preview("Importing") {
    LoadingProgressView(state: .processing(progress: 0.4))
  }
#endif
