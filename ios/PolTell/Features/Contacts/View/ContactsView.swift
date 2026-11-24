import Perception
import SwiftUI
import PolTellCore

struct ContactsView: View {
    @State private var vm = ContactsViewModel()

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        @Perception.Bindable var vm = vm
        NavigationStack {
            List {
                // Favourites first, as in the Phone app (the Android phone's starred contacts).
                if vm.showsFavourites {
                    Section("Favourites") {
                        ForEach(vm.favourites) { c in FavouriteRow(contact: c) }
                    }
                }
                // A–Z sections, as in the Contacts app ("#" for names that do not start with a letter).
                ForEach(vm.sections, id: \.letter) { group in
                    Section(group.letter) {
                        ForEach(group.contacts) { c in
                            NavigationLink {
                                ContactDetailView(contact: c)
                            } label: {
                                HStack(spacing: 12) {
                                    Avatar(name: c.name, photo: c.photo, size: 36)
                                    Text(c.name)
                                    if c.starred { Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow) }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .overlay {
                if vm.isEmpty { EmptyStateView("No contacts", systemImage: "person.crop.circle") }
            }
            .searchable(text: $vm.search, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Search contacts"))
            .scrollDismissesKeyboard(.immediately)
            .refreshable { vm.refresh() }
            .navigationTitle("Contacts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { vm.startAdding() } label: { Image(systemName: "plus").accessibilityLabel(Text("Add Contact")) }.disabled(!vm.isConnected)
                }
            }
            .sheet(isPresented: $vm.adding) { AddContactView().environment(\.appModel, AppModel.shared).environment(\.router, Router.shared) }
        }
    }
}

#if DEBUG
#Preview("Contacts") { ContactsView() }
#Preview("Contact") {
    NavigationStack {
        if let c = AppModel.shared.data.contacts.first { ContactDetailView(contact: c) }
    }
}
#Preview("Add contact") { AddContactView() }
#endif
