import Perception
import SwiftUI
import PolTellCore

/// The block list kept on the Android phone.
@MainActor @Perceptible
final class BlockedListViewModel {
    @PerceptionIgnored private let model: AppModel

    init(model: AppModel? = nil) { self.model = model ?? .shared }

    var numbers: [String] { model.blockLists.blocked }
    var isSystemList: Bool { model.blockLists.system == true }
    func name(for number: String) -> String? { model.name(for: number) }
    func unblock(_ number: String) { model.setBlocked(number, false) }
}
