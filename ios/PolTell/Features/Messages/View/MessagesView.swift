import Perception
import SwiftUI
import PolTellCore

struct MessagesView: View {
    @State private var vm = MessagesViewModel()

    @ViewBuilder private func muteButton(_ c: Conversation) -> some View {
        let muted = vm.isMuted(c)
        Button { vm.toggleMute(c) } label: {
            Label(muted ? "Show Alerts" : "Hide Alerts", systemImage: muted ? "bell" : "bell.slash")
        }
    }

    @ViewBuilder private func conversationMenu(_ c: Conversation) -> some View {
        muteButton(c)
        if vm.isBlocked(c) {
            Button { vm.unblock(c) } label: { Label("Unblock", systemImage: "hand.raised.slash") }
        } else {
            Button(role: .destructive) { vm.askToBlock(c) } label: { Label("Block", systemImage: "hand.raised") }
        }
        Button(role: .destructive) { vm.askToDelete(c) } label: { Label("Delete", systemImage: "trash") }
    }

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        @Perception.Bindable var vm = vm
        NavigationStack(path: $vm.path) {
            List {
                if !vm.search.isEmpty {
                    let hits = vm.searchHits
                    if hits.isEmpty { Text("No results").foregroundStyle(.secondary) }
                    ForEach(hits) { m in
                        NavigationLink(value: m.thread) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(vm.displayName(m.addr)).font(.subheadline.weight(.semibold))
                                Text(MessageText.plain(m.body)).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }
                    }
                } else {
                    ForEach(vm.conversations) { c in
                        NavigationLink(value: c.thread) { ConversationRow(conversation: c) }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) { vm.askToDelete(c) } label: { Label("Delete", systemImage: "trash") }
                                muteButton(c).tint(.secondaryAccentSolid)
                            }
                            .contextMenu { conversationMenu(c) }
                    }
                }
            }
            .listStyle(.plain)
            .overlay {
                if vm.showsEmptyState {
                    EmptyStateView(vm.emptyTitle, systemImage: "message", description: Text(vm.emptyDetail))
                }
            }
            .confirmationDialog(vm.deletingTitle,
                                isPresented: Binding(get: { vm.deleting != nil }, set: { if !$0 { vm.deleting = nil } }), titleVisibility: .visible) {
                Button("Delete Conversation", role: .destructive) { vm.confirmDelete() }
            } message: {
                Text("This conversation will be deleted from your Android phone and all your devices.")
            }
            .confirmationDialog(vm.blockingTitle,
                                isPresented: Binding(get: { vm.blocking != nil }, set: { if !$0 { vm.blocking = nil } }), titleVisibility: .visible) {
                Button("Block Contact", role: .destructive) { vm.confirmBlock() }
            } message: {
                Text("You will not receive phone calls or messages from people on the block list.")
            }
            .searchable(text: $vm.search, prompt: Text("Search messages"))
            .scrollDismissesKeyboard(.immediately)
            .refreshable { vm.refresh() }
            .navigationTitle("Messages")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { vm.startComposing() } label: { Image(systemName: "square.and.pencil").accessibilityLabel(Text("New Message")) }
                        .disabled(!vm.isConnected)
                }
            }
            .navigationDestination(for: Int64.self) { ThreadView(thread: $0) }
            .sheet(isPresented: $vm.composing, onDismiss: { vm.composeTo = "" }) {
                ComposeView(initialTo: vm.composeTo) { vm.composeFinished(thread: $0) }
                    .environment(\.appModel, AppModel.shared).environment(\.router, Router.shared)
            }
            .onChangeCompat(of: vm.routedThread) { _ in vm.takeRoutedThread() }
            // "Send message" on a number inside a bubble: its conversation, or a new one.
            .onChangeCompat(of: vm.routedCompose) { _ in vm.takeRoutedCompose() }
            // A notification tapped before this tab was ever shown sets the thread before we exist.
            .onAppear { vm.appeared() }
        }
    }
}

struct ConversationRow: View {
    let row: ConversationRowViewModel

    init(conversation: Conversation) { row = ConversationRowViewModel(conversation: conversation) }

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        HStack(spacing: 10) {
            // Unread marker, where Messages puts it.
            Circle().fill(row.isUnread ? Color.accentColor : Color.clear).frame(width: 10, height: 10)
            Avatar(name: row.name, photo: row.photo, size: 46)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(row.name).font(.body.weight(.semibold)).lineLimit(1)
                    if row.isMuted {
                        Image(systemName: "moon.fill").font(.caption).foregroundStyle(.secondary)
                            .accessibilityLabel(Text("Alerts hidden"))
                    }
                    if row.isBlocked {
                        Image(systemName: "hand.raised.fill").font(.caption).foregroundStyle(.secondary)
                            .accessibilityLabel(Text("Blocked"))
                    }
                    Spacer()
                    Text(row.time).font(.subheadline)
                        .foregroundStyle(row.isUnread ? Color.accentColor : Color.secondary)
                }
                Text(row.preview).font(.subheadline)
                    .foregroundStyle(row.isUnread ? Color.primary : Color.secondary).lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 36, alignment: .topLeading)
                if let sim = row.simName {
                    Label(sim, systemImage: "simcard").font(.caption2).foregroundStyle(.secondary).labelStyle(.titleAndIcon)
                }
            }
        }
        .padding(.vertical, 2)
        .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 14))
        .alignmentGuide(.listRowSeparatorLeading) { _ in 76 }
    }
}

#if DEBUG
#Preview("Messages") { MessagesView() }
#endif
