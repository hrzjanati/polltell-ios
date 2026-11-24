import AVFoundation
import Perception
import SwiftUI
import PolTellCore

/// Recent link events, newest first (drops and their reasons), with a button to share them.
struct LinkLogView: View {
    @State private var text = LinkJournal.shared.text

    var body: some View {
        ScrollView {
            Text(text.isEmpty ? String(localized: "No events yet.") : text)
                .font(.caption.monospaced()).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading).padding()
                .environment(\.layoutDirection, .leftToRight)
        }
        .navigationTitle("Link log")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) { ShareLink(item: text) }
        }
        .refreshable { text = LinkJournal.shared.text }
    }
}

/// Blocked numbers (the Android phone's list), with swipe to unblock, as in Settings › Phone › Blocked Contacts.
struct BlockedListView: View {
    @State private var vm = BlockedListViewModel()

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        List {
            Section {
                ForEach(vm.numbers, id: \.self) { n in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.name(for: n) ?? n)
                        if vm.name(for: n) != nil {
                            Text(n).font(.caption).foregroundStyle(.secondary).environment(\.layoutDirection, .leftToRight)
                        }
                    }
                    .swipeActions {
                        Button("Unblock") { vm.unblock(n) }.tint(.red)
                    }
                    .contextMenu {
                        Button { vm.unblock(n) } label: { Label("Unblock", systemImage: "hand.raised.slash") }
                    }
                }
            } footer: {
                if vm.isSystemList {
                    Text("This is the Android phone's own block list: it refuses these calls and messages itself, whichever device you use.")
                } else {
                    Text("PolTell rejects these calls and does not forward these messages to your devices.")
                }
            }
        }
        .overlay {
            if vm.numbers.isEmpty { EmptyStateView("No Blocked Contacts", systemImage: "hand.raised") }
        }
        .navigationTitle("Blocked Contacts")
    }
}
