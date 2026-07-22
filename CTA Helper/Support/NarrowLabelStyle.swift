import SwiftUI

/**
 A label style that sets the icon tight against the title, closer than the generous gap the
 automatic style leaves.

 Apply it with ``SwiftUI/LabelStyle/narrow`` rather than constructing it directly. Reach for it
 in compact contexts — a dense list row, an inline status line, a caption — where the default
 icon-to-title gap reads as two separate elements instead of one badge. Leave the automatic
 style in place everywhere the label stands on its own, so it keeps the platform's alignment
 with neighboring rows.

 The gap scales with Dynamic Type, so it stays proportionate at accessibility text sizes.
 */
struct NarrowLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    NarrowLabel(configuration: configuration)
  }
}

/**
 The body of a ``NarrowLabelStyle`` label.

 The style itself cannot hold the `@ScaledMetric`: SwiftUI tracks dynamic properties on views,
 not on style values, so the scaled gap lives here.
 */
private struct NarrowLabel: View {
  let configuration: NarrowLabelStyle.Configuration

  @ScaledMetric private var spacing: CGFloat = 2

  var body: some View {
    HStack(spacing: spacing) {
      configuration.icon
      configuration.title
    }
  }
}

extension LabelStyle where Self == NarrowLabelStyle {
  /**
   A label style that sets the icon tight against the title, for compact and dense views.

   See ``NarrowLabelStyle`` for when to prefer it over the automatic style.
   */
  static var narrow: Self { NarrowLabelStyle() }
}

#if DEBUG
  #Preview("Narrow beside automatic") {
    List {
      Label("Missoula Montana", systemImage: "snowflake")
        .labelStyle(.narrow)
      Label("Missoula Montana", systemImage: "snowflake")
    }
  }

  #Preview("Accessibility text size") {
    List {
      Label("Missoula Montana", systemImage: "snowflake")
        .labelStyle(.narrow)
      Label("Missoula Montana", systemImage: "snowflake")
    }
    .environment(\.dynamicTypeSize, .accessibility3)
  }
#endif
