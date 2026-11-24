import Perception
import SwiftUI
import PolTellCore

/// Favourites: the row above Recents and the picker that adds contacts to it.
@MainActor @Perceptible
final class FavouritesViewModel {
    var search = ""
    @PerceptionIgnored private let model: AppModel

    init(model: AppModel? = nil) { self.model = model ?? .shared }

    var isConnected: Bool { model.linkState.isConnected }
    var favourites: [Contact] { model.favourites }

    /// Contacts that are not Favourites yet, A to Z, narrowed by the search text.
    var candidates: [Contact] {
        model.data.contacts
            .filter { !$0.starred && (search.isEmpty || SearchText.matches(search, names: [$0.name], numbers: $0.phones.map(\.n))) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func firstName(_ c: Contact) -> String { c.name.split(separator: " ").first.map(String.init) ?? c.name }

    func call(_ c: Contact) {
        guard let p = c.phones.first else { return }
        model.dial(p.n, sub: model.preferredSim(for: p.n))
    }

    func canCall(_ c: Contact) -> Bool { c.phones.first != nil }
    func add(_ c: Contact) { model.setStarred(c.id, true) }
    func remove(_ c: Contact) { model.setStarred(c.id, false) }
}
