import SwiftData
import SwiftUI

/**
 The app's settings, presented as a `Form`: the correction preferences that the fixes screen
 reads, the cycle the imported nav data came from, what the downloaded approach charts occupy,
 and a link to ``AboutView``.

 It carries its own `NavigationStack` so the About link and title work when it is shown in a
 plain sheet or a tab; the presenter should not add another.
 */
struct SettingsView: View {
  var body: some View {
    NavigationStack {
      Form {
        CorrectionsSection()
        NavigationDataSection()
        ChartCacheSection()
        Section {
          NavigationLink {
            AboutView()
          } label: {
            Text("About")
          }
          .accessibilityIdentifier("aboutLink")
        }
      }
      .accessibilityIdentifier("settingsScreen")
      .navigationTitle("Settings")
    }
  }
}

/**
 The correction-preference controls: how corrections are rounded, and whether the formula is
 evaluated above the table's 5,000 ft ceiling.
 */
private struct CorrectionsSection: View {
  @AppStorage(SettingsKey.correctionRounding)
  private var rounding = CorrectionRounding.nearestHundred
  @AppStorage(SettingsKey.extrapolateAboveTable)
  private var extrapolateAboveTable = false

  var body: some View {
    Section {
      Picker("Rounding", selection: $rounding) {
        ForEach(CorrectionRounding.allCases) { rounding in
          Text(Self.label(for: rounding))
            .tag(rounding)
            .accessibilityIdentifier("roundingOption-\(rounding.rawValue)")
        }
      }
      .accessibilityIdentifier("roundingPicker")
    } footer: {
      Text(
        "ENR 1.8 5.e permits rounding each segment correction to the nearest 100 ft or always rounding up. The final segment (DA/MDA) is never rounded down."
      )
    }

    Section {
      Toggle("Extrapolate above 5,000 ft", isOn: $extrapolateAboveTable)
        .accessibilityIdentifier("extrapolateToggle")
    } footer: {
      Text(
        "When off, heights above 5,000 ft are capped at the 5,000 ft column, matching the FAA’s worked example. When on, the correction formula is evaluated at the true height."
      )
    }
  }

  /// The convention's name in the rounding picker.
  private static func label(for rounding: CorrectionRounding) -> String {
    switch rounding {
      case .nearestHundred: String(localized: "Nearest 100 ft")
      case .roundUp: String(localized: "Always Round Up")
    }
  }
}

/**
 The imported AIRAC cycle with the dates it takes effect and expires, or "No data" until a
 cycle has been imported.
 */
private struct NavigationDataSection: View {
  /**
   The cycle dates as the AIRAC calendar publishes them: a plain date, read in UTC.

   The manifest carries both date-only, which decodes to UTC midnight, so resolving them
   against the device's own time zone would report a cycle west of Greenwich as taking
   effect and expiring a day early.
   */
  private static let cycleDate = Date.FormatStyle(timeZone: .gmt).year().month().day()

  @Query private var cycles: [NavDataCycle]

  var body: some View {
    Section("Navigation Data") {
      if let cycle = cycles.first {
        // Read out as one element so the cycle carries as the row's accessibility value.
        LabeledContent("AIRAC Cycle", value: cycle.airacCycle)
          .accessibilityElement()
          .accessibilityLabel("AIRAC Cycle")
          .accessibilityValue(cycle.airacCycle)
          .accessibilityIdentifier("airacCycle")
        LabeledContent("Effective") {
          Text(cycle.effectiveDate, format: Self.cycleDate)
        }
        // A pilot who deferred the update at launch dismissed that prompt for the session, so
        // this row is what is left to say the data is out of date. The label carries the state
        // rather than the color alone, which Dynamic Type and color-blind pilots both need.
        LabeledContent(cycle.hasExpired ? "Expired" : "Expires") {
          Text(cycle.expirationDate, format: Self.cycleDate)
            .foregroundStyle(cycle.hasExpired ? Color.red : Color.primary)
        }
        .accessibilityIdentifier(cycle.hasExpired ? "cycleExpired" : "cycleExpires")
      } else {
        Text("No data")
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("noNavigationData")
      }
    }
  }
}

/**
 How much disk the downloaded approach plates occupy, and the way to reclaim it.

 The plates live in Application Support rather than in Caches, so the system will not quietly
 reclaim them when storage runs short — which is the point, since the pilot downloaded them on
 purpose to have them without a network. That makes the space theirs to manage, and this is
 where they manage it.
 */
private struct ChartCacheSection: View {
  @State private var bytes: UInt64?
  @State private var isClearing = false

  @Environment(\.chartStore)
  private var chartStore

  @AppStorage(SettingsKey.chartAirports)
  private var chartAirports = AirportIDList()

  var body: some View {
    Section {
      LabeledContent("Downloaded") {
        if let bytes {
          Text(Int64(bytes), format: .byteCount(style: .file))
        } else {
          ProgressView()
        }
      }
      .accessibilityElement()
      .accessibilityLabel("Downloaded charts")
      .accessibilityValue(bytes.map { Int64($0).formatted(.byteCount(style: .file)) } ?? "")
      .accessibilityIdentifier("chartCacheSize")

      Button("Clear Downloaded Charts", role: .destructive, action: clear)
        .disabled(bytes == 0 || bytes == nil || isClearing)
        .accessibilityIdentifier("clearChartsButton")
    } header: {
      Text("Approach Charts")
    } footer: {
      ChartCacheNote(airportCount: chartAirports.ids.count, bytes: bytes)
    }
    .task { await measure() }
  }

  private func measure() async {
    bytes = await chartStore?.totalBytes() ?? 0
  }

  private func clear() {
    isClearing = true
    Task {
      try? await chartStore?.removeAll()
      chartAirports = AirportIDList()
      await measure()
      isClearing = false
    }
  }
}

/**
 What the pilot needs to know about the charts they have downloaded.

 A new AIRAC cycle discards every plate of the one it replaces — their URLs are dead the moment
 the cycle turns over — and nothing re-fetches them, because nothing downloads a chart without
 being asked. Said plainly here, that is a cycle-turn chore; unsaid, it is the feature quietly
 reverting to nothing every 28 days and the pilot finding out airborne.
 */
private struct ChartCacheNote: View {
  let airportCount: Int
  let bytes: UInt64?

  var body: some View {
    if airportCount > 0, bytes == 0 {
      Text(
        "Updating the navigation data discarded the charts for \(airportCount, format: .number) airports, because charts are published per AIRAC cycle. Download them again from an airport’s approach list."
      )
      .accessibilityIdentifier("chartsDiscardedNote")
    } else {
      Text(
        "Charts are downloaded only when you ask for them, and are kept until you clear them or their AIRAC cycle is superseded."
      )
    }
  }
}

#if DEBUG
  #Preview("No Cycle") {
    SettingsView()
      .modelContainer(.makeInMemory())
  }

  #Preview("Current Cycle") {
    let container = ModelContainer.makeInMemory()
    container.mainContext.insert(PreviewData.navDataCycle())
    return SettingsView()
      .modelContainer(container)
  }

  #Preview("Expired Cycle") {
    let container = ModelContainer.makeInMemory()
    container.mainContext.insert(PreviewData.navDataCycle(expired: true))
    return SettingsView()
      .modelContainer(container)
  }
#endif
