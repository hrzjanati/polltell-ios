import Foundation
import Perception
import PolTellCore

struct SyncBodyV1: Encodable {
    var sms: Int64
    var calls: Int64
    var contacts: String
    var codecs: [String]
    var client: ClientHello
    /// The extensions this app speaks (protocol §7.2); left out when there are none.
    var caps: [String]?
}

/// The link as the extensions see it. AppModel keeps `isUp`, `transport` and `inCall` current (main thread).
final class LinkExtensionPort: ExtensionPort {
    let link: PolTellLink
    var isUp = false, transport = "none", inCall = false
    init(link: PolTellLink) { self.link = link }
    func send(_ type: String, _ body: any Encodable, expectReply: Bool, re: Int?) -> Int? {
        guard isUp else { return nil }
        return link.send(type, body, expectReply: expectReply, re: re)
    }
}

/// How this client introduces itself to the Android phone (the protocol allows several clients).
enum Platform {
    static let kind = "iphone"
    static let clientName = "iPhone"
}
