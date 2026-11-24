import Perception
import SwiftUI
import PolTellCore

/// What a bubble's actions do: copy, call a number inside the text, message it, delete the message.
@MainActor @Perceptible
final class BubbleViewModel {
    var phone: String?
    var confirmDelete = false
    @PerceptionIgnored let message: Sms
    @PerceptionIgnored private let model: AppModel

    init(message: Sms, model: AppModel? = nil) {
        self.message = message
        self.model = model ?? .shared
    }

    func copy(_ code: String) {
        UIPasteboard.general.string = code
        model.flash(String(localized: "Code \(code) copied"))
    }

    func copyBody() { UIPasteboard.general.string = message.body }
    func copyLink(_ url: URL) { UIPasteboard.general.url = url }
    func copyRaw(_ text: String) { UIPasteboard.general.string = text }
    func copyNumber(_ n: String) { UIPasteboard.general.string = n; model.flash(String(localized: "Copied")) }
    func call(_ n: String) { model.dial(n, sub: model.preferredSim(for: message.addr)) }
    func sendMessage(to n: String) { Router.shared.compose(to: n) }
    func delete() { model.deleteMessages([message.id]) }
}
