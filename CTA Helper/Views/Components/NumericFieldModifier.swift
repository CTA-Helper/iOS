import SwiftUI
import UIKit

/**
 The behavior every numeric entry field shares: the right keyboard, digits aligned to the
 trailing edge where the eye compares them, and the whole value selected on focus.
 */
private struct NumericFieldModifier: ViewModifier {
  let keyboardType: UIKeyboardType

  func body(content: Content) -> some View {
    content
      .keyboardType(keyboardType)
      .selectAllOnFocus(matching: keyboardType)
      .multilineTextAlignment(.trailing)
  }
}

extension View {
  /**
   Styles the view as a numeric entry field.

   - Parameter keyboardType: the keyboard to raise — `.numberPad` for a value that is always a
     whole number, `.decimalPad` where a fraction is meaningful.
   */
  func numericField(keyboardType: UIKeyboardType = .decimalPad) -> some View {
    modifier(NumericFieldModifier(keyboardType: keyboardType))
  }
}
