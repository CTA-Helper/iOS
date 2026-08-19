import MeasurementKit
import MeasurementKitUI
import SwiftData
import SwiftUI

/**
 The temperatures the reported-temperature slider spans.

 The correction tables stop at −50 °C, and above +10 °C no US Cold Temperature Airport
 restriction is in force. An observation outside that span is pinned to the nearer end rather
 than left off the track, where the slider could not show it.
 */
private let reportedTemperatureRange =
  Measurement<UnitTemperature>.celsius(-50)...Measurement<UnitTemperature>.celsius(10)

/**
 The app's signature screen: every fix of an approach with its published altitude and the
 applied cold temperature correction.

 Above the list sit the controls that drive the correction — the reported temperature and the
 correction method — and, where the airport's station is reporting, a link to the METAR that
 temperature was filled from. The list itself renders a section per segment of the approach,
 in the order they are flown; a segment coding several transitions shows one at a time, chosen
 from the picker in its header, followed by the legs those transitions converge onto. Each row
 shows its corrected altitude via ``AltitudeView``, and the final segment closes with the
 pilot-entered DA/MDA, corrected like any other fix.

 Warmer than the airport's Cold Temperature Airport restriction there is nothing to correct,
 so everything below the temperature slider collapses to a note saying so. An airport that is
 not a CTA has no such threshold and is corrected at any temperature.

 The correction is a cheap pure computation, so the view rebuilds an ``ApproachCorrector``
 from its inputs each time rather than caching it. The minimums are deliberately not
 persisted: they are cleared every time the screen appears.
 */
struct FixListView: View {
  /// The airport whose elevation and cold temperature restriction the correction uses.
  let airport: Airport
  /// The approach whose fixes are listed.
  let approach: Approach

  @State private var reportedTemperature: Measurement<UnitTemperature>
  @State private var minimums: Measurement<UnitLength>?
  /**
   The station's latest METAR, once fetched — the source of the reported temperature, and the
   subject of the weather section.
   */
  @State private var observation: METARObservation?
  /**
   The transition each segment is showing, where the pilot has chosen one. A segment with no
   entry shows the first transition it codes.
   */
  @State private var selectedTransitions: [Segment: String] = [:]

  @FocusState private var isEditingMinimums: Bool

  @Environment(\.metarLoader)
  private var metarLoader
  @Environment(\.networkMonitor)
  private var networkMonitor

  @AppStorage(SettingsKey.correctionRounding)
  private var rounding = CorrectionRounding.nearestHundred

  @AppStorage(SettingsKey.extrapolateAboveTable)
  private var extrapolateAboveTable = false

  @AppStorage(SettingsKey.correctionMethod)
  private var method = CorrectionMethod.allSegments

