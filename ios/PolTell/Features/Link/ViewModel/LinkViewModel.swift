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
    func applyRecentsSetting() { model.calls.applyRecentsSetting() }
}
