import Perception
import SwiftUI
import PolTellCore

/// The tab bar as one floating Liquid Glass capsule (a thin material before iOS 26): the chosen tab sits in a tinted
/// pill, Recents and Messages carry their badges. The system tab bar is hidden; tabs switch through `Router.tab`.
struct GlassTabBar: View {
    @Binding var selection: Router.Tab
    let missed: Int
    let unread: Int

    private struct Item: Identifiable {
        let tab: Router.Tab
        let title: LocalizedStringKey
        let icon: String
        let badge: Int
        var id: Router.Tab { tab }
    }

    private var items: [Item] {
        [Item(tab: .recents, title: "Recents", icon: "clock", badge: missed),
         Item(tab: .contacts, title: "Contacts", icon: "person.crop.circle", badge: 0),
         Item(tab: .keypad, title: "Keypad", icon: "circle.grid.3x3.fill", badge: 0),
         Item(tab: .messages, title: "Messages", icon: "message", badge: unread),
         Item(tab: .link, title: "Link", icon: "antenna.radiowaves.left.and.right", badge: 0)]
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items) { item in
                let on = selection == item.tab
                Button { selection = item.tab } label: {
                    VStack(spacing: 2) {
                        Image(systemName: item.icon).font(.system(size: 20, weight: .semibold))
                            .overlay(alignment: .topTrailing) {
                                if item.badge > 0 {
                                    Text(item.badge > 99 ? "99+" : "\(item.badge)").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                                        .padding(.horizontal, 5).frame(minWidth: 18, minHeight: 18)
                                        .background(Color.red, in: Capsule()).offset(x: 12, y: -8)
                                }
                            }
                        Text(item.title).font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(on ? Color.accentColor : Color.primary.opacity(0.75))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background { if on { Capsule().fill(Color.accentColor.opacity(0.16)) } }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(item.title))
                .accessibilityValue(Text(item.badge > 0 ? "\(item.badge)" : ""))
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(5)
        .glassSurface(Capsule())
        .padding(.horizontal, 14)
        .padding(.bottom, 2)
    }
}
