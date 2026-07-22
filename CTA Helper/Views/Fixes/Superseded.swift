import SwiftUI

/**
 Crosses out a value a cold temperature correction supersedes, the way a pilot strikes one on
 a chart: a single diagonal slash rather than a horizontal rule. The struck value recedes to a
 lighter shade so the operative corrected value beside it reads first.
 The slash is drawn and tinted unconditionally and hidden when it does not apply, rather than
 branching on `isSuperseded`. Branching would give the two states different structural
 identities, and a struck value that is also a text field then thrashes: taking focus clears
 the slash, rebuilding the field, which drops first responder, which restores the slash, which
 rebuilds the field — a loop that hangs the app on a tap.
 */
private struct Superseded: ViewModifier {
  let isSuperseded: Bool

  func body(content: Content) -> some View {
    content
      .foregroundStyle(isSuperseded ? AnyShapeStyle(.secondary) : AnyShapeStyle(.foreground))
      .overlay {
        DiagonalSlash()
          .stroke(.secondary, style: StrokeStyle(lineWidth: 1, lineCap: .round))
          .padding(.horizontal, -2)
          .opacity(isSuperseded ? 1 : 0)
      }
  }
}

/**
 A rule from the lower left corner to the upper right, the stroke that crosses out a
 superseded value.
 */
private struct DiagonalSlash: Shape {
  func path(in rect: CGRect) -> Path {
    Path { slash in
      slash.move(to: CGPoint(x: rect.minX, y: rect.maxY))
      slash.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
    }
  }
}

extension View {
  /**
   Crosses the view out as a value a correction has superseded.

   - Parameter isSuperseded: whether the correction applies; `false` leaves the view untouched,
     so a caller can strike a value conditionally without branching its layout.
   */
  func superseded(_ isSuperseded: Bool = true) -> some View {
    modifier(Superseded(isSuperseded: isSuperseded))
  }
}

#if DEBUG
  #Preview("Superseded and plain") {
    List {
      LabeledContent("Corrected") {
        Text(9400, format: .number).monospacedDigit().superseded()
      }
      LabeledContent("Uncorrected") {
        Text(9400, format: .number).monospacedDigit().superseded(false)
      }
    }
  }
#endif
