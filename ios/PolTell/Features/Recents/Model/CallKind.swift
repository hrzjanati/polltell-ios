import Foundation

/// The kind of a call-log entry, from the Android phone's numeric call type.
enum CallKind {
    case incoming, outgoing, missed, blocked, other

    init(type: Int) {
        switch type {
        case 1: self = .incoming
        case 2: self = .outgoing
        case 3, 5: self = .missed   // 3 missed, 5 rejected
        case 6: self = .blocked
        default: self = .other
        }
    }

    var isMissed: Bool { self == .missed }

    var symbol: String {
        switch self {
        case .incoming: "phone.arrow.down.left"
        case .outgoing: "phone.arrow.up.right"
        case .missed: "phone.down"
        case .blocked: "nosign"
        case .other: "phone"
        }
    }
}

/// The All / Missed switch above the call list.
enum RecentsFilter: Hashable { case all, missed }
