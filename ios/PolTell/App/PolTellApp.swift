import Intents
import UserNotifications
import Perception
import SwiftUI
import PolTellCore
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

@main
struct PolTellApp: App {
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
