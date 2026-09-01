import SwiftUI
import UIKit

/**
 A modifier that holds the display on for as long as the view it is applied to is on screen.

 Apply it with ``SwiftUICore/View/keepsScreenAwake()`` rather than constructing it directly. Reach
 for it on a screen the pilot reads without touching — one mounted on the yoke, consulted with
 both hands on the controls — where the auto-lock the system would otherwise apply demands an
 unlock at exactly the wrong moment. Everywhere else, leave the device's own timer alone: it is
 the pilot's battery.

 The idle timer is a per-app setting, and the system stops honoring it while the app is not
 frontmost, so a backgrounded app sleeps the display on the system's schedule with no help from
 here. What matters is that every exit restores it, and `onDisappear` covers them alike: the pop
 that leaves the screen where the panes are stacked, and the cleared selection that replaces it
 in the detail pane where they sit side by side. A screen pushed over this one leaves the timer
 set, since the view beneath it has not gone anywhere — a detour rather than an exit, and
 holding the display on across it is what a pilot coming back to the numbers wants.
 */
struct ScreenAwake: ViewModifier {
  func body(content: Content) -> some View {
    content
      .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
      .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
  }
}

extension View {
  /**
   Holds the display on for as long as this view is on screen, restoring the system's auto-lock
   when it goes away.

   See ``ScreenAwake`` for when a screen earns this.
   */
  func keepsScreenAwake() -> some View { modifier(ScreenAwake()) }
}
