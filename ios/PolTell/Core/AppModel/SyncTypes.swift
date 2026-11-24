import Foundation
import Perception
import PolTellCore

struct SyncBodyV1: Encodable {
    var sms: Int64
    var calls: Int64
    var contacts: String
    var codecs: [String]
    var client: ClientHello
}

/// How this client introduces itself to the Android phone (the protocol allows several clients).
enum Platform {
    static let kind = "iphone"
    static let clientName = "iPhone"
}
