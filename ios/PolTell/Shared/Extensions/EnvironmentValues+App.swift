import Perception
import SwiftUI

// Helpers that let the app run on iOS 16 while using the newer APIs where the system has them.

private struct AppModelKey: EnvironmentKey {
    @MainActor static var defaultValue: AppModel { AppModel.shared }
}

private struct RouterKey: EnvironmentKey {
    @MainActor static var defaultValue: Router { Router.shared }
}

extension EnvironmentValues {
    var appModel: AppModel {
        get { self[AppModelKey.self] }
        set { self[AppModelKey.self] = newValue }
    }
    var router: Router {
        get { self[RouterKey.self] }
        set { self[RouterKey.self] = newValue }
    }
}
