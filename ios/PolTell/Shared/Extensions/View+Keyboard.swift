import Perception
import SwiftUI
import PolTellCore

extension View {
    /// A "Done" button above number / phone pads, which have no return key to close them.
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { hideKeyboard() }.fontWeight(.semibold)
            }
        }
    }
}
