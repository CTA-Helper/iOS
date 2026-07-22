import SwiftUI
import UIKit

/**
 A text field that edits a `Measurement`, with the unit set beside the digits exactly as the
 value's own format style renders it.

 The bound value is optional, and an empty field reads as `nil` rather than zero. Where a
 caller drives a calculation from what was typed, that distinction is the difference between
 "nothing entered yet" and a confident answer computed from a value the pilot never gave.
 */
struct MeasurementField<Unit: Dimension>: View {
  /// The field's placeholder, and its accessibility label.
  let label: LocalizedStringKey
  /// The edited value, or `nil` while the field is empty.
  @Binding var value: Measurement<Unit>?
  /// How the value is rendered — and, through its number format, parsed back.
  let format: Measurement<Unit>.FormatStyle
  /// The unit the digits are typed and read in.
  let unit: Unit
  /// The keyboard the field raises.
  let keyboardType: UIKeyboardType
  /// The bounds outside which the entered value shows as invalid, if any.
  let minimum: Measurement<Unit>?, maximum: Measurement<Unit>?

  var body: some View {
    HStack(spacing: 0) {
      if let prefix { Text(verbatim: prefix).foregroundStyle(.secondary) }
      // The placeholder stands down once there is a value to show. A field sized to fit its own
      // placeholder stays that wide forever, and a caller that strikes or boxes the entered
      // value would draw around the empty space the placeholder reserved.
      TextField(value == nil ? label : "", text: text)
        .numericField(keyboardType: keyboardType)
        .accessibilityLabel(Text(label))
        // `.foreground` rather than `.primary`, so a caller that dims or strikes the whole field
        // is not overridden by the field restating the colour it would have had anyway.
        .foregroundStyle(isValid ? AnyShapeStyle(.foreground) : AnyShapeStyle(.red))
      if let suffix { Text(verbatim: suffix).foregroundStyle(.secondary) }
    }
  }

  /// The number format the value is rendered and parsed with, taken from ``format``.
  private var numberFormat: FloatingPointFormatStyle<Double> {
    format.numberFormatStyle ?? .number
  }

  /**
   The value as editable text: the formatted digits alone, without the unit the field sets
   beside them. Text that does not parse — an empty field, above all — clears the value.
   */
  private var text: Binding<String> {
    Binding(
      get: { value.map { numberFormat.format($0.converted(to: unit).value) } ?? "" },
      set: { value = parse($0) }
    )
  }

  /**
   What the format style puts before and after the digits — the unit, and any space or symbol
   that travels with it.

   A format style is not introspectable, so the affixes are recovered by formatting a value of
   one and splitting the result on the digits the number format alone would have produced.
   */
  private var affixes: [Substring] {
    let formatted = format.format(Measurement(value: 1, unit: unit))
    return formatted.split(
      separator: numberFormat.format(1),
      maxSplits: 2,
      omittingEmptySubsequences: false
    )
  }

  private var prefix: String? {
    affixes.first.map(String.init).flatMap { $0.isEmpty ? nil : $0 }
  }

  private var suffix: String? {
    affixes.last.map(String.init).flatMap { $0.isEmpty ? nil : $0 }
  }

  /**
   Whether the entered value lies within the bounds the caller set. An empty field is valid:
   there is nothing yet to be out of range.
   */
  private var isValid: Bool {
    guard let value else { return true }
    if let minimum, value < minimum { return false }
    if let maximum, value > maximum { return false }
    return true
  }

  /**
   Creates a field editing a measurement.

   - Parameters:
     - label: the placeholder shown while the field is empty, and its accessibility label.
     - value: the edited value, `nil` while the field is empty.
     - unit: the unit the digits are typed in; defaults to the value's own unit.
     - format: how the value is rendered, and through its number format how it is parsed.
     - keyboardType: the keyboard to raise, `.decimalPad` unless the value is always whole.
     - minimum: the value below which the field shows as invalid, if any.
     - maximum: the value above which the field shows as invalid, if any.
   */
  init(
    _ label: LocalizedStringKey,
    value: Binding<Measurement<Unit>?>,
    unit: Unit? = nil,
    format: Measurement<Unit>.FormatStyle,
    keyboardType: UIKeyboardType = .decimalPad,
    minimum: Measurement<Unit>? = nil,
    maximum: Measurement<Unit>? = nil
  ) {
    self.label = label
    _value = value
    self.unit = unit ?? value.wrappedValue?.unit ?? .baseUnit()
    self.format = format
    self.keyboardType = keyboardType
    self.minimum = minimum
    self.maximum = maximum
  }

  private func parse(_ text: String) -> Measurement<Unit>? {
    guard let number = try? numberFormat.parseStrategy.parse(text) else { return nil }
    return Measurement(value: number, unit: unit)
  }
}

#if DEBUG
  #Preview("Entered and empty") {
    @Previewable @State var entered: Measurement<UnitLength>? = .init(value: 4520, unit: .feet)
    @Previewable @State var empty: Measurement<UnitLength>?
    @Previewable @State var tooLow: Measurement<UnitTemperature>? = .init(
      value: -80,
      unit: .celsius
    )

    List {
      LabeledContent("DA or MDA") {
        MeasurementField(
          "Feet MSL",
          value: $entered,
          unit: .feet,
          format: .altitude,
          keyboardType: .numberPad
        )
      }
      LabeledContent("DA or MDA") {
        MeasurementField(
          "Feet MSL",
          value: $empty,
          unit: .feet,
          format: .altitude,
          keyboardType: .numberPad
        )
      }
      LabeledContent("Below minimum") {
        MeasurementField(
          "Celsius",
          value: $tooLow,
          unit: .celsius,
          format: .reportedTemperature,
          minimum: .init(value: -50, unit: .celsius)
        )
      }
    }
  }
#endif
