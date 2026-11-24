import Perception
import SwiftUI
import PolTellCore

/// What one row of the conversation list says about its conversation.
@MainActor
struct ConversationRowViewModel {
    let conversation: Conversation
    private let model: AppModel

    init(conversation: Conversation, model: AppModel? = nil) {
        self.conversation = conversation
        self.model = model ?? .shared
    }

    var name: String { model.displayName(conversation.address) }
    var photo: String? { model.photo(for: conversation.address) }
    var isUnread: Bool { conversation.unread > 0 }
    var isMuted: Bool { model.isMuted(conversation.thread) }
    var isBlocked: Bool { model.isBlocked(conversation.address) }
    var time: String { shortTime(conversation.last.date) }
    var preview: String { MessageText.plain(conversation.last.body) }
    var simName: String? { model.simName(conversation.last.sub) }
}
