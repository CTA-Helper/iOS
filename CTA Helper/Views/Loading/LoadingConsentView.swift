import SwiftUI
import UIKit

/**
 The consent prompt: the download the app is asking for, and what the pilot may do about it.

 Data that is out of date but still installed can be flown for now, so the prompt offers that too;
 an empty store leaves the download as the only choice.
 */
struct LoadingConsentView: View {
  private static let logoMaxWidth: CGFloat = 200

  let viewModel: NavDataLoaderViewModel

  @Environment(\.networkMonitor)
  private var networkMonitor

  private var title: String {
    if viewModel.canSkip {
      return String(localized: "Your navigation data is out of date. Would you like to update it?")
    }
    return String(localized: "You need to download navigation data before you can use this app.")
  }

  var body: some View {
    VStack(spacing: 20) {
      Image("Logo")
        .resizable()
        .scaledToFit()
        .frame(maxWidth: Self.logoMaxWidth, alignment: .center)
        .accessibilityHidden(true)

      Text(title)
        .multilineTextAlignment(.center)

      Text(
        "This must be done the first time the app launches, and about once a month as new navigation data is released. You can switch to another app while it runs; your \(UIDevice.current.localizedModel) shows its progress and keeps it going."
      )
      .font(.footnote)
      .multilineTextAlignment(.leading)
      .padding(.horizontal, 20)

      if networkMonitor?.isExpensive == true {
        Text("Warning: You are on a slow or metered network.")
          .font(.footnote)
          .foregroundStyle(.red)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 20)
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
    .padding()
  }
}

#if DEBUG
  #Preview("No data") {
    LoadingConsentView(viewModel: .previewing())
  }

  #Preview("Out of date") {
    LoadingConsentView(viewModel: .previewing(noData: false, canSkip: true))
  }

  #Preview("Metered network") {
    LoadingConsentView(viewModel: .previewing())
      .environment(\.networkMonitor, NetworkMonitor(reporting: true, isExpensive: true))
  }
#endif
