import Perception
import SwiftUI
import PolTellCore

/// One contact's page: the live copy of the contact, its quick actions, blocking and Favourites.
@MainActor @Perceptible
final class ContactDetailViewModel {
    var editing = false
    var confirmBlock = false
    @PerceptionIgnored private let original: Contact
    @PerceptionIgnored private let model: AppModel
    @PerceptionIgnored private let router: Router

    init(contact: Contact, model: AppModel? = nil, router: Router? = nil) {
        original = contact
        self.model = model ?? .shared
        self.router = router ?? .shared
    }

    /// The contact as it is now: edits and re-syncs replace it; the tapped copy is the fallback.
    var contact: Contact { model.data.contacts.first { $0.id == original.id } ?? original }
    var isConnected: Bool { model.linkState.isConnected }
    var isBlocked: Bool { contact.phones.contains { model.isBlocked($0.n) } }

    func formatted(_ number: String) -> String { model.formatted(number) }

    func call(_ number: String) { model.dial(number, sub: model.preferredSim(for: number)) }

    func openThread(_ number: String) {
        if let t = model.thread(for: number) {
            router.open(thread: t)
        } else {
            router.compose(to: number)   // no conversation yet: a new message to this number
        }
    }

    func mail(_ address: String) {
        if let u = URL(string: "mailto:\(address)") { UIApplication.shared.open(u) }
    }

    func toggleFavourite() { model.setStarred(contact.id, !contact.starred) }

    /// Like Contacts: one row for the whole contact (all of its numbers).
    func blockTapped() {
        if isBlocked { for p in contact.phones where model.isBlocked(p.n) { model.setBlocked(p.n, false) } }
        else { confirmBlock = true }
    }

    func block() { for p in contact.phones { model.setBlocked(p.n, true) } }
}
