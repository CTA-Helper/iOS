import SwiftUI

/// A small ring showing how far one step of the nav data update has got.
struct CircularProgressView: View {
  private static let diameter: CGFloat = 16
  private static let lineWidth: CGFloat = 4
  private static let checkmarkDiameter: CGFloat = 20

  let progress: StepProgress

  var body: some View {
    switch progress {
      case .pending:
        Circle()
          .stroke(.gray.opacity(0.25), lineWidth: Self.lineWidth)
          .frame(width: Self.diameter, height: Self.diameter)
          .accessibilityLabel("Pending")
      case .inProgress(let fraction):
        ZStack {
          Circle().stroke(.gray.opacity(0.25), lineWidth: Self.lineWidth)
          Circle()
            .trim(from: 0, to: CGFloat(fraction))
            .stroke(.gray, style: .init(lineWidth: Self.lineWidth, lineCap: .round))
            .rotationEffect(.degrees(-90))
        }
        .frame(width: Self.diameter, height: Self.diameter)
        .accessibilityElement()
        .accessibilityLabel(
          "Progress: \(Double(fraction), format: .percent.precision(.fractionLength(0)))"
        )
      case .indeterminate:
        ProgressView()
          .frame(width: Self.diameter, height: Self.diameter)
      case .complete:
        Image(systemName: "checkmark.circle.fill")
          .resizable()
          .foregroundStyle(.gray)
          .frame(width: Self.checkmarkDiameter, height: Self.checkmarkDiameter)
          .accessibilityLabel("Complete")
    }
  }
}

/// Where one step of the nav data update stands.
enum StepProgress: Equatable {
  /// The step has not started.
  case pending
  /// The step is under way, `progress` of the way through.
  case inProgress(progress: Float)
  /// The step is under way, with no measure of how far.
  case indeterminate
  /// The step has finished.
  case complete
}

#if DEBUG
  #Preview {
    VStack(spacing: 20) {
      CircularProgressView(progress: .pending)
      CircularProgressView(progress: .indeterminate)
      CircularProgressView(progress: .inProgress(progress: 0.3))
      CircularProgressView(progress: .complete)
    }
  }
#endif
