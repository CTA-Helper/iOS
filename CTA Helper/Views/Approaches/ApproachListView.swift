import SwiftData
import SwiftUI

/**
 The middle column of the split view: an airport's approaches, grouped by the runway they
 serve and selectable to drill down to the fixes.
 */
struct ApproachListView: View {
  let airport: Airport

  @Binding var selection: Approach?

  var body: some View {
    List(selection: $selection) {
      ForEach(RunwayGroup.groups(of: airport.approaches)) { group in
        Section(group.title) {
          ForEach(group.approaches) { approach in
            ApproachRow(approach: approach)
              .tag(approach)
              .accessibilityIdentifier("approachRow-\(approach.identifier)")
          }
        }
      }
    }
    .navigationTitle(airport.displayIdentifier)
    .navigationSubtitle(airport.name)
  }
}

/**
 One section of the approach list: the approaches serving a single runway, or — last — the
 circling-only procedures that serve none.
 */
private struct RunwayGroup: Identifiable {
  /// A stable identity for the circling section that no runway designator collides with.
  private static let circlingID = "\u{1}circling"

  /// The runway designator, or a sentinel for the circling section.
  let id: String
  /// The section title as shown in its header.
  let title: LocalizedStringKey
  /// The section's approaches, in Jeppesen chart order.
  let approaches: [Approach]

  /**
   Groups approaches into a section per runway, in runway-designator order, with the
   circling-only procedures appended last.

   - Parameter approaches: the airport's approaches, in any order.
   - Returns: the ordered sections; the circling section is omitted when every approach
     serves a runway.
   */
  static func groups(of approaches: [Approach]) -> [Self] {
    var groups = runwaysServed(by: approaches).map { runway in
      Self(
        id: runway,
        title: "RWY \(runway)",
        approaches: approaches.filter { $0.runway == runway }.inJeppesenChartOrder()
      )
    }

    let circling = approaches.filter { $0.runway == nil }.inJeppesenChartOrder()
    if !circling.isEmpty {
      groups.append(Self(id: circlingID, title: "Circling", approaches: circling))
    }
    return groups
  }

  /// The distinct runways served, in designator order — `"8"` sorts before `"12L"`.
  private static func runwaysServed(by approaches: [Approach]) -> [String] {
    Set(approaches.compactMap(\.runway))
      .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
  }
}

#if DEBUG
  #Preview("Grouped by runway") {
    @Previewable @State var selection: Approach?
    NavigationStack {
      ApproachListView(airport: PreviewData.missoula(), selection: $selection)
    }
    .modelContainer(.preview)
  }

  #Preview("No approaches") {
    @Previewable @State var selection: Approach?
    NavigationStack {
      ApproachListView(airport: PreviewData.sanFrancisco(), selection: $selection)
    }
    .modelContainer(.preview)
  }
#endif
