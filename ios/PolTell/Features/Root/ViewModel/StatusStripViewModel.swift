import Perception
import SwiftUI
import PolTellCore

/// The glass capsule under the status bar: Bluetooth state on the left, the Android phone's SIMs and battery on the right.
@MainActor @Perceptible
final class StatusStripViewModel {
    @PerceptionIgnored private let model: AppModel

    init(model: AppModel? = nil) { self.model = model ?? .shared }

    /// The phone's SIMs and battery, shown only while linked (or in demo mode / previews).
    var phoneStatus: StatusBody? {
        guard let s = model.status, model.linkState.isConnected || AppModel.demoMode else { return nil }
        return s
    }

    /// A paired phone that is not connected tints the capsule red.
    var problem: Bool { model.isPaired && !model.linkState.isConnected }

    var badge: BluetoothBadge.State {
        switch model.linkState {
        case .connected: .connected
        case .connecting, .handshaking: .connecting
        case .poweredOff, .unauthorized: .off
        default: model.isPaired ? .lost : .off
        }
    }

    /// Read by VoiceOver in place of the glyph.
    var stateText: LocalizedStringKey {
        switch model.linkState {
        case .connected: "Connected"
        case .connecting, .handshaking: "Connecting…"
        case .poweredOff: "Bluetooth is off"
        case .unauthorized: "Bluetooth not allowed"
        case .unpaired: "Not paired"
        case .searching: model.isPaired ? "Out of reach" : "Not paired"
        }
    }

    func batteryIcon(_ s: StatusBody) -> String {
        if s.charging { return "battery.100.bolt" }
        switch s.battery {
        case ..<13: return "battery.0"
        case ..<38: return "battery.25"
        case ..<63: return "battery.50"
        case ..<88: return "battery.75"
        default: return "battery.100"
        }
    }

    func batteryColor(_ s: StatusBody) -> Color {
        s.battery <= 15 && !s.charging ? .red : (s.charging ? .green : .primary)
    }
}
