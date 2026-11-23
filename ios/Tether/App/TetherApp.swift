import Intents
import UserNotifications
import Perception
import SwiftUI
import TetherCore
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    /// The app is being terminated while it still ran (swiped away from the foreground or a running background):
    /// calls stop reaching this iPhone until it is opened again, so say so.
    func applicationWillTerminate(_ application: UIApplication) {
        MainActor.assumeIsolatedCompat {
            guard AppModel.shared.link.isPaired else { return }
            let c = UNMutableNotificationContent()
            c.title = String(localized: "Calls paused")
            c.body = String(localized: "The app was closed. Open it again to keep receiving calls and messages from your Android phone.")
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "app-closed", content: c,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)))
        }
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Create the model (and with it the CBCentralManager) right away: when iOS relaunches us in the
        // background for a Bluetooth event, state restoration needs the manager during launch.
        Notifications.shared.setUp()
        MainActor.assumeIsolatedCompat {
            _ = AppModel.shared.calls // CXProvider must exist before a call can be reported
        }
        return true
    }
}

/// Simple navigation requests (e.g. tapping an SMS notification).
@MainActor @Perceptible
final class Router {
    static let shared = Router()
    var tab: Tab = .messages
    var openThread: Int64?

    enum Tab: Hashable { case recents, contacts, keypad, messages, link }

    func open(thread: Int64) {
        tab = .messages
        openThread = thread
    }

    /// A number to call that came from outside the app, waiting for the owner's tap ("Call …?").
    var dialRequest: DialRequest?
    /// A number for the Keypad to show (the Keypad takes it and clears it).
    var keypadNumber: String?

    struct DialRequest: Identifiable, Equatable {
        let id = UUID()
        let number: String
    }

    /// tel: / telprompt: (as the default calling app) and tether:// links. Any web page can open these, so they
    /// never dial by themselves: the number is shown and the owner taps Call.
    func open(url: URL) {
        guard let n = DialLink.number(from: url) else { return }
        ask(n)
    }

    /// A tap in the Phone app's Recents, Siri or the Contacts app: an INStartCallIntent. The owner chose to call
    /// in system UI, so it dials at once when the Android phone is linked (waiting a few seconds for the link
    /// after a cold launch), and asks otherwise.
    func continueActivity(_ activity: NSUserActivity) {
        guard let n = Router.number(from: activity.interaction?.intent) else { return }
        callNow(n)
    }

    /// The number of a call intent from system UI (the first contact's handle), if it is dialable.
    nonisolated static func number(from intent: INIntent?) -> String? {
        let handle = (intent as? INStartCallIntent)?.contacts?.first?.personHandle?.value
            ?? (intent as? INStartAudioCallIntent)?.contacts?.first?.personHandle?.value
        return handle.flatMap(DialLink.dialable)
    }

    /// Half-second checks for the link before `callNow` asks instead (shortened by the unit tests).
    @PerceptionIgnored var linkWaitTries = 16

    /// Dials at once if the link comes up within a few seconds, else asks.
    func callNow(_ number: String) {
        Task { @MainActor in
            let m = AppModel.shared
            for _ in 0..<linkWaitTries where !m.linkState.isConnected { try? await Task.sleep(for: .milliseconds(500)) }
            if m.linkState.isConnected && m.callScreen == nil { m.dial(number, sub: nil) } else { ask(number) }
        }
    }

    func ask(_ number: String) {
        tab = .keypad
        dialRequest = DialRequest(number: number)
    }

    /// A number to write to (from a bubble's phone-number menu).
    var composeTo: String?
    func compose(to number: String) {
        tab = .messages
        composeTo = number
    }
}

@main
struct TetherApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            // As the unit tests' host the app shows nothing: the tests drive the model, not the screens.
            if AppModel.runningTests { Color.clear } else { content }
        }
    }

    private var content: some View {
        RootView()
            .environment(\.appModel, AppModel.shared)
            .environment(\.router, Router.shared)
            .onOpenURL { Router.shared.open(url: $0) }
            .onContinueUserActivity("INStartCallIntent") { Router.shared.continueActivity($0) }
            .onContinueUserActivity("INStartAudioCallIntent") { Router.shared.continueActivity($0) }
            .onChangeCompat(of: phase) { p in
                AppModel.shared.appActive = p == .active
                if p == .active {
                    let m = AppModel.shared
                    m.requestSync()
                    // Coming back to the app during a call opens the call screen, like the Phone app.
                    if let c = m.callScreen, c.state != "ended", c.state != "ringing" {
                        m.callScreenDismissed = false
                        m.showCallScreen = true
                    }
                }
            }
    }
}
