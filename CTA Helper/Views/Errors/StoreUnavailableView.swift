import SwiftUI

/**
 What the app shows when it cannot open its navigation database at all.

 An unreadable store is discarded and rebuilt rather than reported, since every airport in it
 is re-downloaded on the next launch. Reaching this screen means the rebuild failed too — in
 practice a full disk or an unwritable container — and there is nothing left to run against.
 The failure itself goes to the log and to crash reporting; none of it is prose a pilot can act
 on, so what is shown here is the one thing they can do about it.
 */
struct StoreUnavailableView: View {
  @ScaledMetric private var symbolSize: CGFloat = 32

  /// The gap between the message's elements, which read as separate thoughts rather than a block.
  @ScaledMetric private var spacing: CGFloat = 20

  var body: some View {
    VStack(spacing: spacing) {
      Image(systemName: "exclamationmark.triangle")
        .font(.system(size: symbolSize))
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      Text("CTA Helper can’t open its navigation database.")
        .font(.headline)
        .accessibilityIdentifier("storeUnavailableDescription")

      Text(
        "This usually means your device is out of storage. Free up some space and open CTA Helper again."
      )
      .foregroundStyle(.secondary)
    }
    .multilineTextAlignment(.center)
    .padding()
    .accessibilityIdentifier("storeUnavailableScreen")
  }
}

#if DEBUG
  #Preview {
    StoreUnavailableView()
  }
#endif
