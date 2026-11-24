import Perception
import SwiftUI
import PolTellCore

/// The New message sheet: recipient with suggestions, the text and the SIM.
@MainActor @Perceptible
final class ComposeViewModel {
    var to = ""
    var text = ""
    var sub: Int?
    @PerceptionIgnored private let model: AppModel

    init(model: AppModel? = nil) { self.model = model ?? .shared }

    var canSend: Bool { !to.isEmpty && !text.isEmpty }

    /// Saved contacts whose name or number contain what is typed in To (at most about seven).
    var suggestions: [(name: String, number: String)] {
        let q = to.lowercased()
        var out: [(name: String, number: String)] = []
        for c in model.data.contacts where c.name.lowercased().contains(q) || c.phones.contains(where: { $0.n.contains(q) }) {
            for p in c.phones { out.append((c.name, p.n)) }
            if out.count > 6 { break }
        }
        return out
    }

    func formatted(_ number: String) -> String { model.formatted(number) }

    func appeared(initialTo: String) {
        sub = model.status?.defaultSub
        if to.isEmpty { to = initialTo }
    }

    /// Sends and returns the conversation's thread, when there already is one.
    func send() -> Int64? {
        model.sendSms(to: to, body: text, sub: sub)
        return model.thread(for: to)
    }
}
