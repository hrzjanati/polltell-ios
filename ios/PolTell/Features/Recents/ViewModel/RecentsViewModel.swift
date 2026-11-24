import Perception
import SwiftUI
import PolTellCore

/// Everything the Recents screen decides: which calls are listed, what a row says, and what its actions do.
/// The view only draws; the shared `AppModel` stays the source of the data.
@MainActor @Perceptible
final class RecentsViewModel {
    var filter: RecentsFilter = .all
    var search = ""
    var blocking: String?
    var clearing = false
    var addingFavourite = false

    @PerceptionIgnored private let model: AppModel
    @PerceptionIgnored private let router: Router

    init(model: AppModel? = nil, router: Router? = nil) {
        self.model = model ?? .shared
        self.router = router ?? .shared
    }

    // MARK: State for the view

    var isConnected: Bool { model.linkState.isConnected }
    var hasRecents: Bool { !model.data.recents.isEmpty }
    var showsFavourites: Bool { search.isEmpty }
    var showsNoResults: Bool { !search.isEmpty && entries.isEmpty }
    var canClear: Bool { hasRecents && isConnected }
    var blockingTitle: String { blocking.map { model.displayName($0) } ?? "" }

    var entries: [CallEntry] {
        var list = model.data.recents
        if filter == .missed { list = list.filter { CallKind(type: $0.type).isMissed } }
        if !search.isEmpty {
            list = list.filter { e in SearchText.matches(search, names: [e.name ?? "", model.name(for: e.num) ?? ""], numbers: [e.num]) }
        }
        return Array(list.prefix(500))
    }

    // MARK: Row text

    func title(_ e: CallEntry) -> String { e.name ?? model.displayName(e.num) }
    func simName(_ e: CallEntry) -> String? { model.simName(e.sub) }
    func time(_ e: CallEntry) -> String { shortTime(e.date) }
    func duration(_ e: CallEntry) -> String? {
        e.dur > 0 ? Duration.seconds(e.dur).formatted(.time(pattern: .minuteSecond)) : nil
    }
    func kind(_ e: CallEntry) -> CallKind { CallKind(type: e.type) }

    // MARK: Actions

    func call(_ e: CallEntry) { model.dial(e.num, sub: e.sub) }
    func delete(_ e: CallEntry) { model.deleteRecents([e.id]) }
    func copy(_ e: CallEntry) { UIPasteboard.general.string = e.num }
    func isBlocked(_ e: CallEntry) -> Bool { model.isBlocked(e.num) }
    func unblock(_ e: CallEntry) { model.setBlocked(e.num, false) }
    func askToBlock(_ e: CallEntry) { blocking = e.num }
    func confirmBlock() { if let n = blocking { model.setBlocked(n, true) } }
    func clearAll() { model.clearRecents() }
    func refresh() { model.requestSync() }

    func message(_ e: CallEntry) {
        router.tab = .messages
        if let t = model.thread(for: e.num) { router.openThread = t } else { router.compose(to: e.num) }
    }

    /// The saved contact a number belongs to (Favourites hold contacts, so an unknown number has none).
    func contact(for e: CallEntry) -> Contact? {
        let key = PhoneNumber.matchKey(e.num)
        return model.data.contacts.first { c in c.phones.contains { PhoneNumber.matchKey($0.n) == key } }
    }

    func toggleFavourite(_ c: Contact) { model.setStarred(c.id, !c.starred) }

    // MARK: Missed-call badge

    /// Seen only while the user can see it: a call missed in the background keeps its badge.
    func markSeen() { model.markRecentsSeen() }
    func markSeenIfVisible() { if router.tab == .recents && model.appActive { model.markRecentsSeen() } }
    var latestID: Int64? { model.data.recents.first?.id }
    var appActive: Bool { model.appActive }
}
