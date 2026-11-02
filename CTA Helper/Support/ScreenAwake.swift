import SwiftUI
import UIKit

/**
 A modifier that holds the display on while a condition holds, for as long as the view it is
 applied to is on screen.

 Apply it with ``SwiftUICore/View/keepsScreenAwake(_:)`` rather than constructing it directly.
 Reach for it on a screen the pilot reads without touching — one mounted on the yoke, consulted
 with both hands on the controls — where the auto-lock the system would otherwise apply demands an
 unlock at exactly the wrong moment. Everywhere else, leave the device's own timer alone: it is
 the pilot's battery.

 The idle timer is a per-app setting, and the system stops honoring it while the app is not
 frontmost, so a backgrounded app sleeps the display on the system's schedule with no help from
 here. What matters is that exactly one view decides it. Two holders that come and go — the
 screen the pilot reads, built once per layout — have no order SwiftUI guarantees between one's
 `onDisappear` and the other's `onAppear`, and the last to run wins. So the hold goes on a view
 that outlives the screens it covers, and follows a condition naming whether one is showing.
 */
struct ScreenAwake: ViewModifier {
  /// Whether the display is held on.
  let isActive: Bool

  func body(content: Content) -> some View {
    content
      .onChange(of: isActive, initial: true) { UIApplication.shared.isIdleTimerDisabled = $1 }
      .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
  }
}

extension View {
  /**
   Holds the display on while `isActive`, restoring the system's auto-lock when it stops being so
   or when this view goes away.

   See ``ScreenAwake`` for when a screen earns this.
   */
  func keepsScreenAwake(_ isActive: Bool) -> some View { modifier(ScreenAwake(isActive: isActive)) }
}
