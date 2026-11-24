import AVFoundation
import Perception
import SwiftUI
import PolTellCore

/// The Android phone's VPN (any VPN app) and "Share VPN": its proxy lets this device use that VPN.
struct VPNSection: View {
    @State private var vm = InternetViewModel()

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        FoldSection(title: "VPN", footer: "Turn the VPN on in its own app on the Android phone. The phone's hotspot and Bluetooth tethering do not go through it (Android sends tethered traffic straight out), so Share VPN runs a proxy on the phone whose traffic does. This iPhone can use it over the hotspot (one-time proxy setting); over Bluetooth tethering only with a proxy app.") {
            LabeledContent {
                Text(vm.net?.vpn == true ? String(localized: "On") : vm.net?.vpn == false ? String(localized: "Off") : "–")
                    .foregroundStyle(vm.net?.vpn == true ? Color.green : Color.secondary)
            } label: {
                Label("VPN on the Android phone", systemImage: "lock.shield")
            }
            NetToggle(title: "Share VPN", icon: "network.badge.shield.half.filled", what: "share", value: vm.net?.share)
            if vm.net?.share == true {
                IPhoneProxySetup(proxy: vm.net?.proxy)
            }
        }
    }
}

/// One-time steps: iOS lets no app set the system proxy, but the hotspot network can use the phone's PAC file.
struct IPhoneProxySetup: View {
    @State private var vm = InternetViewModel()
    let proxy: ShareProxyInfo?

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        DisclosureGroup {
            if let a = proxy?.addrs.first(where: { $0.kind == "hotspot" }) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Join the Android phone's hotspot in Settings › Wi-Fi.")
                    Text("2. Tap ⓘ next to it › Configure Proxy › Automatic.")
                    Text("3. Paste this URL and tap Save:")
                    HStack {
                        Text(a.pac).font(.callout.monospaced()).textSelection(.enabled)
                            .environment(\.layoutDirection, .leftToRight)
                        Spacer()
                        Button { vm.copy(a.pac) } label: {
                            Image(systemName: "doc.on.doc").accessibilityLabel(Text("Copy"))
                        }.buttonStyle(.borderless)
                    }
                    Text("Once is enough: with Share VPN on, apps on this iPhone use the phone's VPN over the hotspot; with it off they go direct. If the hotspot address ever changes, update the URL.")
                        .foregroundStyle(.secondary)
                    BluetoothProxyNote(proxy: proxy)
                }
                .font(.footnote)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Turn on the Wi-Fi hotspot to see the address to use.")
                    BluetoothProxyNote(proxy: proxy)
                }
                .font(.footnote).foregroundStyle(.secondary)
            }
        } label: {
            Label("Use it on this iPhone", systemImage: "iphone")
        }
    }
}

/// Bluetooth tethering and the VPN: iOS has no proxy setting for it, so only a proxy app can use the Android phone's proxy there.
struct BluetoothProxyNote: View {
    let proxy: ShareProxyInfo?

    var body: some View {
        let bt = proxy?.addrs.first(where: { $0.kind == "bt" })
        let port = proxy?.port ?? 8118
        VStack(alignment: .leading, spacing: 4) {
            Text("Bluetooth tethering does not use the VPN on its own: iPhone has no proxy setting for it. Use the hotspot for the VPN.")
                .fontWeight(.semibold)
            Text("Only a proxy app on this iPhone (for example V2Box) can use it over Bluetooth: add a SOCKS5 server \(bt?.ip ?? "192.168.44.1"):\(String(port)) there and turn it on.")
                .foregroundStyle(.secondary)
        }
        .font(.footnote)
    }
}