  var body: some View {
    List {
      Section {
        TemperatureControl(reportedTemperature: $reportedTemperature)
        if let observation {
          WeatherLink(observation: observation)
        }
      }
      if isCorrectionRequired {
        MethodPicker(method: $method)
        SegmentSections(
          fixes: approach.fixes,
          corrector: corrector,
          selectedTransitions: $selectedTransitions,
          minimums: $minimums,
          isEditingMinimums: $isEditingMinimums
        )
      } else {
        NoCorrectionNotice()
      }
    }
    .toolbar {
      // The number pad has no return key, and the minimums sit at the foot of the list, so
      // without this the keyboard covers the corrected value it was opened to produce.
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") { isEditingMinimums = false }
          .accessibilityIdentifier("dismissKeyboard")
      }
    }
    .navigationTitle(approach.name)
    .onAppear(perform: clearEntries)
    .task(id: approach.identifier) { await loadObservation() }
  }

  /**
   Whether the reported temperature calls for a correction at all: at or below the airport's
   Cold Temperature Airport restriction, or at any temperature at an airport that is not a CTA.
   */
  private var isCorrectionRequired: Bool {
    guard let coldTemperature = airport.coldTemperature else { return true }
    return reportedTemperature <= coldTemperature.restrictionTemperature
  }

  /// The correction in force, rebuilt from the current controls.
  private var corrector: ApproachCorrector {
    ApproachCorrector(
      elevation: airport.elevation,
      referenceAltitudes: approach.referenceAltitudes,
      reportedTemperature: reportedTemperature,
      coldTemperature: airport.coldTemperature,
      method: method,
      rounding: rounding,
      extrapolateAboveTable: extrapolateAboveTable,
      minimumsAltitude: minimums
    )
  }

  /**
   Creates the fix list for an approach.

   - Parameters:
     - airport: the airport the approach serves.
     - approach: the approach to list.
     - initialTemperature: the temperature the slider starts at, so a fetched METAR temperature
       can be injected later; the pilot then adjusts it with the slider.
   */
  init(
    airport: Airport,
    approach: Approach,
    initialTemperature: Measurement<UnitTemperature> = .celsius(0)
  ) {
    self.airport = airport
    self.approach = approach
    _reportedTemperature = State(initialValue: initialTemperature)
  }

  /**
   Discard the entries that belong to the approach being left: the typed minimums, and the
   transition chosen for each segment.
   */
  private func clearEntries() {
    minimums = nil
    selectedTransitions = [:]
  }

  /**
   Fetch the airport's latest METAR when the network is available, and fill the reported
   temperature from it. Runs once per approach; the pilot's later slider adjustments are
   preserved.

   An observation warmer or colder than the slider spans is pinned to the nearer end. Off the
   track the thumb is unreadable and the value is one the control cannot express, and a
   temperature above the span is warmer than any restriction — so the pinned reading and the
   true one call for the same correction: none.
   */
  private func loadObservation() async {
    guard let metarLoader, let networkMonitor, networkMonitor.isConnected else { return }
    observation = await metarLoader.observation(for: airport.metarStationID)
    guard let temperature = observation?.temperature else { return }
    reportedTemperature = temperature.roundedToWholeCelsius.clamped(to: reportedTemperatureRange)
  }
}

/**
 The way through to the METAR the reported temperature was filled from: the reporting station
 over how long ago it filed, so the pilot can weigh the reading before flying it.
 */
private struct WeatherLink: View {
  let observation: METARObservation

  var body: some View {
    NavigationLink {
      WeatherView(observation: observation)
    } label: {
      VStack(alignment: .leading, spacing: 2) {
        ReportingStation(observation: observation)
        ObservationAge(date: observation.date)
      }
    }
    .accessibilityIdentifier("weatherLink")
  }
}

/// The reporting station, with the temperature it filed where it filed one.
private struct ReportingStation: View {
  let observation: METARObservation

  var body: some View {
    if let temperature = observation.temperature {
      Text(
        "METAR (\(temperature.converted(to: .celsius), format: .reportedTemperature))"
      )
    } else {
      Text(observation.stationID)
    }
  }
}

/**
 How long ago the observation was taken, set under the station in smaller type than the line it
 qualifies — an hour-old reading is still worth filling from, but the pilot should see its age.
 */
private struct ObservationAge: View {
  let date: Date

  @ScaledMetric(relativeTo: .body)
  private var size = 13.0

  var body: some View {
    Text(date, format: .relative(presentation: .numeric))
      .font(.system(size: size))
      .foregroundStyle(.secondary)
  }
}

/**
 The reported-temperature slider, in °C, with the selected value above it in the same list row
 so nothing divides the reading from the control that sets it.
 */
private struct TemperatureControl: View {
  /**
   The span of ``reportedTemperatureRange`` in the bare degrees `Slider` is defined over.

   The track is the one thing on this screen that cannot hold a measurement — `Slider` works in
   `BinaryFloatingPoint` — so the scalar is derived here and goes no further.
   */
  private static let trackC: ClosedRange<Double> = {
    let coldest = reportedTemperatureRange.lowerBound.converted(to: .celsius).value
    let warmest = reportedTemperatureRange.upperBound.converted(to: .celsius).value
    return coldest...warmest
  }()

  @Binding var reportedTemperature: Measurement<UnitTemperature>

