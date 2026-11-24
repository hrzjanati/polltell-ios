import Foundation
import Perception
import PolTellCore

struct Conversation: Identifiable, Hashable {
    var id: Int64 { thread }
    let thread: Int64
    let address: String
    let last: Sms
    let unread: Int
}
