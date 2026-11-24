import Perception
import SwiftUI
import PolTellCore

struct ThreadView: View {
    @State private var vm: ThreadViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    init(thread: Int64) { _vm = State(initialValue: ThreadViewModel(thread: thread)) }

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        @Perception.Bindable var vm = vm
        let msgs = vm.messages
        let name = vm.name
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.rows) { r in
                        if let h = r.header {
                            Text(h).font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                                .padding(.top, 14).padding(.bottom, 6)
                        }
                        Bubble(message: r.message, tail: r.tail)
                            .padding(.bottom, r.tail ? 8 : 2)
                            .id(r.message.id)
                        if let st = r.status {
                            Text(st).font(.caption2.weight(r.failed ? .semibold : .regular))
                                .foregroundStyle(r.failed ? Color.red : Color.secondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .padding(.trailing, 6).padding(.top, -4).padding(.bottom, 8)
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .bottomAnchoredCompat(proxy, last: msgs.last?.id)
            .scrollDismissesKeyboard(.interactively)
            .onChangeCompat(of: msgs.count) { _ in
                if let last = msgs.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                vm.messagesChanged()
            }
        }
        .safeAreaInset(edge: .bottom) { composer }
        // Like Messages: no tab bar inside a conversation (it sat under the composer and the keyboard).
        .toolbar(.hidden, for: .tabBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Avatar(name: name, photo: vm.photo, size: 26)
                    Text(name).font(.caption2).lineLimit(1)
                }
                .accessibilityElement(children: .combine)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { vm.call() } label: { Image(systemName: "phone").accessibilityLabel(Text("Call")) }
                    .disabled(!vm.canAct)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    let muted = vm.isMuted
                    Color.clear.frame(width: 0, height: 0).onAppear { focused = false }
                    Button { vm.toggleMute() } label: {
                        Label(muted ? "Show Alerts" : "Hide Alerts", systemImage: muted ? "bell" : "bell.slash")
                    }
                    if vm.isBlocked {
                        Button { vm.unblock() } label: { Label("Unblock this Caller", systemImage: "hand.raised.slash") }
                    } else {
                        Button(role: .destructive) { vm.confirmBlock = true } label: { Label("Block this Caller", systemImage: "hand.raised") }
                    }
                    Button(role: .destructive) { vm.confirmDelete = true } label: { Label("Delete Conversation", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis.circle").accessibilityLabel(Text("More")) }
                .disabled(!vm.canAct)
            }
        }
        .confirmationDialog(name, isPresented: $vm.confirmDelete, titleVisibility: .visible) {
            Button("Delete Conversation", role: .destructive) { vm.deleteConversation(); dismiss() }
        } message: {
            Text("This conversation will be deleted from your Android phone and all your devices.")
        }
        .confirmationDialog(name, isPresented: $vm.confirmBlock, titleVisibility: .visible) {
            Button("Block Contact", role: .destructive) { vm.block() }
        } message: {
            Text("You will not receive phone calls or messages from people on the block list.")
        }
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-PolTellDemoFocus") {   // keyboard screenshots
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { focused = true }
            }
            #endif
            vm.appeared()
        }
        .onDisappear { vm.disappeared() }
    }

    private var composer: some View {
        @Perception.Bindable var vm = vm
        return HStack(alignment: .bottom, spacing: 8) {
            SimPicker(sub: Binding(get: { vm.sub }, set: { vm.choose(sim: $0) }))
                .padding(.bottom, 3)
            HStack(alignment: .bottom, spacing: 4) {
                TextField("Text Message · SMS", text: $vm.text, axis: .vertical)
                    .lineLimit(1...6)
                    .focused($focused)
                    .padding(.leading, 12).padding(.vertical, 7)
                Button { vm.send() } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 30)).accessibilityLabel(Text("Send"))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, vm.canSend ? Color.green : Color(.systemGray3))
                }
                .disabled(!vm.canSend)
                .padding(.trailing, 3).padding(.bottom, 3)
                .accessibilityLabel(Text("Send"))
            }
            .glassSurface(RoundedRectangle(cornerRadius: 22, style: .continuous), interactive: false)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
    }
}

#if DEBUG
#Preview("Thread") { NavigationStack { ThreadView(thread: 1) } }
#Preview("Thread (rich text)") { NavigationStack { ThreadView(thread: 5) } }
#endif
