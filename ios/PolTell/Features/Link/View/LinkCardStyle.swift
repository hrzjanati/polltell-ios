import AVFoundation
import Perception
import SwiftUI
import PolTellCore

// MARK: - Collapsible sections

/// A list section that starts folded: the title row opens it, and its footnote is the last line inside.
struct FoldSection<Content: View>: View {
    let title: LocalizedStringKey
    var footer: LocalizedStringKey? = nil
    @ViewBuilder let content: () -> Content
    @State private var open = false

    var body: some View {
        Section {
            DisclosureGroup(isExpanded: $open) {
                content()
                if let footer { Text(footer).font(.footnote).foregroundStyle(.secondary) }
            } label: {
                Text(title).font(.headline)
            }
        }
    }
}

// MARK: - Link dashboard (Liquid Glass cards)

extension View {
    /// The card shape of the Link dashboard: Liquid Glass on iOS 26, a thin material before.
    func linkCard() -> some View {
        self.padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(RoundedRectangle(cornerRadius: 24, style: .continuous), interactive: false)
    }
}

extension View {
    /// Makes the view open `destination` when tapped without the list's own disclosure chevron around it
    /// (the cards draw their own).
    func cardLink<D: View>(@ViewBuilder _ destination: @escaping () -> D) -> some View {
        overlay { NavigationLink { destination() } label: { EmptyView() }.opacity(0) }
    }
}
