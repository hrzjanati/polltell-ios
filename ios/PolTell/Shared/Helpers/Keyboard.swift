import Perception
import SwiftUI
import PolTellCore

/// Puts the keyboard away (before a menu, sheet or dialog opens over a text field).
@MainActor func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