  var body: some View {
    VStack(alignment: .leading) {
      LabeledContent("Reported Temperature") {
        Text(reportedTemperature, format: .reportedTemperature)
          .monospacedDigit()
      }
      Slider(value: $reportedTemperature.scalar(in: .celsius), in: Self.trackC, step: 1) {
        Text("Reported Temperature")
      } minimumValueLabel: {
        // The ends of the track are labelled in the same unit as the reading above it, so the
        // span the slider covers is read off the control rather than inferred from where the
        // thumb stops.
        Text(reportedTemperatureRange.lowerBound, format: .reportedTemperature)
      } maximumValueLabel: {
        Text(reportedTemperatureRange.upperBound, format: .reportedTemperature)
      }
      .accessibilityIdentifier("reportedTemperatureSlider")
    }
  }
}

/// The menu choosing between the All Segments and Individual Segments methods.
private struct MethodPicker: View {
  @Binding var method: CorrectionMethod

  var body: some View {
    Section {
      Picker("Correction Method", selection: $method) {
        ForEach(CorrectionMethod.allCases) { method in
          Text(Self.label(for: method))
            .tag(method)
            .accessibilityIdentifier("correctionMethodOption-\(method.rawValue)")
        }
      }
      .pickerStyle(.menu)
      .accessibilityIdentifier("correctionMethodPicker")
    }
  }

  /// The method's name in the menu.
  private static func label(for method: CorrectionMethod) -> String {
    switch method {
      case .allSegments: String(localized: "All Segments")
      case .individualSegments: String(localized: "Individual Segments")
    }
  }
}

/**
 The fix list proper: one section per segment the approach codes, in the order they are flown,
 with the pilot-entered minimums closing the final segment.
 */
private struct SegmentSections: View {
  let fixes: [Fix]
  let corrector: ApproachCorrector
  @Binding var selectedTransitions: [Segment: String]
  @Binding var minimums: Measurement<UnitLength>?
  @FocusState.Binding var isEditingMinimums: Bool

  var body: some View {
    ForEach(groups) { group in
      SegmentSection(
        group: group,
        selectedTransition: transitionBinding(for: group),
        corrector: corrector,
        minimums: $minimums,
        isEditingMinimums: $isEditingMinimums
      )
    }
  }

  /// The sections to render, over the approach's fixes plus the minimums pseudo-fix.
  private var groups: [FixGrouping.Group<FixListEntry>] {
    FixGrouping.groups(
      fixes.map(FixListEntry.fix) + [.minimums],
      segment: \.segment,
      transition: \.transition,
      sequence: \.sequence
    )
  }

  /**
   The transition a segment is showing: the pilot's choice, or the first transition it codes
   until they make one. Deriving the default rather than seeding it keeps the selection in step
   with the approach on screen without an initialization pass.
   */
  private func transitionBinding(for group: FixGrouping.Group<FixListEntry>) -> Binding<String?> {
    Binding(
      get: { selectedTransitions[group.segment] ?? group.transitions.first?.name },
      set: { selectedTransitions[group.segment] = $0 }
    )
  }
}

/**
 One segment's section: the legs flown on the selected transition and the legs they converge
 onto, headed by the segment and the picker that chooses between its transitions.
 */
private struct SegmentSection: View {
  let group: FixGrouping.Group<FixListEntry>
  @Binding var selectedTransition: String?
  let corrector: ApproachCorrector
  @Binding var minimums: Measurement<UnitLength>?
  @FocusState.Binding var isEditingMinimums: Bool

  var body: some View {
    Section {
      ForEach(group.elements(via: selectedTransition)) { entry in
        CorrectedRow(
          entry: entry,
          corrector: corrector,
          minimums: $minimums,
          isEditingMinimums: $isEditingMinimums
        )
      }
    } header: {
      SegmentHeader(group: group, selectedTransition: $selectedTransition)
    }
  }
}

/**
 A section's header: the segment's name, with the transition picker beside it where the segment
 codes more than one. A segment coding a single transition names it in the header instead, since
 a menu of one choice is a control that cannot be used.
 */
private struct SegmentHeader: View {
  let group: FixGrouping.Group<FixListEntry>
  @Binding var selectedTransition: String?

