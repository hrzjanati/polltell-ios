import Perception
import SwiftUI
import PolTellCore

/// The call screen and its "return to call" strip: what the call says about itself and what each control does.
/// Every action goes through CallKit (`CallController`) so lock screen, Dynamic Island and AirPods stay in sync.
@MainActor @Perceptible
final class InCallViewModel {
    var keypad: Bool
    var typed = ""
    @PerceptionIgnored private let model: AppModel
    @PerceptionIgnored private let router: Router

    init(model: AppModel? = nil, router: Router? = nil) {
        self.model = model ?? .shared
        self.router = router ?? .shared
        #if DEBUG
        keypad = ProcessInfo.processInfo.arguments.contains("-PolTellDemoKeypad")
        #else
        keypad = false
        #endif
    }

    // MARK: State

    var call: CallScreen? { model.callScreen }
    /// The strip shows while a call runs and its screen is hidden.
    var returnableCall: CallScreen? {
        guard let c = model.callScreen, !model.showCallScreen, c.state != "ended" else { return nil }
        return c
    }

    func title(_ call: CallScreen) -> String { call.name ?? model.formatted(call.number) }
    func simName(_ call: CallScreen) -> String? { model.simName(call.sub) }

    /// The caller's picture, when the Android phone sent one.
    func photo(_ call: CallScreen) -> UIImage? {
        guard let b64 = model.photo(for: call.number), let data = Data(base64Encoded: b64) else { return nil }
        return UIImage(data: data)
    }

    // MARK: Actions

    func callChanged() { keypad = false; typed = "" }
    func hideScreen() { model.showCallScreen = false; model.callScreenDismissed = true }
    func returnToCall() { model.callScreenDismissed = false; model.showCallScreen = true }
    func showContacts() { hideScreen(); router.tab = .contacts }
    func dtmf(_ call: CallScreen, _ digit: String) { model.calls.dtmf(call.uuid, digit) }
    func selectRoute(_ id: String) { model.calls.selectRoute(id) }
    func toggleSpeaker(_ call: CallScreen) { model.calls.setSpeaker(!call.speaker) }
    func toggleHold(_ call: CallScreen) { model.calls.setHeld(call.uuid, !call.held) }
    func toggleMute(_ call: CallScreen) { model.calls.setMuted(call.uuid, !call.muted) }
    func end(_ call: CallScreen) { model.calls.end(call.uuid) }
    func answer(_ call: CallScreen) { model.calls.answer(call.uuid) }
}
