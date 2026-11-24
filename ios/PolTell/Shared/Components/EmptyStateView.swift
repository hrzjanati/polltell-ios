import Perception
import SwiftUI

/// `ContentUnavailableView` (iOS 17) with a plain stand-in for iOS 16.
struct EmptyStateView: View {
    private let title: Text
    private let image: String
    private let detail: Text?
    private let searchText: String?

    init(_ title: LocalizedStringKey, systemImage: String, description: Text? = nil) {
        self.title = Text(title); image = systemImage; detail = description; searchText = nil
    }

    init(_ title: String, systemImage: String, description: Text? = nil) {
        self.title = Text(title); image = systemImage; detail = description; searchText = nil
    }

    init(searchText searchText_: String) {
        title = Text("No Results for “\(searchText_)”"); image = "magnifyingglass"
        detail = Text("Check the spelling or try a new search."); searchText = searchText_
    }

    var body: some View {
        if #available(iOS 17, *) {
            if let searchText { ContentUnavailableView.search(text: searchText) }
            else { ContentUnavailableView { Label { title } icon: { Image(systemName: image) } } description: { detail } }
        } else {
            VStack(spacing: 8) {
                Image(systemName: image).font(.system(size: 44)).foregroundStyle(.secondary)
                title.font(.title2.weight(.bold)).multilineTextAlignment(.center)
                if let detail { detail.font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center) }
            }
            .padding(24)
        }
    }
}
