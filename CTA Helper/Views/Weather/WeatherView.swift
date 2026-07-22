import SwiftUI

/**
 The station's latest METAR — the observation the fix list filled its reported temperature
 from, shown whole so the pilot can see what that number came from and how old it is.

 Nothing here is editable. The reported temperature is corrected on the fix list itself, and
 this screen only accounts for where its starting value came from.
 */
struct WeatherView: View {
  /// The observation to show.
  let observation: METARObservation

  var body: some View {
    List {
      Section {
        // Read out as one element so the station carries as the row's accessibility value —
        // "Station, KMSO" to VoiceOver, and the bare identifier to anything querying for it.
        LabeledContent("Station", value: observation.stationID)
          .accessibilityElement()
          .accessibilityLabel("Station")
          .accessibilityValue(observation.stationID)
          .accessibilityIdentifier("weatherStation")
        LabeledContent("Observed") {
          ObservationTime(date: observation.date)
        }
        if let temperature = observation.temperature {
          LabeledContent("Temperature") {
            Text(temperature.converted(to: .celsius), format: .reportedTemperature)
              .monospacedDigit()
          }
        }
      }
      if !observation.rawText.isEmpty {
        Section("Raw") {
          RawObservation(text: observation.rawText)
        }
      }
    }
    .accessibilityIdentifier("weatherScreen")
    .navigationTitle("Weather")
  }
}

/// When the observation was taken: the Zulu time it is filed under, over how long ago that was.
private struct ObservationTime: View {
  /**
   The observation time as a METAR carries it — UTC, on a 24-hour clock, in neither the
   device's time zone nor its locale's clock. A METAR filed at `250053Z` reads 00:53, which a
   locale-aware style would render as the 12:53 of a different hour entirely.
   */
  private static let zulu = Date.VerbatimFormatStyle(
    format: """
      \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)Z
      """,
    timeZone: .gmt,
    calendar: Calendar(identifier: .gregorian)
  )

  let date: Date

  var body: some View {
    VStack(alignment: .trailing) {
      // Formatted here rather than handed to `Text(_:format:)`, which resolves a date against
      // the environment's own time zone and would put the observation back in local time.
      Text(verbatim: date.formatted(Self.zulu))
        .monospacedDigit()
      Text(date, format: .relative(presentation: .numeric))
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}

/**
 The METAR as published, in the monospaced type it is read in, scrolling sideways rather than
 wrapping — a wrapped METAR loses the grouping that makes it legible.
 */
private struct RawObservation: View {
  let text: String

  /**
   Set a little under body text: a METAR is one long line of groups, and the smaller type fits
   more of it on screen before the pilot has to scroll. It still tracks Dynamic Type off body,
   which is what this text reads as.
   */
  @ScaledMetric(relativeTo: .body)
  private var size = 15.0

  var body: some View {
    ScrollView(.horizontal) {
      Text(text)
        .font(.system(size: size, design: .monospaced))
    }
  }
}

#if DEBUG
  #Preview("Cold") {
    NavigationStack {
      WeatherView(observation: .preview)
    }
  }

  #Preview("Off the slider's warm end") {
    NavigationStack {
      WeatherView(observation: .previewOffScale)
    }
  }

  #Preview("No temperature reported") {
    NavigationStack {
      WeatherView(observation: .previewWithoutTemperature)
    }
  }
#endif
