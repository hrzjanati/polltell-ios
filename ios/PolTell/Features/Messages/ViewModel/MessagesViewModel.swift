import Perception
import SwiftUI
import PolTellCore

/// The conversation list: search, the actions on a conversation, and which thread is open.
@MainActor @Perceptible
final class MessagesViewModel {
    var search = ""
    var path: [Int64] = []
    var composing = false
    var composeTo = ""
    var deleting: Conversation?
    var blocking: String?

    @PerceptionIgnored private let model: AppModel
    @PerceptionIgnored private let router: Router

    init(model: AppModel? = nil, router: Router? = nil) {
        self.model = model ?? .shared
        self.router = router ?? .shared
    }

    var isConnected: Bool { model.linkState.isConnected }
    var conversations: [Conversation] { model.conversations }
    var showsEmptyState: Bool { conversations.isEmpty && search.isEmpty }
    var emptyTitle: LocalizedStringKey { model.syncing ? "Syncing…" : "No messages" }
    var emptyDetail: LocalizedStringKey { model.isPaired ? "" : "Pair with your Android phone in the Link tab." }
    var deletingTitle: String { deleting.map { model.displayName($0.address) } ?? "" }
    var blockingTitle: String { blocking.map { model.displayName($0) } ?? "" }
    var routedThread: Int64? { router.openThread }
    var routedCompose: String? { router.composeTo }

    /// Messages matching the search text, newest first.
    var searchHits: [Sms] {
        model.data.sms.filter { SearchText.matches(search, names: [$0.body, model.name(for: $0.addr) ?? ""], numbers: [$0.addr]) }
            .sorted { $0.date > $1.date }.prefix(200).map { $0 }
    }

    func displayName(_ address: String) -> String { model.displayName(address) }
    func isMuted(_ c: Conversation) -> Bool { model.isMuted(c.thread) }
    func toggleMute(_ c: Conversation) { model.setMuted(c.thread, !isMuted(c)) }
    func isBlocked(_ c: Conversation) -> Bool { model.isBlocked(c.address) }
    func unblock(_ c: Conversation) { model.setBlocked(c.address, false) }
    func askToBlock(_ c: Conversation) { blocking = c.address }
    func confirmBlock() { if let n = blocking { model.setBlocked(n, true) } }
    func askToDelete(_ c: Conversation) { deleting = c }
    func confirmDelete() { if let c = deleting { model.deleteConversation(c.thread) } }
    func refresh() { model.requestSync() }
    func startComposing() { hideKeyboard(); composing = true }

    func composeFinished(thread: Int64?) {
        composing = false
        if let thread { path = [thread] }
    }

    func takeRoutedThread() {
        if let t = router.openThread { path = [t]; router.openThread = nil }
    }

    /// "Send message" on a number inside a bubble: its conversation, or a new one.
    func takeRoutedCompose() {
        guard let n = router.composeTo else { return }
        router.composeTo = nil
        if let t = model.thread(for: n) { path = [t] } else { composeTo = n; path = []; composing = true }
    }

    func appeared() {
        takeRoutedThread()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-PolTellDemoCompose") { composing = true }   // keyboard screenshots
        #endif
    }
}
