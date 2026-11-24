import Perception
import SwiftUI
import PolTellCore

struct RootView: View {
    @State private var vm = RootViewModel()

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        @Perception.Bindable var vm = vm
        VStack(spacing: 0) {
            // The capsule has its own row above the tabs: a navigation bar's buttons (add, compose) can then never sit under it.
            StatusStrip()
            ReturnToCallBanner()
            RemoteCallBanner()
            TabView(selection: $vm.tab) {
                RecentsView()
                    .tabItem { Label("Recents", systemImage: "clock") }
                    .badge(vm.missedCount)
                    .tag(Router.Tab.recents)
                ContactsView()
                    .tabItem { Label("Contacts", systemImage: "person.crop.circle") }
                    .tag(Router.Tab.contacts)
                KeypadView()
                    .tabItem { Label("Keypad", systemImage: "circle.grid.3x3.fill") }
                    .tag(Router.Tab.keypad)
                MessagesView()
                    .tabItem { Label("Messages", systemImage: "message") }
                    .badge(vm.unreadTotal)
                    .tag(Router.Tab.messages)
                LinkView()
                    .tabItem { Label("Link", systemImage: "antenna.radiowaves.left.and.right") }
                    .tag(Router.Tab.link)
            }
        }
        .overlay(alignment: .bottom) {
            if let err = vm.lastError {
                Text(err)
                    .font(.footnote)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 64)
                    .onTapGesture { vm.dismissError() }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            if let n = vm.notice {
                Label(n, systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 64)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .alert(item: $vm.dialRequest) { req in
            let linked = vm.isConnected
            let who = vm.contactName(req.number)
            return Alert(
                title: Text("Call \(who ?? vm.formatted(req.number))?"),
                message: Text(linked
                    ? (who == nil ? "The call goes through your Android phone." : "\(vm.formatted(req.number)) · through your Android phone.")
                    : "The Android phone is not connected. Keep it nearby and open the Link tab, then call from the Keypad."),
                primaryButton: .default(Text(linked ? "Call" : "Show in Keypad")) { vm.confirm(req) },
                secondaryButton: .cancel { vm.cancel(req) })
        }
        .animation(.default, value: vm.lastError)
        .animation(.default, value: vm.notice)
        .fullScreenCover(isPresented: $vm.showsCallScreen) {
            // Presented content does not always inherit environment objects: pass them explicitly.
            InCallView().environment(\.appModel, AppModel.shared).environment(\.router, Router.shared)
        }
        .tint(Color("AccentColor"))
        .task { vm.opened() }
    }
}

#if DEBUG
#Preview("Root") { RootView() }
#endif
