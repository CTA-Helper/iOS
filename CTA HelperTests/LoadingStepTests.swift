import Testing

@testable import CTA_Helper

/**
 The loading screen draws each step of an update from the updater's single state, so which steps
 read as done, under way or still to come has to follow from where that state is — including a
 prebuilt store, which finishes straight from decompressing and never processes.
 */
struct `Loading steps` {
  @Test(
    arguments: [
      (NavDataLoader.State.idle, [StepProgress.pending, .pending, .pending]),
      (.downloading(progress: nil), [.indeterminate, .pending, .pending]),
      (.downloading(progress: 0.5), [.inProgress(progress: 0.5), .pending, .pending]),
      (.decompressing(progress: 0.25), [.complete, .inProgress(progress: 0.25), .pending]),
      (.processing(progress: nil), [.complete, .complete, .indeterminate]),
      (.finished, [.complete, .complete, .complete])
    ]
  )
  func `marks the steps before the current one complete and those after it pending`(
    state: NavDataLoader.State,
    expected: [StepProgress]
  ) {
    #expect(LoadingStep.allCases.map { $0.progress(during: state) } == expected)
  }
}
