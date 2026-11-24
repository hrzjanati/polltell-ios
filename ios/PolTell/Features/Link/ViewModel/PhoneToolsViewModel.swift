import Perception
import SwiftUI
import PolTellCore

/// Phone tools: carrier (USSD) codes, "find my phone" and the ringer mode.
@MainActor @Perceptible
final class PhoneToolsViewModel {
    var code = ""
    var sub: Int?
    @PerceptionIgnored private let model: AppModel

    init(model: AppModel? = nil) { self.model = model ?? .shared }

    var isConnected: Bool { model.linkState.isConnected }
    var ussdPending: Bool { model.ussdPending }
    var ussdResult: UssdResult? { model.ussdResult }
    var finding: Bool { model.finding }
    var error: String? { model.phoneToolError }

    func chosenSub(_ status: StatusBody) -> Int? { sub ?? status.defaultSub ?? status.sims.first?.sub }
    func canSend() -> Bool {
        UssdCode.isValid(code.trimmingCharacters(in: .whitespaces)) && !model.ussdPending && model.linkState.isConnected
    }
    func send(_ status: StatusBody) { model.sendUssd(code, sub: chosenSub(status)) }
    func setFinding(_ on: Bool) { model.setFinding(on) }
    func setRinger(_ mode: String) { model.setRinger(mode) }
}
