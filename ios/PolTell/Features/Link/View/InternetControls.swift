import AVFoundation
import Perception
import SwiftUI
import PolTellCore

/// One switch in the Internet section: shows the phone's state, greys out while a change is in flight.
struct NetToggle: View {
    @State private var vm = InternetViewModel()
    let title: LocalizedStringKey
    let icon: String
    let what: String
    let value: Bool?

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        Toggle(isOn: Binding(get: { value ?? false }, set: { vm.set(what, on: $0) })) {
            Label {
                HStack(spacing: 8) {
                    Text(title)
                    if vm.pending == what { ProgressView().controlSize(.small) }
                }
            } icon: {
                Image(systemName: icon)
            }
        }
        .tint(.green)
        .disabled(value == nil || vm.isLocked)
    }
}

// MARK: - Internet (Control Center style)

/// The Android phone's internet switches as round buttons in a grid, like Control Center's connectivity
/// module: tap to switch, filled colour when on, a spinner while the phone applies the change.
struct InternetControls: View {
    @State private var vm = InternetViewModel()
    let status: StatusBody

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Internet").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 12)], spacing: 16) {
                tile("Mobile data", "antenna.radiowaves.left.and.right", "data", vm.net?.data, Color(red: 0.13, green: 0.62, blue: 0.33))
                // Only what this Android phone can do (older Android builds of PolTell do not say: shown).
                if vm.net?.can?.hotspot != false {
                    tile("Wi-Fi hotspot", "personalhotspot", "hotspot", vm.net?.hotspot, Color(red: 0.13, green: 0.62, blue: 0.33))
                }
                if vm.net?.can?.bt != false {
                    tile("Bluetooth tethering", "dot.radiowaves.left.and.right", "bt", vm.net?.bt, Color.accentColor)
                }
                tile("Airplane mode", "airplane", "airplane", vm.net?.airplane, Color(red: 0.80, green: 0.38, blue: 0.0))
            }
            if status.sims.count > 1, let current = vm.net?.dataSub {
                Menu {
                    Picker("Data SIM", selection: Binding(get: { current }, set: { vm.setDataSim($0) })) {
                        ForEach(status.sims) { sim in Text("SIM \(sim.slot + 1) · \(sim.name)").tag(sim.sub) }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "simcard.2")
                        Text("Data SIM")
                        Spacer(minLength: 4)
                        if vm.pending == "dataSub" { ProgressView().controlSize(.small) }
                        Text(status.sims.first { $0.sub == current }.map { "SIM \($0.slot + 1) · \($0.name)" } ?? "")
                            .foregroundStyle(.secondary).lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundStyle(.tertiary)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .frame(minHeight: 44)
                    .background(Color(.tertiarySystemFill), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(vm.isLocked)
            }
            if let e = vm.net?.err {
                Text(e).font(.footnote).foregroundStyle(.red)
            }
            Text("Turn on the hotspot and join it in Settings › Wi-Fi to use the Android phone's internet here. Bluetooth tethering is slower: after switching it on, tap the Android phone in Settings › Bluetooth. Airplane mode keeps Bluetooth on so this link stays up; if the link is not back within 90 seconds it switches itself off. The hotspot and Bluetooth tethering come back on after it.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .linkCard()
    }

    private func tile(_ title: LocalizedStringKey, _ icon: String, _ what: String, _ value: Bool?, _ color: Color) -> some View {
        let on = value ?? false
        return Button {
            vm.set(what, on: !on)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(on ? color : Color(.tertiarySystemFill))
                    if vm.pending == what {
                        ProgressView().tint(on ? .white : nil)
                    } else {
                        Image(systemName: icon).font(.title3.weight(.semibold)).foregroundStyle(on ? Color.white : Color.primary)
                    }
                }
                .frame(width: 58, height: 58)
                .shadow(color: on ? color.opacity(0.35) : .clear, radius: 8, y: 3)
                Text(title).font(.caption2).multilineTextAlignment(.center).lineLimit(2).foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(value == nil || vm.isLocked)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(on ? "On" : "Off"))
    }
}
