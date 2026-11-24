import Perception
import SwiftUI
import PolTellCore

/// One conversation: its transcript rows, the draft being typed, and the actions in its menu.
@MainActor @Perceptible
final class ThreadViewModel {
    let thread: Int64
    var text = ""
    var sub: Int?
    var confirmDelete = false
    var confirmBlock = false

    @PerceptionIgnored private let model: AppModel

    init(thread: Int64, model: AppModel? = nil) {
        self.thread = thread
        self.model = model ?? .shared
    }

    // MARK: Conversation

    var messages: [Sms] { model.messages(thread: thread) }
    var address: String { messages.last?.addr ?? "" }
    var name: String { model.displayName(address) }
    var photo: String? { model.photo(for: address) }
    var isConnected: Bool { model.linkState.isConnected }
    var canAct: Bool { isConnected && !address.isEmpty }
    var isMuted: Bool { model.isMuted(thread) }
    var isBlocked: Bool { model.isBlocked(address) }
    var canSend: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && canAct }

    /// The transcript with what Messages derives from neighbours: time lines, bubble tails and the delivery status.
    var rows: [TranscriptRow] {
        let msgs = messages
        var out: [TranscriptRow] = []
        let lastMine = msgs.last(where: { !$0.incoming })?.id
        for (i, m) in msgs.enumerated() {
            let prev = i > 0 ? msgs[i - 1] : nil
            let next = i + 1 < msgs.count ? msgs[i + 1] : nil
            let gap: Int64 = 15 * 60_000
            // With two SIMs the line above a run says which SIM it is on, and a change of SIM starts a new run.
            let sim = model.simName(m.sub)
            let simChanged = sim != nil && prev != nil && prev!.sub != m.sub
            let header = (prev == nil || m.date - prev!.date > gap || simChanged)
                ? transcriptTime(m.date) + (sim.map { " · \($0)" } ?? "") : nil
            let tail = next == nil || next!.incoming != m.incoming || next!.date - m.date > gap
            var status: String?
            if m.box == 5 { status = String(localized: "Not Delivered") }
            else if m.box == 4 || m.box == 6 { status = String(localized: "Sending…") }
            else if m.id == lastMine && !m.incoming { status = String(localized: "Sent as Text Message") }
            out.append(TranscriptRow(message: m, header: header, tail: tail, status: status, failed: m.box == 5))
        }
        return out
    }

    // MARK: Actions

    func send() {
        model.sendSms(to: address, body: text, sub: sub)
        text = ""
    }

    func choose(sim: Int?) {
        sub = sim
        model.setPreferredSim(sim, for: address)
    }

    func call() { model.dial(address, sub: sub) }
    func toggleMute() { model.setMuted(thread, !isMuted) }
    func unblock() { model.setBlocked(address, false) }
    func block() { model.setBlocked(address, true) }
    func deleteConversation() { model.deleteConversation(thread) }

    func messagesChanged() {
        if model.appActive { model.markRead(thread: thread) }
    }

    func appeared() {
        model.openThread = thread
        model.markRead(thread: thread)
        text = model.draft(for: address)
        sub = model.preferredSim(for: address)
    }

    func disappeared() {
        // The view that replaced this one (the real thread after a first text) may already have set its own.
        if model.openThread == thread { model.openThread = nil }
        model.setDraft(text, for: address)
    }
}
