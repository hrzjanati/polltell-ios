import Perception
import SwiftUI
import PolTellCore

struct RecentsView: View {
    @State private var vm = RecentsViewModel()
    @State private var detail: Contact?

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        @Perception.Bindable var vm = vm
        NavigationStack {
            List {
                if vm.showsFavourites {
                    Section {
                        FavouritesStrip(onAdd: { vm.addingFavourite = true })
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                    }
                }
                ForEach(vm.entries) { e in row(e) }
            }
            .listStyle(.plain)
            .sheet(isPresented: $vm.addingFavourite) {
                FavouritePicker().environment(\.appModel, AppModel.shared).environment(\.router, Router.shared)
            }
            .scrollDismissesKeyboard(.immediately)
            .refreshable { vm.refresh() }
            .onAppear { vm.markSeen() }
            .onChangeCompat(of: vm.latestID) { _ in vm.markSeenIfVisible() }
            .onChangeCompat(of: vm.appActive) { _ in vm.markSeenIfVisible() }
            .searchable(text: $vm.search, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Search name or number"))
            .overlay { if vm.showsNoResults { EmptyStateView(searchText: vm.search) } }
            .overlay { if !vm.hasRecents { EmptyStateView("No recent calls", systemImage: "clock") } }
            .navigationTitle("Recents")
            .navigationDestination(isPresented: Binding(get: { detail != nil }, set: { if !$0 { detail = nil } })) {
                if let c = detail { ContactDetailView(contact: c, customBack: true) }
            }
            .confirmationDialog(vm.blockingTitle,
                                isPresented: Binding(get: { vm.blocking != nil }, set: { if !$0 { vm.blocking = nil } }),
                                titleVisibility: .visible) {
                Button("Block Contact", role: .destructive) { vm.confirmBlock() }
            } message: {
                Text("You will not receive phone calls or messages from people on the block list.")
            }
            .confirmationDialog("Clear All Recents", isPresented: $vm.clearing, titleVisibility: .hidden) {
                Button("Clear All Recents", role: .destructive) { vm.clearAll() }
            } message: {
                Text("The call history will be deleted from your Android phone and all your devices.")
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") { vm.clearing = true }.disabled(!vm.canClear)
                }
                ToolbarItem(placement: .principal) {
                    Picker("", selection: $vm.filter) {
                        Text("All").tag(RecentsFilter.all)
                        Text("Missed").tag(RecentsFilter.missed)
                    }.pickerStyle(.segmented).frame(width: 180)
                }
            }
        }
    }

    private func row(_ e: CallEntry) -> some View {
        let kind = vm.kind(e)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(vm.title(e))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(kind.isMissed ? .red : .primary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if kind == .outgoing {
                        Image(systemName: "phone.arrow.up.right.fill").font(.system(size: 11))
                    }
                    if let sim = vm.simName(e) { Text(sim) }
                    if let d = vm.duration(e) { Text(d) }
                }
                .font(.system(size: 15)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(vm.time(e)).font(.system(size: 15)).foregroundStyle(.secondary)
            if let c = vm.contact(for: e) {
                Button { detail = c } label: {
                    Image(systemName: "info.circle").font(.system(size: 22)).foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Contact Info"))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { vm.call(e) }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            // Like Phone: a swipe deletes the entry at once (from the Android phone and every device).
            Button(role: .destructive) { vm.delete(e) } label: { Label("Delete", systemImage: "trash") }
            Button { vm.message(e) } label: { Label("Message", systemImage: "message") }.tint(.accentColor)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if let c = vm.contact(for: e) { favouriteButton(c) }
        }
        .contextMenu {
            Button { vm.call(e) } label: { Label("Call", systemImage: "phone") }
            Button { vm.message(e) } label: { Label("Message", systemImage: "message") }
            if let c = vm.contact(for: e) { favouriteButton(c) }
            Button { vm.copy(e) } label: { Label("Copy", systemImage: "doc.on.doc") }
            if vm.isBlocked(e) {
                Button { vm.unblock(e) } label: { Label("Unblock this Caller", systemImage: "hand.raised.slash") }
            } else {
                Button(role: .destructive) { vm.askToBlock(e) } label: { Label("Block this Caller", systemImage: "hand.raised") }
            }
            Button(role: .destructive) { vm.delete(e) } label: { Label("Delete from Recents", systemImage: "trash") }
        }
    }

    /// Add to or remove from Favourites, like the Phone app's swipe and menu on a recent call.
    private func favouriteButton(_ c: Contact) -> some View {
        Button { vm.toggleFavourite(c) } label: {
            Label(c.starred ? LocalizedStringKey("Remove from Favourites") : LocalizedStringKey("Add to Favourites"),
                  systemImage: c.starred ? "star.slash" : "star")
        }
        .tint(.orange)
        .disabled(!vm.isConnected)
    }
}

#if DEBUG
#Preview("Recents") { RecentsView() }
#endif
