import AVFoundation
import Perception
import SwiftUI
import PolTellCore

/// The Link tab: link state, the paired Android phone, audio self-test, sync and pairing.
@MainActor @Perceptible
final class LinkViewModel {
    var scanning = false
    var confirmUnpair = false
    @PerceptionIgnored private let model: AppModel

    init(model: AppModel? = nil) { self.model = model ?? .shared }

    // MARK: Phone and link

    var status: StatusBody? { model.status }
    var isConnected: Bool { model.linkState.isConnected }
    var isPaired: Bool { model.isPaired }
    var peerName: String { model.peerName }
    var dataSub: Int? { model.net?.dataSub }
    var blockedCount: Int { model.blockLists.blocked.count }
    var lastSync: Date? { model.lastSync }
    var audioStats: CallAudio.Stats? { model.lastAudioStats }
    var selftest: SelftestResult? { model.selftest }

    var stateLine: String {
        switch model.linkState {
        case .connected(let t): String(localized: "Connected over \(t == "l2cap" ? "L2CAP" : "GATT")")
        case .connecting, .handshaking: String(localized: "Connecting…")
        case .searching: model.isPaired ? String(localized: "Out of reach, will reconnect automatically") : String(localized: "Not paired")
        case .poweredOff: String(localized: "Bluetooth is off")
        case .unauthorized: String(localized: "Allow Bluetooth for PolTell in Settings")
        case .unpaired: String(localized: "Not paired")
        }
    }

    // MARK: Actions

    func appeared() { model.refreshNet() }
    func connectionChanged() { if isConnected { model.refreshNet() } }
    func startScanning() { scanning = true }
    func paired(_ code: PairingCode?) {
        scanning = false
        if let code { model.pair(code) }
    }
    func unpair() { model.unpair() }
    func syncAll() { model.requestSync(full: true) }
    func runSelftest() { model.runSelftest() }
    func setPhoneMic(_ mic: String) { model.setPhoneMic(mic) }
    func setPhoneMicMute(_ on: Bool) { model.setPhoneMicMute(on) }
    func applyRecentsSetting() { model.calls.applyRecentsSetting() }
}

/// What the Call audio section shows of the Android phone's microphone mute and the uplink check.
enum CallAudioRows {
    /// The switch only when the Android phone reports the setting (older Android builds do not: hidden).
    static func showsMicToggle(_ s: StatusBody?) -> Bool { s?.helper.micMute != nil }

    /// The picker's value: an unknown setting from a newer Android build reads as the default.
    static func micChoice(_ mic: String) -> String { ["auto", "mute", "open"].contains(mic) ? mic : "auto" }

    static func micPathText(_ p: String) -> String {
        switch p {
        case "off": return String(localized: "Microphone out of the call")
        case "muted": return String(localized: "Microphone muted")
        default: return String(localized: "Microphone on")
        }
    }

    static func micFooter(_ mic: String) -> String {
        switch micChoice(mic) {
        case "mute": return String(localized: "Muting works on some phones only: on others it also mutes your voice for the other side. PolTell checks during each call and turns the mute off if your voice does not get through.")
        case "open": return String(localized: "The Android phone's microphone stays in the call: the other side may hear your voice twice, and the room around the phone.")
        default: return String(localized: "PolTell puts the call in Android's redirect audio mode: the Android phone's own microphone and earpiece leave the call, so the other side hears only this iPhone. PolTell checks that both directions still work and keeps the microphone on where the phone does not allow it.")
        }
    }

    static func uplinkText(_ u: String) -> String {
        switch u {
        case "ok": return String(localized: "Reaches the other side")
        case "checking": return String(localized: "Checking…")
        case "muted-locally-fixed": return String(localized: "Was muted by the phone; fixed")
        case "off": return String(localized: "Not muted by the phone")
        default: return String(localized: "Not checked")
        }
    }

    /// This iPhone refused PolTell the microphone: every call's uplink is silent.
    static func microphoneDenied() -> Bool {
        if #available(iOS 17, *) { return AVAudioApplication.shared.recordPermission == .denied }
        return AVAudioSession.sharedInstance().recordPermission == .denied
    }
}
