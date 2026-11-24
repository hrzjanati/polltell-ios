import AVFoundation
import Perception
import SwiftUI
import PolTellCore

/// PolTell's signature: the iPhone and the Android phone joined by a bridge, solid in the brand colour while the
/// link is up and dashed while it is down.
struct BridgeBadge: View {
    let connected: Bool
    @ScaledMetric(relativeTo: .title2) private var phone: CGFloat = 22

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            Image(systemName: "iphone").font(.system(size: phone))
            BridgeArc()
                .stroke(connected ? Color("AccentColor") : Color.secondary,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: connected ? [] : [3, 4]))
                .frame(width: phone * 1.4, height: phone * 0.8)
                .padding(.bottom, phone * 0.35)
            Image(systemName: "candybarphone").font(.system(size: phone))
        }
        .foregroundStyle(connected ? Color("AccentColor") : Color.secondary)
        .accessibilityElement()
        .accessibilityLabel(Text(connected ? "Connected to the Android phone" : "Not connected to the Android phone"))
    }
}

/// An arch with a deck and three hangers, like the app icon.
struct BridgeArc: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY), control: CGPoint(x: r.midX, y: r.minY - r.height * 0.9))
        p.move(to: CGPoint(x: r.minX, y: r.maxY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        let top = r.minY - r.height * 0.9
        for t: CGFloat in [0.3, 0.5, 0.7] {
            let x = r.minX + r.width * t
            let y = (1 - t) * (1 - t) * r.maxY + 2 * t * (1 - t) * top + t * t * r.maxY
            p.move(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: x, y: r.maxY))
        }
        return p
    }
}
