import Perception
import SwiftUI
import PolTellCore

/// Favourites above Recents as round avatars in a row you scroll sideways, like stories: a gradient ring, the first
/// name underneath, tap to call (its first number), hold for the contact or to remove it, and "+" to add more.
struct FavouritesStrip: View {
    @State private var vm = FavouritesViewModel()
    let onAdd: () -> Void

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                Button(action: onAdd) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle().strokeBorder(Color.accentColor.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                            Image(systemName: "plus").font(.title3.weight(.semibold)).foregroundStyle(Color.accentColor)
                        }
                        .frame(width: 68, height: 68)
                        Text("Add").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!vm.isConnected)
                .accessibilityLabel(Text("Add to Favourites"))
                ForEach(vm.favourites) { c in
                    Button { vm.call(c) } label: {
                        VStack(spacing: 6) {
                            Avatar(name: c.name, photo: c.photo, size: 58)
                                .padding(4)
                                .overlay(Circle().strokeBorder(
                                    LinearGradient(colors: [Color.accentColor, Color.secondaryAccent], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 3))
                                .frame(width: 68, height: 68)
                            Text(vm.firstName(c)).font(.caption).lineLimit(1).frame(width: 72)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Call \(c.name)"))
                    .contextMenu {
                        if vm.canCall(c) {
                            Button { vm.call(c) } label: { Label("Call", systemImage: "phone") }
                        }
                        Button(role: .destructive) { vm.remove(c) } label: { Label("Remove from Favourites", systemImage: "star.slash") }
                            .disabled(!vm.isConnected)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
    }
}

/// Pick contacts to add to Favourites; the list keeps going so several can be added in one visit.
struct FavouritePicker: View {
    @State private var vm = FavouritesViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        @Perception.Bindable var vm = vm
        NavigationStack {
            List(vm.candidates) { c in
                Button { vm.add(c) } label: {
                    HStack(spacing: 12) {
                        Avatar(name: c.name, photo: c.photo, size: 36)
                        Text(c.name).foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "plus.circle.fill").foregroundStyle(Color.accentColor)
                    }
                }
                .disabled(!vm.isConnected)
            }
            .listStyle(.plain)
            .searchable(text: $vm.search, prompt: Text("Search contacts"))
            .navigationTitle("Add to Favourites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
