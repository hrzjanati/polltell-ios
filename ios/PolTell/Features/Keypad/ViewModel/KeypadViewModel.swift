import Perception
import SwiftUI
import PolTellCore

/// The number being typed and what the dial pad does with it.
@MainActor @Perceptible
final class KeypadViewModel {
    var number = ""
    var sub: Int?
    @PerceptionIgnored private var longPressedZero = false
    @PerceptionIgnored private let model: AppModel
    @PerceptionIgnored private let router: Router

    init(model: AppModel? = nil, router: Router? = nil) {
        self.model = model ?? .shared
        self.router = router ?? .shared
    }

    var displayNumber: String { number.isEmpty ? " " : model.formatted(number) }
    /// The saved contact's name for the typed number, if any.
    var contactName: String? { number.isEmpty ? nil : model.name(for: number) }
    var canCall: Bool { !number.isEmpty && model.linkState.isConnected }
    var routedNumber: String? { router.keypadNumber }

    func tap(_ key: KeypadKey) {
        if key.digit == "0" && longPressedZero { longPressedZero = false; return }
        longPressedZero = false
        number.append(key.digit)
    }

    /// Hold 0 for "+" (the tap that ends the hold must not add a 0 as well).
    func hold(_ key: KeypadKey) {
        guard key.digit == "0" else { return }
        number.append("+")
        longPressedZero = true
    }

    func backspace() { if !number.isEmpty { number.removeLast() } }
    func paste() { if let s = UIPasteboard.general.string { number = PhoneNumber.digits(s) } }
    func call() { model.dial(number, sub: sub) }

    func appeared() {
        if sub == nil { sub = model.status?.defaultSub }
        #if DEBUG
        // -PolTellDemoKeypad <digits>: a typed number, to check the as-you-type grouping.
        let args = ProcessInfo.processInfo.arguments
        if number.isEmpty, let i = args.firstIndex(of: "-PolTellDemoKeypad"), i + 1 < args.count { number = args[i + 1] }
        #endif
        takeRouted()
    }

    /// A number from a link the owner did not call yet (cancelled, or the Android phone was not connected).
    func takeRouted() {
        guard let n = router.keypadNumber else { return }
        number = n
        router.keypadNumber = nil
    }
}
