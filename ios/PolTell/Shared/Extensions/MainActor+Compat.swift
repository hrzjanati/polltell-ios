import Perception
import SwiftUI

extension MainActor {
    /// `MainActor.assumeIsolated` needs iOS 17; the callers are already on the main queue.
    static func assumeIsolatedCompat<T>(_ body: @MainActor @escaping () -> T) -> T {
        if #available(iOS 17, *) { return assumeIsolated(body) }
        return unsafeBitCast(body, to: (() -> T).self)()
    }
}
