import Perception
import SwiftUI
import PolTellCore

/// The window around the tabs: which tab is shown, the badges, banners, toasts, the "Call this number?" alert and
/// whether the call screen is up.
@MainActor @Perceptible
final class RootViewModel {
    @PerceptionIgnored private let model: AppModel
    @PerceptionIgnored private let router: Router

    init(model: AppModel? = nil, router: Router? = nil) {
        self.model = model ?? .shared
        self.router = router ?? .shared
    }

    // MARK: Tabs

    var tab: Router.Tab {
        get { router.tab }
        set { router.tab = newValue }
    }
    var missedCount: Int { model.missedCount }
    var unreadTotal: Int { model.unreadTotal }
    /// Like Messages: no tab bar inside a conversation (it would sit under the composer and the keyboard).

    func opened() { if !model.isPaired { router.tab = .link } }

    // MARK: Messages over the content

    var lastError: String? {
        get { model.lastError }
        set { model.lastError = newValue }
    }
    var notice: String? { model.notice }
    func dismissError() { model.lastError = nil }

    // MARK: Call screen

    var showsCallScreen: Bool {
        get { model.showCallScreen && model.callScreen != nil }
        set { model.showCallScreen = newValue }
    }

    // MARK: "Call this number?" (a tel: link or a shortcut)

    var dialRequest: Router.DialRequest? {
        get { router.dialRequest }
        set { router.dialRequest = newValue }
    }
    var isConnected: Bool { model.linkState.isConnected }
    func contactName(_ number: String) -> String? { model.name(for: number) }
    func formatted(_ number: String) -> String { model.formatted(number) }
    func confirm(_ req: Router.DialRequest) {
        if isConnected { model.dial(req.number, sub: nil) } else { router.keypadNumber = req.number }
    }
    func cancel(_ req: Router.DialRequest) { router.keypadNumber = req.number }

    // MARK: Calls whose audio is on another device

    var remoteCalls: [CallInfo] { model.remoteCalls }
    func displayName(_ number: String) -> String { model.displayName(number) }
    func take(_ call: CallInfo) { model.calls.take(call.cid) }
}
