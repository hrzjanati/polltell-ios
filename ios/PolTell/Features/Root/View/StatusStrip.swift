import Perception
import SwiftUI
import PolTellCore

/// One floating capsule in the system's glass (a thin material before iOS 26), under the status bar: the Bluetooth
/// state on the leading side, the Android phone's SIMs and battery on the trailing one. A broken link tints it red.
struct StatusStrip: View {
    @State private var vm = StatusStripViewModel()

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        HStack(spacing: 8) {
            BluetoothBadge(state: vm.badge)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(vm.stateText))
            Spacer(minLength: 8)
            if let s = vm.phoneStatus {
                ViewThatFits(in: .horizontal) {
                    details(s, names: true)
                    details(s, names: false)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minHeight: 36)
        .glassSurface(Capsule(), tint: vm.problem ? Color.red.opacity(0.30) : nil, interactive: false)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private func details(_ s: StatusBody, names: Bool) -> some View {
        HStack(spacing: 12) {
            ForEach(s.sims) { sim in SimStatus(sim: sim, showName: names && s.sims.count > 1) }
            BatteryBadge(level: s.battery, charging: s.charging, tint: vm.batteryColor(s))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("Battery"))
            .accessibilityValue(Text("\(s.battery)%"))
        }
        .fixedSize()
    }
}

/// One SIM in the status strip: bars, network type (5G / LTE+ / H+ …), roaming, or "No service".
struct SimStatus: View {
    let sim: SimInfo
    var showName = true

    /// Network type as an iPhone labels it: Android's "LTE+", "4G+" or "H+" are not shown by iOS, which says
    /// "LTE" (4G), "5G", "3G" or "E". Anything unknown is shown as the phone sent it.
    static func iPhoneLabel(_ net: String) -> String {
        switch net.uppercased() {
        case "LTE", "LTE+", "4G", "4G+", "LTE-A": "LTE"
        case "5G", "5G+", "NR", "5G NR": "5G"
        case "H", "H+", "3G", "3G+", "HSPA", "HSPA+", "UMTS": "3G"
        case "E", "G", "2G", "EDGE", "GPRS": "E"
        default: net
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            if showName { Text(sim.name).font(.caption2).lineLimit(1) }
            if sim.hasService {
                SignalBars(level: sim.signal)
                if let n = sim.net { Text(Self.iPhoneLabel(n)).font(.caption2.weight(.semibold)) }
                if sim.roaming == true { Text("R").font(.caption2.weight(.bold)).foregroundStyle(.orange) }
            } else {
                Text(sim.service == "emergency" ? "SOS" : String(localized: "No service")).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct SignalBars: View {
    let level: Int
    var body: some View {
        HStack(alignment: .bottom, spacing: 1) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < level ? Color.primary : Color.secondary.opacity(0.3))
                    .frame(width: 3, height: CGFloat(4 + i * 2))
            }
        }
        .accessibilityLabel(Text("Signal \(level) of 4"))
    }
}

/// Bluetooth as the Control Center shows it: a round glyph, blue and filled when linked, grey when off, slashed
/// when Bluetooth is unavailable, red when the paired phone is out of reach. No words: the state is the look.
struct BluetoothBadge: View {
    enum State { case connected, connecting, lost, off }
    let state: State

    var body: some View {
        ZStack {
            Circle().fill(fill)
            BluetoothGlyph()
                .stroke(glyph, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                .frame(width: 11, height: 16)
            if state == .off {
                Capsule().fill(glyph).frame(width: 1.8, height: 24).rotationEffect(.degrees(45))
                    .mask(Circle())
            }
        }
        .frame(width: 26, height: 26)
        .opacity(state == .connecting ? 0.75 : 1)
    }

    private var fill: Color {
        switch state {
        case .connected, .connecting: Color(red: 10 / 255, green: 132 / 255, blue: 255 / 255)
        case .lost: .red
        case .off: Color(.tertiarySystemFill)
        }
    }

    private var glyph: Color { state == .off ? Color.secondary : .white }
}

/// The Bluetooth rune, drawn in the rectangle it is given.
struct BluetoothGlyph: Shape {
    func path(in r: CGRect) -> Path {
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + r.width * x, y: r.minY + r.height * y) }
        var p = Path()
        p.move(to: pt(0, 0.27)); p.addLine(to: pt(1, 0.73)); p.addLine(to: pt(0.5, 1))
        p.addLine(to: pt(0.5, 0)); p.addLine(to: pt(1, 0.27)); p.addLine(to: pt(0, 0.73))
        return p
    }
}

#if DEBUG
#Preview("Bluetooth badge") {
    HStack(spacing: 16) {
        BluetoothBadge(state: .connected); BluetoothBadge(state: .connecting)
        BluetoothBadge(state: .lost); BluetoothBadge(state: .off)
    }.padding()
}
#endif


/// iPhone-style battery: a dark fill up to the charge level, a light track for the rest, the percentage inside.
struct BatteryBadge: View {
    let level: Int
    let charging: Bool
    let tint: Color

    private let width: CGFloat = 34
    private let height: CGFloat = 15

    var body: some View {
        let fraction = CGFloat(min(max(level, 0), 100)) / 100
        HStack(spacing: 1.5) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4.5, style: .continuous).fill(Color.primary.opacity(0.22))
                RoundedRectangle(cornerRadius: 4.5, style: .continuous).fill(tint)
                    .frame(width: max(8, width * fraction))
                HStack(spacing: 0) {
                    if charging { Image(systemName: "bolt.fill").font(.system(size: 9, weight: .bold)) }
                    Text("\(level)").font(.system(size: 12, weight: .bold).monospacedDigit())
                }
                .foregroundStyle(Color(uiColor: .systemBackground))
                .frame(width: width)
            }
            .frame(width: width, height: height)
            Capsule().fill(Color.primary.opacity(0.4)).frame(width: 1.5, height: 5)
        }
    }
}

#if DEBUG
#Preview("Battery badge") {
    VStack(spacing: 12) {
        BatteryBadge(level: 82, charging: false, tint: .primary)
        BatteryBadge(level: 40, charging: true, tint: .green)
        BatteryBadge(level: 12, charging: false, tint: .red)
    }
    .padding()
}
#endif
