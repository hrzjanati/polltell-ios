import PolTellCore

/// One row of a conversation: the message plus what Messages derives from its neighbours.
struct TranscriptRow: Identifiable {
    let message: Sms
    let header: String?      // centred day/time line above the bubble
    let tail: Bool           // last bubble of a run from the same side
    let status: String?      // under the newest outgoing bubble
    let failed: Bool
    var id: Int64 { message.id }
}
