import SwiftUI

/**
 Information about the app: its name and version, what it does, the FAA reference it
 implements, and an advisory-use disclaimer.
 */
struct AboutView: View {
  var body: some View {
    Form {
      Section {
        VStack(alignment: .leading) {
          Text("CTA Helper")
            .font(.headline)
          Text(AppInfo.versionSummary)
            .font(.subheadline)
            .padding(.bottom)
            .accessibilityIdentifier("appVersion")
          Text(
            "CTA Helper applies FAA cold temperature altitude corrections to the altitudes of an instrument approach, following the method published in AIP ENR 1.8."
          )
        }
      }

      Section {
        Text(
          "This app is for situational awareness and planning only. It is not for primary navigation. Always verify every correction independently, and read the DA/MDA and all altitudes from the official approach plate before you fly them."
        )
        .font(.footnote)
      }

      Section {
        Link("Privacy Policy", destination: AppInfo.privacyPolicyURL)
          .accessibilityIdentifier("privacyPolicyLink")
        Link("Support", destination: AppInfo.supportURL)
          .accessibilityIdentifier("supportLink")
      }
    }
    .accessibilityIdentifier("aboutScreen")
    .navigationTitle("About CTA Helper")
  }
}

/// App identity read from the bundle, plus the pages a pilot can reach from here.
private enum AppInfo {
  /// The privacy policy App Store Connect points at, kept alongside the source it describes.
  static let privacyPolicyURL = URL(
    string: "https://github.com/CTA-Helper/iOS/blob/main/PRIVACY.md"
  )!

  /// Where to report a bad correction, a missing approach, or anything else.
  static let supportURL = URL(string: "https://github.com/CTA-Helper/iOS/issues")!

  /// A "Version x.y (build)" summary from the bundle's short version and build numbers.
  static var versionSummary: String {
    let info = Bundle.main.infoDictionary
    let version = info?["CFBundleShortVersionString"] as? String ?? "—"
    let build = info?["CFBundleVersion"] as? String ?? "—"
    return String(localized: "Version \(version) (\(build))")
  }
}

#if DEBUG
  #Preview {
    NavigationStack {
      AboutView()
    }
  }
#endif
