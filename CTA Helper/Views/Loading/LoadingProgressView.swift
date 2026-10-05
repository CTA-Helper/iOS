import SwiftUI
import UIKit

/**
 The update under way: each of its steps in turn — downloading, decompressing, processing — with
 how far the current one has got.

 A store built ahead of time needs no processing, so that step goes straight from pending to
 complete when the update finishes.
 */
struct LoadingProgressView: View {
  private static let logoMaxWidth: CGFloat = 200

  let state: NavDataLoader.State

  var body: some View {
    VStack(spacing: 20) {
      Image("Logo")
        .resizable()
        .scaledToFit()
        .frame(maxWidth: Self.logoMaxWidth, alignment: .center)
        .accessibilityHidden(true)

      Text("Loading the latest airport information…")
        .multilineTextAlignment(.center)

      Grid(alignment: .leading) {
        ForEach(LoadingStep.allCases, id: \.self) { step in
          LoadingStepRow(step: step, progress: step.progress(during: state))
        }
      }

      Text(
        "You can switch to another app while this runs; your \(UIDevice.current.localizedModel) shows its progress and keeps it going."
      )
      .font(.footnote)
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)
      .padding(.horizontal, 20)
    }
    .padding()
  }
}

/// One step's ring and name, the name dimmed until the step starts.
private struct LoadingStepRow: View {
  let step: LoadingStep
  let progress: StepProgress

  private var title: String {
    let isComplete = progress == .complete
    return switch step {
      case .download:
        isComplete ? String(localized: "Downloaded") : String(localized: "Downloading…")
      case .decompress:
        isComplete ? String(localized: "Decompressed") : String(localized: "Decompressing…")
      case .process:
        isComplete ? String(localized: "Processed") : String(localized: "Processing…")
    }
  }

  var body: some View {
    GridRow {
      CircularProgressView(progress: progress)
        .gridColumnAlignment(.center)
      Text(title)
        .foregroundStyle(progress == .pending ? .secondary : .primary)
        .accessibilityIdentifier("loadingStep-\(step.rawValue)")
    }
  }
}

/// The steps an update passes through, in the order it passes through them.
enum LoadingStep: String, CaseIterable, Comparable {
  case download, decompress, process

  private var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }

  static func < (lhs: Self, rhs: Self) -> Bool { lhs.order < rhs.order }

  /**
   The step an update in `state` is on, and how far through it, or `nil` when no step is under
   way.
   */
  private static func current(in state: NavDataLoader.State) -> (step: Self, fraction: Float?)? {
    switch state {
      case .idle, .finished: nil
      case .downloading(let progress): (.download, progress)
      case .decompressing(let progress): (.decompress, progress)
      case .processing(let progress): (.process, progress)
    }
  }

  /// Where this step stands while the update is in `state`.
  func progress(during state: NavDataLoader.State) -> StepProgress {
    if case .finished = state { return .complete }
    guard let current = Self.current(in: state) else { return .pending }

    if self < current.step { return .complete }
    if self > current.step { return .pending }
    return current.fraction.map { .inProgress(progress: $0) } ?? .indeterminate
  }
}

#if DEBUG
  #Preview(
    arguments: [
      NavDataLoader.State.downloading(progress: nil),
      .downloading(progress: 0.6),
      .decompressing(progress: 0.3),
      .processing(progress: 0.8),
      .finished
    ]
  ) { state in
    LoadingProgressView(state: state)
  }
#endif
