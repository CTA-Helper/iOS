import SwiftUI
import UIKit

/**
 Selects a text field's whole contents when it takes focus, so typing over an entered value
 replaces it instead of appending to it.

 UIKit announces the start of editing through a notification that names no particular field,
 and SwiftUI hands out no reference to the `UITextField` behind a `TextField`, so the only
 thing this can match on is the kind of keyboard the field raises. That is enough to keep the
 selection off unrelated fields: the split view has the sidebar's search field on screen
 beside the fix list, and selecting its contents out from under the pilot would lose whatever
 they had typed on their next keystroke.
 */
struct SelectAllOnFocus: ViewModifier {
  /// The keyboard whose fields this selects. A field raising any other keyboard is left alone.
  let keyboardType: UIKeyboardType

  func body(content: Content) -> some View {
    content.onReceive(
      NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)
    ) { notification in
      guard let textField = notification.object as? UITextField,
        textField.keyboardType == keyboardType
      else { return }
      // Deferred to the next run loop: selecting synchronously inside textDidBeginEditing is
      // undone by SwiftUI's focus re-render of the field, which deselects and parks the caret at
      // the end, so a fast typist — or a UI test — appends instead of replacing the value.
      Task { @MainActor in textField.selectAll(nil) }
    }
  }
}

extension View {
  /**
   Selects the field's contents when it takes focus, so typing replaces the entered value.

   - Parameter keyboardType: the keyboard the field raises; only fields raising it are
     selected.
   */
  func selectAllOnFocus(matching keyboardType: UIKeyboardType) -> some View {
    modifier(SelectAllOnFocus(keyboardType: keyboardType))
  }
}
