import SwiftUI
import UIKit

/**
 The Nearest tab's account of a refusal, and what the pilot can do about it.

 The three refusals are three different situations, and only one of them is fixable where the
 button goes: `UIApplication.openSettingsURLString` opens this app's own Settings page, which
 carries the app's location switch but neither the device-wide one nor a restriction. So the
 device-wide case names the full path in words, and a restriction offers no button at all.
 */
struct LocationRefusedView: View {
  let reason: Reason

  var body: some View {
    ContentUnavailableView {
      Label(reason.title, systemImage: "location.slash")
    } description: {
      Text(reason.explanation)
    } actions: {
      if reason.opensSettings, let settingsURL = URL(string: UIApplication.openSettingsURLString) {
        Button("Open Settings") {
          UIApplication.shared.open(settingsURL)
        }
      }
    }
    .accessibilityIdentifier(reason.accessibilityIdentifier)
  }

  /// Why location was refused, insofar as it changes what the pilot can do about it.
  enum Reason {
    /// This app was denied access.
    case app
    /// Location Services is off for the whole device.
    case deviceWide
    /// Parental restrictions or device management prevent access.
    case restricted

    var title: String {
      switch self {
        case .app: String(localized: "Location Access Denied")
        case .deviceWide: String(localized: "Location Services Is Off")
        case .restricted: String(localized: "Location Access Restricted")
      }
    }

    var explanation: String {
      switch self {
        case .app:
          String(
            localized:
              "CTA Helper doesn’t have permission to use your location. Allow it in Settings to see nearby airports."
          )
        case .deviceWide:
          String(
            localized:
              "Location Services is turned off for this device. Turn it on in Settings → Privacy & Security → Location Services to see nearby airports."
          )
        case .restricted:
          String(
            localized:
              "Location access is restricted on this device, so nearby airports aren’t available. Screen Time or a device management profile usually sets this."
          )
      }
    }

    /// Whether this app's Settings page holds the switch that would lift the refusal.
    var opensSettings: Bool { self != .restricted }

    var accessibilityIdentifier: String {
      switch self {
        case .app: "locationOffNotice"
        case .deviceWide: "locationServicesOffNotice"
        case .restricted: "locationRestrictedNotice"
      }
    }
  }
}

#if DEBUG
  #Preview("Denied") {
    LocationRefusedView(reason: .app)
  }

  #Preview("Services Off") {
    LocationRefusedView(reason: .deviceWide)
  }

  #Preview("Restricted") {
    LocationRefusedView(reason: .restricted)
  }
#endif
