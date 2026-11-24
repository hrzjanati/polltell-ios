import Perception
import SwiftUI
import PolTellCore

struct ContactDetailView: View {
    @State private var vm: ContactDetailViewModel
    @Environment(\.dismiss) private var dismiss
    private let customBack: Bool

    /// `customBack` draws an explicit Back button, for when the screen is pushed from a place where the system one is missing (Recents).
    init(contact: Contact, customBack: Bool = false) {
        self.customBack = customBack
        _vm = State(initialValue: ContactDetailViewModel(contact: contact))
    }

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        @Perception.Bindable var vm = vm
        let contact = vm.contact
        List {
            Section {
                VStack(spacing: 10) {
                    Avatar(name: contact.name, photo: contact.photo, size: 96)
                    Text(contact.name).font(.title2.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
            // The quick actions under the name, as in Contacts: Message, Call, Mail.
            Section {
                HStack(spacing: 10) {
                    if let p = contact.phones.first {
                        ContactActionTile(icon: "message.fill", title: "Message") { vm.openThread(p.n) }
                        ContactActionTile(icon: "phone.fill", title: "Call") { vm.call(p.n) }
                    }
                    if let e = contact.emails.first {
                        ContactActionTile(icon: "envelope.fill", title: "Mail") {
                            vm.mail(e)
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }
            Section {
                ForEach(contact.phones, id: \.self) { p in
                    HStack {
                        VStack(alignment: .leading) {
                            Group {
                                if let label = p.label, !label.trimmingCharacters(in: .whitespaces).isEmpty { Text(verbatim: label) }
                                else { Text(LocalizedStringKey(p.type.capitalized)) }
                            }
                            .font(.caption).foregroundStyle(.secondary)
                            Text(vm.formatted(p.n)).environment(\.layoutDirection, .leftToRight)
                        }
                        Spacer()
                        Button { vm.openThread(p.n) } label: { Image(systemName: "message.fill").accessibilityLabel(Text("Message")) }.buttonStyle(.borderless)
                        Button { vm.call(p.n) } label: { Image(systemName: "phone.fill").accessibilityLabel(Text("Call")) }
                            .buttonStyle(.borderless).padding(.leading, 12)
                    }
                }
                ForEach(contact.emails, id: \.self) { e in
                    VStack(alignment: .leading) {
                        Text("Email").font(.caption).foregroundStyle(.secondary)
                        Text(e)
                    }
                }
            }
            if !contact.phones.isEmpty {
                Section {
                    // Like Contacts: one row for the whole contact (all of its numbers).
                    let blocked = vm.isBlocked
                    Button(role: blocked ? nil : .destructive) { vm.blockTapped() } label: {
                        Text(blocked ? "Unblock this Caller" : "Block this Caller").foregroundStyle(blocked ? Color.accentColor : .red)
                    }
                    .disabled(!vm.isConnected)
                }
            }
        }
        .confirmationDialog(contact.name, isPresented: $vm.confirmBlock, titleVisibility: .visible) {
            Button("Block Contact", role: .destructive) { vm.block() }
        } message: {
            Text("You will not receive phone calls or messages from people on the block list.")
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(customBack)
        .toolbar {
            if customBack {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.backward").fontWeight(.semibold) }
                        .accessibilityLabel(Text("Back"))
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { vm.toggleFavourite() } label: {
                    Image(systemName: contact.starred ? "star.fill" : "star").foregroundStyle(contact.starred ? .yellow : .accentColor)
                }
                .accessibilityLabel(Text(contact.starred ? "Remove from Favourites" : "Add to Favourites"))
                .disabled(!vm.isConnected)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") { vm.editing = true }.disabled(!vm.isConnected)
            }
        }
        .sheet(isPresented: $vm.editing) {
            EditContactView(contact: contact).environment(\.appModel, AppModel.shared).environment(\.router, Router.shared)
        }
    }
}

/// One of the round-cornered quick actions under a contact's name, in glass.
struct ContactActionTile: View {
    let icon: String
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.title3)
                Text(title).font(.caption.weight(.semibold))
            }
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity, minHeight: 64)
            .glassSurface(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
