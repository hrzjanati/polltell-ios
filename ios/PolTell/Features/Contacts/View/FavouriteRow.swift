import Perception
import SwiftUI
import PolTellCore

/// A favourite: tap to call (its first number, on the SIM last used with it), ⓘ for the contact.
struct FavouriteRow: View {
    @State private var vm = FavouritesViewModel()
    let contact: Contact

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        HStack(spacing: 12) {
            Avatar(name: contact.name, photo: contact.photo, size: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(contact.name)
                if let p = contact.phones.first {
                    Text(LocalizedStringKey(p.type.capitalized)).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            NavigationLink { ContactDetailView(contact: contact) } label: { Image(systemName: "info.circle").accessibilityLabel(Text("Contact Info")) }
                .buttonStyle(.borderless).fixedSize()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            vm.call(contact)
        }
        .swipeActions {
            Button { vm.remove(contact) } label: { Label("Remove", systemImage: "star.slash") }.tint(.orange)
        }
    }
}
