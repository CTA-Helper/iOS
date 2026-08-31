import SwiftUI

extension EnvironmentValues {
  /// The shared approach plate store, or `nil` where charts are unavailable (previews).
  @Entry var chartStore: ChartStore?
}
