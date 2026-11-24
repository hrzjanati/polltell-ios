import Perception
import SwiftUI
import PolTellCore

// MARK: - Liquid Glass

extension View {
    /// Apple's Liquid Glass behind a control: the real `glassEffect` on iOS 26 (built with Xcode 26), and on
    /// earlier systems a thin material with a hairline edge in the same shape. With Reduce Transparency on, the
    /// system makes both opaque by itself. Use it on the control layer only (buttons, bars), never on content.
    @ViewBuilder func glassSurface<S: Shape>(_ shape: S, tint: Color? = nil, interactive: Bool = true) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(Self.glass(tint: tint, interactive: interactive), in: shape)
        } else {
            self.materialSurface(shape, tint: tint)
        }
        #else
        self.materialSurface(shape, tint: tint)
        #endif
    }

    #if compiler(>=6.2)
    @available(iOS 26.0, *)
    private static func glass(tint: Color?, interactive: Bool) -> Glass {
        var g = Glass.regular
        if let tint { g = g.tint(tint) }
        if interactive { g = g.interactive() }
        return g
    }
    #endif

    private func materialSurface<S: Shape>(_ shape: S, tint: Color?) -> some View {
        background {
            ZStack {
                shape.fill(.ultraThinMaterial)
                if let tint { shape.fill(tint.opacity(0.85)) }
                shape.stroke(.white.opacity(0.18), lineWidth: 0.5)
            }
        }
    }
}
