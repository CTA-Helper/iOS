import SwiftUI

/**
 A blocking error, presented as a sheet: the category description, the specific failure, and
 any recovery suggestion, each as its own element.

 Present it with ``SwiftUICore/View/errorSheet(_:)`` rather than constructing it directly, and only
 when the failure stops the pilot from continuing: it takes over the screen and has to be
 dismissed before anything else can be done.
 */
struct ErrorView: View {
  /// The error to present.
  let error: any Error

  @Environment(\.dismiss)
  private var dismiss

  @ScaledMetric private var symbolSize: CGFloat = 32

  /**
   The gap between the sheet's elements. The failure reason and the recovery suggestion are
   distinct thoughts set as adjacent left-aligned paragraphs with no rule between them, so at
   the default stack spacing they read as one run-on block.
   */
  @ScaledMetric private var spacing: CGFloat = 20

  var body: some View {
    let presentation = ErrorPresentation(error)

    VStack(spacing: spacing) {
      Spacer()

      Image(systemName: "exclamationmark.triangle")
        .font(.system(size: symbolSize))
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      Text(presentation.description)
        .font(.headline)
        .padding(.bottom)
        .accessibilityIdentifier("errorDescription")

      if let failureReason = presentation.failureReason {
        ErrorParagraph(text: failureReason)
      }

      if let recoverySuggestion = presentation.recoverySuggestion {
        ErrorParagraph(text: recoverySuggestion)
          .foregroundStyle(.secondary)
      }

      Button("OK") { dismiss() }
        .padding(.top)
        .accessibilityIdentifier("errorDismissButton")

      Spacer()
    }
    .multilineTextAlignment(.center)
    .padding()
  }
}

/**
 A body paragraph of ``ErrorView``, set as a left-aligned block spanning the sheet's width so
 consecutive paragraphs share one margin rather than each centering on its own length.
 */
private struct ErrorParagraph: View {
  /// The paragraph's contents.
  let text: String

  var body: some View {
    Text(text)
      .multilineTextAlignment(.leading)
  }
}

extension View {
  /// Presents a blocking error as a sheet, clearing `error` once the pilot dismisses it.
  func errorSheet(_ error: Binding<(any Error)?>) -> some View {
    let isPresented = Binding(
      get: { error.wrappedValue != nil },
      set: { if !$0 { error.wrappedValue = nil } }
    )
    return sheet(isPresented: isPresented) {
      if let presented = error.wrappedValue {
        ErrorView(error: presented)
          .presentationDetents([.medium])
      }
    }
  }
}

#if DEBUG
  #Preview("With recovery suggestion") {
    ErrorView(error: NavDataError.httpError(statusCode: 503))
  }

  #Preview("Without recovery suggestion") {
    ErrorView(error: NavDataError.decodingFailed(underlying: URLError(.cannotParseResponse)))
  }
#endif
