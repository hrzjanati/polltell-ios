import AVFoundation
import Perception
import SwiftUI
import PolTellCore

/// The top of the Link tab: the Android phone with its battery, one card per SIM (tap for details) and two
/// status cards. The soft purple wash behind them gives the glass something to refract.
struct LinkDashboard: View {
    @State private var vm = LinkViewModel()
    let stateLine: String
    var onScan: () -> Void = {}

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        VStack(spacing: 12) {
            phoneCard
            if let s = vm.status {
                simCards(s)
                HStack(spacing: 12) {
                    StatusCard(icon: "phone.fill", title: "Default phone app",
                               value: s.dialer ? String(localized: "PolTell") : String(localized: "Not set"), ok: s.dialer)
                        .cardLink {
                            LinkInfoView(title: "Default phone app", icon: "phone.fill", ok: s.dialer,
                                         text: "PolTell must be the default phone app on the Android phone so calls and messages can be bridged to this iPhone.")
                        }
                    StatusCard(icon: "wifi", title: "Wireless debugging",
                               value: s.adbWifi ? String(localized: "On") : String(localized: "Off"), ok: s.adbWifi)
                        .cardLink {
                            LinkInfoView(title: "Wireless debugging", icon: "wifi", ok: s.adbWifi,
                                         text: "Used by the audio helper on the Android phone to carry call audio. It stays on the Android phone's own Wi-Fi.")
                        }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(alignment: .top) {
            LinearGradient(colors: [Color.accentColor.opacity(0.28), Color.accentColor.opacity(0.06), .clear],
                           startPoint: .topLeading, endPoint: .bottom)
                .overlay(alignment: .topTrailing) { Circle().fill(Color.accentColor.opacity(0.25)).frame(width: 160, height: 160).blur(radius: 50).offset(x: 40, y: -40) }
                .clipped()
        }
    }

    private var phoneCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                BridgeBadge(connected: vm.isConnected)
                VStack(alignment: .leading, spacing: 3) {
                    Text(vm.isPaired ? vm.peerName : String(localized: "Not paired")).font(.headline)
                    Text(stateLine).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button(action: onScan) {
                    Image(systemName: "qrcode.viewfinder").font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .glassSurface(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(vm.isPaired ? "Pair again" : "Pair with Android phone"))
            }
            if let s = vm.status {
                HStack(spacing: 10) {
                    Image(systemName: s.charging ? "battery.100.bolt" : "battery.75")
                        .foregroundStyle(batteryColor(s))
                    Gauge(value: Double(s.battery), in: 0...100) { Text("Battery") }
                        .gaugeStyle(.accessoryLinearCapacity)
                        .tint(batteryColor(s))
                    Text("\(s.battery)%").font(.subheadline.weight(.semibold).monospacedDigit())
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("Battery"))
                .accessibilityValue(Text("\(s.battery)%"))
            }
        }
        .linkCard()
    }

    private func batteryColor(_ s: StatusBody) -> Color {
        s.battery <= 15 && !s.charging ? .red : (s.charging ? .green : .accentColor)
    }

    @ViewBuilder private func simCards(_ s: StatusBody) -> some View {
        if s.sims.count <= 2 {
            HStack(spacing: 12) { ForEach(s.sims) { simLink($0) } }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) { ForEach(s.sims) { simLink($0).frame(width: 170) } }
            }
        }
    }

    private func simLink(_ sim: SimInfo) -> some View {
        SimCard(sim: sim, isDataSim: vm.dataSub == sim.sub)
            .cardLink { SimDetailView(sim: sim) }
    }
}

/// One SIM as a glass card: slot, name, carrier, signal bars and network type.
struct SimCard: View {
    let sim: SimInfo
    let isDataSim: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "simcard.fill").foregroundStyle(Color.secondaryAccent)
                Text("SIM \(sim.slot + 1)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer(minLength: 4)
                if isDataSim { Text("Data").font(.caption2.weight(.bold)).padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.secondaryAccent.opacity(0.18), in: Capsule()).foregroundStyle(Color.secondaryAccent) }
                Image(systemName: "chevron.forward").font(.caption2.weight(.bold)).foregroundStyle(.tertiary)
            }
            Text(sim.name).font(.headline).lineLimit(1)
            Text(sim.carrier).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 0)
            SimStatus(sim: sim, showName: false)
        }
        .frame(minHeight: 112, alignment: .topLeading)
        .linkCard()
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Shows details"))
    }
}

/// A small status card: icon, what it is and its state (green when fine, secondary when not).
struct StatusCard: View {
    let icon: String
    let title: LocalizedStringKey
    let value: String
    let ok: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundStyle(ok ? Color.green : Color.secondary)
                Spacer(minLength: 4)
                Image(systemName: "chevron.forward").font(.caption2.weight(.bold)).foregroundStyle(.tertiary)
            }
            Text(title).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
            Text(value).font(.headline).foregroundStyle(ok ? Color.primary : Color.secondary)
        }
        .frame(minHeight: 96, alignment: .topLeading)
        .linkCard()
        .accessibilityElement(children: .combine)
    }
}
