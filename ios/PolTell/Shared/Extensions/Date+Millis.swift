import Perception
import SwiftUI
import PolTellCore

extension Date {
    init(millis: Int64) { self.init(timeIntervalSince1970: Double(millis) / 1000) }
}
