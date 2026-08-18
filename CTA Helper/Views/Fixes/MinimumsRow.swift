import SwiftUI

/**
 The pilot-entered DA or MDA, standing in the fix list as the last row of the final segment.

 The pilot types the charted minimums where a charted fix shows its published altitude, and
 the corrected value appears beside them. The final segment's correction is computed from the
 minimums themselves (ENR 1.8 5.f.2.1), so this row is both the input to that correction and
 the place it is read off.

 Once corrected, the entered value is struck through exactly as a fix's published altitude is
 — but only while the field is idle, so the digits stay legible under the caret.
 */
struct MinimumsRow: View {
  /**
   The altitude above which an entered DA or MDA reads as a mistyping rather than a minimum.

   The highest airport in the country sits under 15,000 ft, so no published minimum comes near
   this. It is a wrong-order-of-magnitude check — a dropped or doubled digit — not a limit.
   */
  private static let implausibleMinimums = Measurement<UnitLength>.feet(30_000)

  /// The entered DA or MDA, MSL, or `nil` until the pilot types one.
  @Binding var minimums: Measurement<UnitLength>?
  /// The corrector that resolves the entered minimums.
  let corrector: ApproachCorrector

  /**
   Whether the entry field holds the keyboard, owned by the screen so the key that dismisses
   it can live on the screen's toolbar rather than on this row.
   */
  @FocusState.Binding var isEditing: Bool

  var body: some View {
    VStack(alignment: .leading) {
      HStack(alignment: .firstTextBaseline) {
        Text("DA or MDA")
        Spacer()
        MeasurementField(
          "minimums",
          value: $minimums,
          unit: .feet,
          format: .altitude,
          keyboardType: .numberPad,
          maximum: Self.implausibleMinimums
        )
        // Sized to what it holds rather than to a fixed width, so the slash that strikes it
        // covers the digits alone. A field wide enough for its placeholder would trail the
        // stroke off across empty space to the left of the value.
        .fixedSize(horizontal: true, vertical: false)
        .focused($isEditing)
        .superseded(isSuperseded)
        .accessibilityIdentifier("minimumsField")
        CorrectedMinimums(corrected: correctedMinimums)
          .accessibilityIdentifier("correctedMinimums")
      }
      DecisionHeightNote()
    }
  }

  /// The corrected minimums, or `nil` until the pilot enters them.
  private var correctedMinimums: Measurement<UnitLength>? {
    corrector.corrected(MinimumsFix(altitude: minimums)).corrected
  }

  /**
   Whether the entered value is struck through: a correction supersedes it, and the field is
   not being typed into.
   */
  private var isSuperseded: Bool {
    !isEditing && correctedMinimums != nil
  }
}

/**
 What the field does not take: a decision height.

 ENR 1.8 corrects barometric altitudes, and a DH is referenced to the threshold elevation rather
 than to sea level — the Category II and III minima expressed as one are flown on the radio
 altimeter, which cold temperature leaves alone. Set under the field in smaller type, since it
 qualifies the entry rather than labelling it.
 */
private struct DecisionHeightNote: View {
  var body: some View {
    Text("Do not correct a DH (radar altimeter height).")
      .font(.caption)
      .fontWeight(.medium)
  }
}

/**
 The corrected DA or MDA, in the weight every corrected altitude on this screen carries, or a
 dash until the minimums are entered.
 */
private struct CorrectedMinimums: View {
  let corrected: Measurement<UnitLength>?

  var body: some View {
    if let corrected {
      Text(corrected, format: .altitudeDigits)
        .fontWeight(.bold)
        .monospacedDigit()
    } else {
      Text(verbatim: "—")
        .foregroundStyle(.secondary)
        .accessibilityLabel("No corrected minimums")
    }
  }
}

/**
 The pilot-entered DA or MDA presented to the correction engine as a fix of the final segment,
 so the minimums are corrected by exactly the machinery every charted fix goes through.
 */
private struct MinimumsFix: CorrectableFix {
  let segment = Segment.final
  let isCorrectable = true
  let publishedAltitude: PublishedAltitude

  /**
   Wraps an entered DA or MDA, publishing nothing until the pilot types one.

   ``PublishedAltitude`` codes the whole feet the store holds, so the entry is rounded to them
   here. The conversion is `Int(exactly:)` rather than `Int(_:)` because a number pad accepts
   more digits than an `Int` holds, and converting a `Double` past `Int.max` traps outright. A
   value that large is not a minimum anyone typed on purpose, so it publishes nothing at all.
   */
  init(altitude: Measurement<UnitLength>?) {
    publishedAltitude =
      altitude
      .flatMap { Int(exactly: $0.converted(to: .feet).value.rounded()) }
      .map { .single(ft: $0, restriction: .atOrAbove, glidepathFt: nil) } ?? .unpublished
  }
}

#if DEBUG
  #Preview("Entered") {
    @Previewable @State var minimums: Measurement<UnitLength>? = .feet(4520)
    @Previewable @FocusState var isEditing: Bool
    let airport = PreviewData.missoula()

    List {
      MinimumsRow(
        minimums: $minimums,
        corrector: .preview(for: airport, minimums: minimums),
        isEditing: $isEditing
      )
    }
  }

  #Preview("Empty") {
    @Previewable @State var minimums: Measurement<UnitLength>?
    @Previewable @FocusState var isEditing: Bool
    let airport = PreviewData.missoula()

    List {
      MinimumsRow(
        minimums: $minimums,
        corrector: .preview(for: airport, minimums: minimums),
        isEditing: $isEditing
      )
    }
  }

  #Preview("Uncorrected") {
    @Previewable @State var minimums: Measurement<UnitLength>? = .feet(4520)
    @Previewable @FocusState var isEditing: Bool

    List {
      MinimumsRow(
        minimums: $minimums,
        corrector: .preview(
          for: PreviewData.missoula(),
          temperature: .celsius(20),
          minimums: minimums
        ),
        isEditing: $isEditing
      )
    }
  }
#endif
