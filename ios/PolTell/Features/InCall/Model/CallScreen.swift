import AVFoundation
import CallKit
import Foundation
@_spi(PolTellApp) import PolTellCore
import UIKit

/// What the in-app call screen shows.
struct CallScreen: Equatable {
    var uuid: UUID
    var number: String
    var name: String?
    var state: String          // "dialing", "ringing", "active", "holding", "ended"
    var incoming: Bool
    var connectedAt: Date?
    var sub: Int?
    var muted = false
    var held = false
    var speaker = false
    /// Where the call's audio is now, the routes on offer and the selected one (the audio menu).
    var route: RouteKind = .receiver
    var routes: [RouteOption] = []
    var selectedRoute = RouteOption.iPhoneID
}