  var body: some View {
    if group.transitions.count > 1 {
      HStack {
        Text(group.segment.label)
        Spacer()
        TransitionPicker(
          segment: group.segment,
          transitions: group.transitions,
          selection: $selectedTransition
        )
      }
      // A list header uppercases the text it heads, which would misspell a transition the
      // procedure names in mixed case.
      .textCase(nil)
    } else {
      Text(group.label)
    }
  }
}

/// The menu choosing which of a segment's transitions its section lists.
private struct TransitionPicker: View {
  let segment: Segment
  let transitions: [FixGrouping.Transition<FixListEntry>]
  @Binding var selection: String?

  var body: some View {
    Picker("Transition", selection: $selection) {
      ForEach(transitions) { transition in
        // A transition name is procedure data rather than copy: it is never translated.
        Text(verbatim: transition.name)
          .accessibilityIdentifier("transitionOption-\(transition.name)")
          .tag(Optional(transition.name))
      }
    }
    .pickerStyle(.menu)
    .labelsHidden()
    .accessibilityIdentifier("transitionPicker-\(segment.rawValue)")
  }
}

/**
 One row of the fix list: a coded fix, or the pilot-entered DA/MDA that closes the final
 segment.
 */
private struct CorrectedRow: View {
  let entry: FixListEntry
  let corrector: ApproachCorrector
  @Binding var minimums: Measurement<UnitLength>?
  @FocusState.Binding var isEditingMinimums: Bool

  var body: some View {
    switch entry {
      case let .fix(fix):
        FixRow(fix: fix, altitude: corrector.corrected(fix))
      case .minimums:
        MinimumsRow(
          minimums: $minimums,
          corrector: corrector,
          isEditing: $isEditingMinimums
        )
    }
  }
}

/**
 What the fix list places in a segment section: a coded fix, or the pilot-entered DA/MDA.

 The minimums are a pseudo-fix of the final segment, sequenced after every leg the procedure
 codes, so the same grouping that orders the charted fixes puts them where they are flown —
 and the final section exists even for a procedure that codes no fixes at all.
 */
private enum FixListEntry: Identifiable {
  case fix(Fix)
  case minimums

  var id: PersistentIdentifier? {
    switch self {
      case let .fix(fix): fix.persistentModelID
      case .minimums: nil
    }
  }

  var segment: Segment {
    switch self {
      case let .fix(fix): fix.segment
      case .minimums: .final
    }
  }

  var transition: String? {
    switch self {
      case let .fix(fix): fix.transition
      case .minimums: nil
    }
  }

  var sequence: UInt {
    switch self {
      case let .fix(fix): fix.sequence
      case .minimums: .max
    }
  }
}

/**
 What the screen shows in place of the fixes when the reported temperature is warmer than the
 airport's Cold Temperature Airport restriction.
 */
private struct NoCorrectionNotice: View {
  var body: some View {
    Section {
      Text("No correction necessary")
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityIdentifier("noCorrectionNotice")
    }
  }
}

#if DEBUG
  #Preview("Cold") {
    NavigationStack {
      let airport = PreviewData.missoula()
      FixListView(
        airport: airport,
        approach: airport.approaches[0],
        initialTemperature: .celsius(-20)
      )
    }
    .modelContainer(.preview)
  }
#endif

// The weather block only renders where a loader and a connected monitor are both in the
// environment, so this preview seeds both. Serving one fixed cold observation keeps the preview
// off the network and shows the temperature auto-filling from the METAR it links to.
#if DEBUG
  #Preview("Reporting station") {
    NavigationStack {
      let airport = PreviewData.missoula()
      FixListView(airport: airport, approach: airport.approaches[0])
    }
    .modelContainer(.preview)
    .environment(\.metarLoader, METARLoader(serving: ["KMSO": .preview]))
    .environment(\.networkMonitor, NetworkMonitor(reporting: true))
  }

  #Preview("No correction necessary") {
    NavigationStack {
      let airport = PreviewData.missoula()
      FixListView(
        airport: airport,
        approach: airport.approaches[0],
        initialTemperature: .celsius(5)
      )
    }
    .modelContainer(.preview)
  }
#endif
