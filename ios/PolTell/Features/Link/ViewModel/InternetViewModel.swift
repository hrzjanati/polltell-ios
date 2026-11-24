import Perception
import SwiftUI
import PolTellCore

/// The Android phone's internet switches (mobile data, hotspot, Bluetooth tethering, airplane mode, VPN sharing,
/// per-SIM network mode and the data SIM), with the "a change is in flight" state.
@MainActor @Perceptible
final class InternetViewModel {
    @PerceptionIgnored private let model: AppModel

    init(model: AppModel? = nil) { self.model = model ?? .shared }

    var net: NetState? { model.net }
    var pending: String? { model.netPending }
    var isConnected: Bool { model.linkState.isConnected }
    var simCount: Int { model.status?.sims.count ?? 0 }
    /// Nothing can be switched while the link is down or another change is still being applied.
    var isLocked: Bool { pending != nil || !isConnected }

    func set(_ what: String, on: Bool) { model.setNet(what, on: on) }
    func setDataSim(_ sub: Int) { model.setDataSim(sub) }
    func setNetworkMode(slot: Int, _ mode: String) { model.setNetworkMode(slot: slot, mode) }
    func copy(_ text: String) {
        UIPasteboard.general.string = text
        model.flash(String(localized: "Copied"))
    }
}