/// Calling numbers from other apps (tel: links, Shortcuts, the Phone app's Recents); docs/USAGE.md.
struct PhoneLinksSection: View {
    @State private var vm = LinkViewModel()
    @AppStorage(CallController.phoneRecentsKey) private var inPhoneRecents = false

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        FoldSection(title: "Numbers in other apps", footer: "Calls made here also appear in the Phone app's Recents; tapping one calls back through the Android phone. To call numbers you tap in other apps, choose this app in Settings › Apps › Default Apps › Calling (needs a paid Apple developer account), or use the \"Call with\" shortcut in the Shortcuts app.") {
            Toggle(isOn: $inPhoneRecents) { Label("Show calls in the Phone app", systemImage: "clock.arrow.circlepath") }
                .onChangeCompat(of: inPhoneRecents) { _ in vm.applyRecentsSetting() }
        }
    }
}

/// How long this build's free signature still lasts (renewed by running tools/reinstall-ios.sh on the Mac).
struct SigningSection: View {
    var body: some View {
        if let expiry = Signing.expiry, let days = Signing.daysLeft {
            FoldSection(title: "Renewal", footer: "A free Apple account's signature lasts 7 days. Renew it by running tools/reinstall-ios.sh on your Mac with this device unlocked and connected.") {
                LabeledContent("App expires") {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(days == 0 ? String(localized: "Today") : String(localized: "in \(days) days"))
                            .foregroundStyle(days <= 2 ? Color.red : (days <= 4 ? Color.orange : Color.primary))
                        Text(expiry.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

/// Link tab › Phone tools: carrier codes (balance etc.) on a SIM, "find my phone" and the ringer mode. Each part shows
/// only when the Android phone's status says it can (older Android builds of PolTell do not say: the section is hidden).
struct PhoneToolsSection: View {
    @State private var vm = PhoneToolsViewModel()
    let status: StatusBody
    let tools: StatusBody.PhoneTools

    private var chosenSub: Int? { vm.chosenSub(status) }

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        @Perception.Bindable var vm = vm
        FoldSection(title: "Phone tools", footer: "Carrier codes are sent from the Android phone's SIM and may cost money. Find phone rings the Android phone loudly for up to 30 seconds, until it is unlocked or you switch it off.") {
            if tools.ussd == true {
                HStack {
                    TextField("*123#", text: $vm.code)
                        .keyboardType(.numbersAndPunctuation).autocorrectionDisabled().textInputAutocapitalization(.never)
                        .font(.body.monospaced())
                    Button("Send") { vm.send(status) }
                        .disabled(!vm.canSend())
                }
                if status.sims.count > 1 {
                    Picker("SIM", selection: Binding(get: { chosenSub ?? -1 }, set: { vm.sub = $0 })) {
                        ForEach(status.sims) { sim in Text("SIM \(sim.slot + 1) · \(sim.name)").tag(sim.sub) }
                    }
                }
                if vm.ussdPending {
                    HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Waiting for the carrier…").foregroundStyle(.secondary) }
                } else if let r = vm.ussdResult {
                    Text(r.ok ? (r.text ?? "") : (r.err ?? String(localized: "No answer")))
                        .font(.callout).foregroundStyle(r.ok ? Color.primary : Color.red).textSelection(.enabled)
                }
            }
            if tools.find == true {
                Toggle(isOn: Binding(get: { vm.finding }, set: { vm.setFinding($0) })) {
                    Label("Find phone", systemImage: "bell.and.waves.left.and.right")
                }
                .tint(.green).disabled(!vm.isConnected)
            }
            if tools.ringer == true, let mode = status.ringer {
                Picker(selection: Binding(get: { mode }, set: { vm.setRinger($0) })) {
                    Text("Ring").tag("normal"); Text("Vibrate").tag("vibrate"); Text("Silent").tag("silent")
                } label: { Label("Ringer", systemImage: "bell") }
                .disabled(!vm.isConnected)
                if status.dnd == false {
                    Text("Silent needs Do Not Disturb access for PolTell on the Android phone.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            if let e = vm.error { Text(e).font(.footnote).foregroundStyle(.red) }
        }
    }
}
