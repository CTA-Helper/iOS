import SwiftUI

extension EnvironmentValues {
  /// The shared METAR loader, or `nil` when weather auto-fill is unavailable (previews, tests).
  @Entry var metarLoader: METARLoader?
  /// The shared network monitor, or `nil` when weather auto-fill is unavailable.
  @Entry var networkMonitor: NetworkMonitor?
}
