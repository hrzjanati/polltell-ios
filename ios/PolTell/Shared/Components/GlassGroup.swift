import Perception
import SwiftUI
import PolTellCore

/// Groups glass controls so iOS 26 can blend and morph them together; a plain container before.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 26
    @ViewBuilder var content: Content

    var body: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
        #else
        content
        #endif
    }
}
