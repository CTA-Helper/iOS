import SwiftUI

/**
 What the chart screen shows in place of a plate, and why.

 Every case here is a state the app knew about before the pilot tapped anything — except a fetch
 that failed, which is the one it could not. Each says what is true and what would change it,
 because "no chart" with no reason is indistinguishable from a broken app.
 */
struct ChartUnavailableView: View {
  /// Why there is no plate to draw.
  let reason: Reason

  /// What to run when the pilot asks to try the fetch again, where trying again could help.
  let retry: (() -> Void)?

  var body: some View {
    ContentUnavailableView {
      Label(title, systemImage: icon)
    } description: {
      Text(message)
    } actions: {
      if let retry {
        Button("Try Again", action: retry)
          .accessibilityIdentifier("retryChart")
      }
    }
    .accessibilityIdentifier("chartUnavailable")
  }

  private var title: String {
    switch reason {
      case .unpublished: String(localized: "No Chart Published")
      case .offline: String(localized: "Not Downloaded")
      case .supersededCycle: String(localized: "Navigation Data Out of Date")
      case .failed: String(localized: "Couldn’t Load the Chart")
    }
  }

  private var icon: String {
    switch reason {
      case .unpublished: "doc"
      case .offline: "wifi.slash"
      case .supersededCycle: "calendar.badge.exclamationmark"
      case .failed: "exclamationmark.triangle"
    }
  }

  private var message: String {
    switch reason {
      case .unpublished:
        String(localized: "The navigation data publishes no approach plate for this procedure.")
      case .offline:
        String(
          localized:
            "This chart is not on your device, and there is no network to fetch it over. Download an airport’s charts while you have a connection to read them without one."
        )
      case .supersededCycle:
        String(
          localized:
            "Charts are published per AIRAC cycle, and the cycle on your device has been superseded, so its charts are no longer available. Update your navigation data to read them."
        )
      case let .failed(error):
        Self.message(for: error)
    }
  }

  /// What a failed fetch says: the specific failure, and what the pilot can do about it.
  private static func message(for error: any Error) -> String {
    let presentation = ErrorPresentation(error)
    let parts = [presentation.failureReason, presentation.recoverySuggestion].compactMap(\.self)
    return parts.isEmpty ? presentation.description : parts.joined(separator: " ")
  }

  /// Why the chart screen has no plate to draw.
  enum Reason {
    /// The navigation data publishes no chart for this approach, as it does for 584 of them.
    case unpublished
    /// The plate is not on the device, and there is no network to fetch it over.
    case offline
    /// The imported cycle has been superseded, so the plate's URL is dead.
    case supersededCycle
    /// The fetch was attempted and failed.
    case failed(any Error)
  }
}

#if DEBUG
  #Preview("Unpublished") {
    ChartUnavailableView(reason: .unpublished, retry: nil)
  }

  #Preview("Offline") {
    ChartUnavailableView(reason: .offline, retry: nil)
  }

  #Preview("Superseded cycle") {
    ChartUnavailableView(reason: .supersededCycle, retry: nil)
  }

  #Preview("Failed") {
    ChartUnavailableView(reason: .failed(ChartError.httpError(statusCode: 503)), retry: {})
  }
#endif
