import Perception
import SwiftUI
import PolTellCore

/// The contact list: Favourites, the A–Z sections and the search.
@MainActor @Perceptible
final class ContactsViewModel {
    var search = ""
    var adding = false
    @PerceptionIgnored private let model: AppModel

    init(model: AppModel? = nil) { self.model = model ?? .shared }

    var isConnected: Bool { model.linkState.isConnected }
    var isEmpty: Bool { model.data.contacts.isEmpty }
    var showsFavourites: Bool { search.isEmpty && !model.favourites.isEmpty }
    var favourites: [Contact] { model.favourites }
    var sections: [ContactSection] { ContactSection.make(from: filtered) }

    private var filtered: [Contact] {
        guard !search.isEmpty else { return model.data.contacts }
        return model.data.contacts.filter { c in
            SearchText.matches(search, names: [c.name] + c.emails, numbers: c.phones.map(\.n))
        }
    }

    func refresh() { model.requestSync() }
    func startAdding() { hideKeyboard(); adding = true }
}
