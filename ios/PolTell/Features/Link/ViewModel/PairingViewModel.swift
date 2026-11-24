import Perception
import SwiftUI
import PolTellCore

/// Pairing with the Android phone: the scanner screen and the typed-code screen.
@MainActor @Perceptible
final class PairingViewModel {
    var error: String?
    var manual = false
    var cameraMissing = false
    var typed = ""

    private static var notACode: String { String(localized: "That is not a PolTell pairing code.") }

    /// A scanned QR text: the code, or an error line under the viewfinder.
    func scanned(_ text: String) -> PairingCode? {
        if let code = PairingCode.parse(text) { return code }
        error = Self.notACode
        return nil
    }

    /// The typed or pasted text: the code, or an error under the field.
    func submitTyped() -> PairingCode? {
        if let code = PairingCode.parse(typed.trimmingCharacters(in: .whitespacesAndNewlines)) { return code }
        error = Self.notACode
        return nil
    }

    func paste(_ s: String) { typed = s.trimmingCharacters(in: .whitespacesAndNewlines) }
}
