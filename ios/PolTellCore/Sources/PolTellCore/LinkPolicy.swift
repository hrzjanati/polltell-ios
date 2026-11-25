import Foundation

/// A counter shared across threads under an unfair lock held for one increment.
final class RequestIds: @unchecked Sendable {
    private let lock = UnfairLock()
    private var last = 1
    func next() -> Int { lock.lock(); defer { lock.unlock() }; last += 1; return last }
}

/// When to try the link again after a failure (pure, for tests): the failures of the last minute decide. Up to three
/// reconnect at once (a pending connect, plus a scan after 1 s); more back off 2 s per failure, at most 30 s.
enum ReconnectPolicy {
    enum Action: Equatable { case atOnce, backOff(Double) }
    static let window: TimeInterval = 60
    static func next(failures: [Date], now: Date) -> (failures: [Date], action: Action) {
        let recent = failures.filter { now.timeIntervalSince($0) < window } + [now]
        return (recent, recent.count <= 3 ? .atOnce : .backOff(Double(min(30, 2 * recent.count))))
    }
}
