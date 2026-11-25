#if canImport(os)
import os
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#elseif canImport(WinSDK)
import WinSDK
#endif

/// A short-critical-section lock that is safe on a real-time audio thread: `os_unfair_lock` on Apple platforms
/// (as before), a `pthread_mutex_t` elsewhere (an `SRWLOCK` on Windows). The lock word lives in its own allocation,
/// so its address never moves.
final class UnfairLock: @unchecked Sendable {
    #if canImport(os)
    private let raw: UnsafeMutablePointer<os_unfair_lock>
    #elseif canImport(WinSDK)
    private let raw: UnsafeMutablePointer<SRWLOCK>
    #else
    private let raw: UnsafeMutablePointer<pthread_mutex_t>
    #endif

    init() {
        raw = .allocate(capacity: 1)
        #if canImport(os)
        raw.initialize(to: os_unfair_lock())
        #elseif canImport(WinSDK)
        InitializeSRWLock(raw)
        #else
        raw.initialize(to: pthread_mutex_t())
        pthread_mutex_init(raw, nil)
        #endif
    }

    deinit {
        #if !canImport(os) && !canImport(WinSDK)
        pthread_mutex_destroy(raw)
        #endif
        raw.deallocate()
    }

    @inline(__always) func lock() {
        #if canImport(os)
        os_unfair_lock_lock(raw)
        #elseif canImport(WinSDK)
        AcquireSRWLockExclusive(raw)
        #else
        pthread_mutex_lock(raw)
        #endif
    }

    @inline(__always) func unlock() {
        #if canImport(os)
        os_unfair_lock_unlock(raw)
        #elseif canImport(WinSDK)
        ReleaseSRWLockExclusive(raw)
        #else
        pthread_mutex_unlock(raw)
        #endif
    }
}
