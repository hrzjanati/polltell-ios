import AVFoundation
import Perception
import SwiftUI
import TetherCore

struct LinkView: View {
    @Environment(\.appModel) private var model
    @State private var scanning = false
    @State private var confirmUnpair = false

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        NavigationStack {
            ScrollViewReader { scroller in
            List {
                Section {
                    HStack(spacing: 14) {
                        BridgeBadge(connected: model.linkState.isConnected)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(model.isPaired ? model.peerName : String(localized: "Not paired")).font(.headline)
                            Text(stateLine).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    Label {
                        Text("PolTell keeps the link in the background and when the screen is locked. Swiping PolTell away in the app switcher stops it until you open it again: iOS does not relaunch a force-quit app for Bluetooth.")
                            .font(.footnote)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                    }
                }

                SigningSection()

                if let s = model.status {
                    Section("Phone") {
                        LabeledContent("Battery", value: "\(s.battery)%" + (s.charging ? " ⚡︎" : ""))
                        ForEach(s.sims) { sim in
                            LabeledContent {
                                HStack(spacing: 6) { SimStatus(sim: sim, showName: false); Text(sim.carrier) }
                            } label: {
                                Text("SIM \(sim.slot + 1) · \(sim.name)")
                            }
                        }
                        LabeledContent("Default phone app", value: s.dialer ? String(localized: "PolTell") : String(localized: "Not set"))
                        LabeledContent("Wireless debugging", value: s.adbWifi ? String(localized: "On") : String(localized: "Off"))
                    }
                    Section {
                        NetToggle(title: "Mobile data", icon: "antenna.radiowaves.left.and.right", what: "data", value: model.net?.data)
                        if s.sims.count > 1, let current = model.net?.dataSub {
                            Picker(selection: Binding(get: { current }, set: { model.setDataSim($0) })) {
                                ForEach(s.sims) { sim in
                                    Text("SIM \(sim.slot + 1) · \(sim.name)").tag(sim.sub)
                                }
                            } label: {
                                Label {
                                    HStack(spacing: 8) {
                                        Text("Data SIM")
                                        if model.netPending == "dataSub" { ProgressView().controlSize(.small) }
                                    }
                                } icon: {
                                    Image(systemName: "simcard.2")
                                }
                            }
                            .disabled(model.netPending != nil || !model.linkState.isConnected)
                        }
                        // Only what this Android phone can do (older Android builds of Tether do not say: shown).
                        if model.net?.can?.hotspot != false {
                            NetToggle(title: "Wi-Fi hotspot", icon: "personalhotspot", what: "hotspot", value: model.net?.hotspot)
                        }
                        if model.net?.can?.bt != false {
                            NetToggle(title: "Bluetooth tethering", icon: "dot.radiowaves.left.and.right", what: "bt", value: model.net?.bt)
                        }
                        NetToggle(title: "Airplane mode", icon: "airplane", what: "airplane", value: model.net?.airplane)
                        ForEach(s.sims) { sim in
                            if let mode = model.net?.mode(slot: sim.slot) {
                                Picker(selection: Binding(get: { mode }, set: { model.setNetworkMode(slot: sim.slot, $0) })) {
                                    ForEach(["5G", "4G", "3G", "2G"], id: \.self) { Text($0).tag($0) }
                                } label: {
                                    Label {
                                        HStack(spacing: 8) {
                                            Text("Network · \(sim.name)")
                                            if model.netPending == "rat\(sim.slot)" { ProgressView().controlSize(.small) }
                                        }
                                    } icon: { Image(systemName: "cellularbars") }
                                }
                                .disabled(model.netPending != nil || !model.linkState.isConnected)
                            }
                        }
                        if let e = model.net?.err {
                            Text(e).font(.footnote).foregroundStyle(.red)
                        }
                    } header: {
                        Text("Internet")
                    } footer: {
                        Text("Turn on the hotspot and join it in Settings › Wi-Fi to use the Android phone's internet here. Bluetooth tethering is slower: after switching it on, tap the Android phone in Settings › Bluetooth. Airplane mode keeps Bluetooth on so this link stays up; if the link is not back within 90 seconds it switches itself off. The hotspot and Bluetooth tethering come back on after it.")
                    }
                    VPNSection().id("vpn")
                    if let t = s.tools, t.ussd == true || t.find == true || t.ringer == true {
                        PhoneToolsSection(status: s, tools: t).id("phonetools")
                    }
                    Section("Call audio") {
                        LabeledContent("Audio helper", value: s.helper.state == "running" ? String(localized: "Running") : String(localized: "Stopped"))
                        if let m = s.helper.method { LabeledContent("Method", value: m) }
                        if let q = s.helper.silent {
                            LabeledContent("Android phone silent", value: q == "full" ? String(localized: "Yes") :
                                q == "earpiece" ? String(localized: "Earpiece only") : String(localized: "No"))
                        }
                        if let a = model.lastAudioStats {
                            LabeledContent("Last call") {
                                Text(String(format: "buffer %.0f ms · jitter %.1f ms · gaps %d", a.delayMs, a.jitterMs, a.underruns))
                                    .font(.caption.monospacedDigit())
                            }
                        }
                        Button("Run call-audio self-test") { model.runSelftest() }
                            .disabled(!model.linkState.isConnected)
                        if let st = model.selftest {
                            ForEach(st.methods, id: \.self) { m in
                                HStack(alignment: .top) {
                                    Image(systemName: m.ok ? "checkmark.circle.fill" : "xmark.circle").foregroundStyle(m.ok ? .green : .secondary)
                                    VStack(alignment: .leading) {
                                        Text(m.name).font(.subheadline)
                                        if let n = m.note { Text(n).font(.caption).foregroundStyle(.secondary) }
                                    }
                                }
                            }
                        }
                    }
                }

                PhoneLinksSection()

                Section {
                    NavigationLink {
                        BlockedListView()
                    } label: {
                        LabeledContent {
                            Text("\(model.blockLists.blocked.count)")
                        } label: {
                            Label("Blocked Contacts", systemImage: "hand.raised")
                        }
                    }
                } footer: {
                    Text("Kept on the Android phone and shared by all your devices.")
                }

                Section {
                    if let last = model.lastSync {
                        LabeledContent("Last sync", value: last.formatted(date: .omitted, time: .shortened))
                    }
                    Button("Sync everything again") { model.requestSync(full: true) }.disabled(!model.linkState.isConnected)
                    NavigationLink("Link log") { LinkLogView() }
                    Button(model.isPaired ? "Pair again" : "Pair with Android phone") { scanning = true }
                    if model.isPaired {
                        Button("Unpair", role: .destructive) { confirmUnpair = true }
                    }
                } footer: {
                    Text("On the Android phone, open PolTell and tap Pair iPhone, then scan the code (or paste it). Calls, messages, contacts and call history stay between your devices; there is no server.")
                }
            }
            #if DEBUG
            // -TetherDemoVPN: start scrolled to the VPN section (screenshots).
            .onAppear {
                if ProcessInfo.processInfo.arguments.contains("-TetherDemoPair") || ProcessInfo.processInfo.arguments.contains("-TetherDemoPairManual") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { scanning = true }
                }
                if ProcessInfo.processInfo.arguments.contains("-TetherDemoPhoneTools") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { scroller.scrollTo("phonetools", anchor: .top) }
                }
                if ProcessInfo.processInfo.arguments.contains("-TetherDemoVPN") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { scroller.scrollTo("vpn", anchor: .top) }
                }
            }
            #endif
            }
            .navigationTitle("Link")
            .onAppear { model.refreshNet() }
            .onChangeCompat(of: model.linkState.isConnected) { up in if up { model.refreshNet() } }
            // Full screen: nothing of the Link tab shows around or behind the camera.
            .fullScreenCover(isPresented: $scanning) {
                PairingView { code in
                    scanning = false
                    if let code { model.pair(code) }
                }
                .environment(\.appModel, AppModel.shared)
            }
            .confirmationDialog("Forget the Android phone and delete synced data from this iPhone?", isPresented: $confirmUnpair,
                                titleVisibility: .visible) {
                Button("Unpair", role: .destructive) { model.unpair() }
            }
        }
    }

    private var stateLine: String {
        switch model.linkState {
        case .connected(let t): String(localized: "Connected over \(t == "l2cap" ? "L2CAP" : "GATT")")
        case .connecting, .handshaking: String(localized: "Connecting…")
        case .searching: model.isPaired ? String(localized: "Out of reach, will reconnect automatically") : String(localized: "Not paired")
        case .poweredOff: String(localized: "Bluetooth is off")
        case .unauthorized: String(localized: "Allow Bluetooth for PolTell in Settings")
        case .unpaired: String(localized: "Not paired")
        }
    }
}

/// The Android phone's VPN (any VPN app) and "Share VPN": its proxy lets this device use that VPN.
struct VPNSection: View {
    @Environment(\.appModel) private var model

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        Section {
            LabeledContent {
                Text(model.net?.vpn == true ? String(localized: "On") : model.net?.vpn == false ? String(localized: "Off") : "–")
                    .foregroundStyle(model.net?.vpn == true ? Color.green : Color.secondary)
            } label: {
                Label("VPN on the Android phone", systemImage: "lock.shield")
            }
            NetToggle(title: "Share VPN", icon: "network.badge.shield.half.filled", what: "share", value: model.net?.share)
            if model.net?.share == true {
                IPhoneProxySetup(proxy: model.net?.proxy)
            }
        } header: {
            Text("VPN")
        } footer: {
            Text("Turn the VPN on in its own app on the Android phone. The phone's hotspot and Bluetooth tethering do not go through it (Android sends tethered traffic straight out), so Share VPN runs a proxy on the phone whose traffic does. This iPhone can use it over the hotspot (one-time proxy setting); over Bluetooth tethering only with a proxy app.")
        }
    }
}


/// One-time steps: iOS lets no app set the system proxy, but the hotspot network can use the phone's PAC file.
struct IPhoneProxySetup: View {
    @Environment(\.appModel) private var model
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
                        Button { UIPasteboard.general.string = a.pac; model.flash(String(localized: "Copied")) } label: {
                            Image(systemName: "doc.on.doc")
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

/// Recent link events, newest first (drops and their reasons), with a button to share them.
struct LinkLogView: View {
    @State private var text = LinkJournal.shared.text

    var body: some View {
        ScrollView {
            Text(text.isEmpty ? String(localized: "No events yet.") : text)
                .font(.caption.monospaced()).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading).padding()
                .environment(\.layoutDirection, .leftToRight)
        }
        .navigationTitle("Link log")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) { ShareLink(item: text) }
        }
        .refreshable { text = LinkJournal.shared.text }
    }
}

/// Blocked numbers (the Android phone's list), with swipe to unblock, as in Settings › Phone › Blocked Contacts.
struct BlockedListView: View {
    @Environment(\.appModel) private var model

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        List {
            Section {
                ForEach(model.blockLists.blocked, id: \.self) { n in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.name(for: n) ?? n)
                        if model.name(for: n) != nil {
                            Text(n).font(.caption).foregroundStyle(.secondary).environment(\.layoutDirection, .leftToRight)
                        }
                    }
                    .swipeActions {
                        Button("Unblock") { model.setBlocked(n, false) }.tint(.red)
                    }
                    .contextMenu {
                        Button { model.setBlocked(n, false) } label: { Label("Unblock", systemImage: "hand.raised.slash") }
                    }
                }
            } footer: {
                if model.blockLists.system == true {
                    Text("This is the Android phone's own block list: it refuses these calls and messages itself, whichever device you use.")
                } else {
                    Text("PolTell rejects these calls and does not forward these messages to your devices.")
                }
            }
        }
        .overlay {
            if model.blockLists.blocked.isEmpty { EmptyStateView("No Blocked Contacts", systemImage: "hand.raised") }
        }
        .navigationTitle("Blocked Contacts")
    }
}

/// Calling numbers from other apps (tel: links, Shortcuts, the Phone app's Recents); docs/USAGE.md.
struct PhoneLinksSection: View {
    @Environment(\.appModel) private var model
    @AppStorage(CallController.phoneRecentsKey) private var inPhoneRecents = false

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        Section {
            Toggle(isOn: $inPhoneRecents) { Label("Show calls in the Phone app", systemImage: "clock.arrow.circlepath") }
                .onChangeCompat(of: inPhoneRecents) { _ in model.calls.applyRecentsSetting() }
        } header: {
            Text("Numbers in other apps")
        } footer: {
            Text("Calls made here also appear in the Phone app's Recents; tapping one calls back through the Android phone. To call numbers you tap in other apps, choose this app in Settings › Apps › Default Apps › Calling (needs a paid Apple developer account), or use the \"Call with\" shortcut in the Shortcuts app.")
        }
    }
}

/// How long this build's free signature still lasts (renewed by running tools/reinstall-ios.sh on the Mac).
struct SigningSection: View {
    var body: some View {
        if let expiry = Signing.expiry, let days = Signing.daysLeft {
            Section {
                LabeledContent("App expires") {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(days == 0 ? String(localized: "Today") : String(localized: "in \(days) days"))
                            .foregroundStyle(days <= 2 ? Color.red : (days <= 4 ? Color.orange : Color.primary))
                        Text(expiry.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Renewal")
            } footer: {
                Text("A free Apple account's signature lasts 7 days. Renew it by running tools/reinstall-ios.sh on your Mac with this device unlocked and connected.")
            }
        }
    }
}

/// Link tab › Phone tools: carrier codes (balance etc.) on a SIM, "find my phone" and the ringer mode. Each part shows
/// only when the Android phone's status says it can (older Android builds of Tether do not say: the section is hidden).
struct PhoneToolsSection: View {
    @Environment(\.appModel) private var model
    let status: StatusBody
    let tools: StatusBody.PhoneTools
    @State private var code = ""
    @State private var sub: Int?

    private var chosenSub: Int? { sub ?? status.defaultSub ?? status.sims.first?.sub }

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        Section {
            if tools.ussd == true {
                HStack {
                    TextField("*123#", text: $code)
                        .keyboardType(.numbersAndPunctuation).autocorrectionDisabled().textInputAutocapitalization(.never)
                        .font(.body.monospaced())
                    Button("Send") { model.sendUssd(code, sub: chosenSub) }
                        .disabled(!UssdCode.isValid(code.trimmingCharacters(in: .whitespaces)) || model.ussdPending || !model.linkState.isConnected)
                }
                if status.sims.count > 1 {
                    Picker("SIM", selection: Binding(get: { chosenSub ?? -1 }, set: { sub = $0 })) {
                        ForEach(status.sims) { sim in Text("SIM \(sim.slot + 1) · \(sim.name)").tag(sim.sub) }
                    }
                }
                if model.ussdPending {
                    HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Waiting for the carrier…").foregroundStyle(.secondary) }
                } else if let r = model.ussdResult {
                    Text(r.ok ? (r.text ?? "") : (r.err ?? String(localized: "No answer")))
                        .font(.callout).foregroundStyle(r.ok ? Color.primary : Color.red).textSelection(.enabled)
                }
            }
            if tools.find == true {
                Toggle(isOn: Binding(get: { model.finding }, set: { model.setFinding($0) })) {
                    Label("Find phone", systemImage: "bell.and.waves.left.and.right")
                }
                .tint(.green).disabled(!model.linkState.isConnected)
            }
            if tools.ringer == true, let mode = status.ringer {
                Picker(selection: Binding(get: { mode }, set: { model.setRinger($0) })) {
                    Text("Ring").tag("normal"); Text("Vibrate").tag("vibrate"); Text("Silent").tag("silent")
                } label: { Label("Ringer", systemImage: "bell") }
                .disabled(!model.linkState.isConnected)
                if status.dnd == false {
                    Text("Silent needs Do Not Disturb access for PolTell on the Android phone.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            if let e = model.phoneToolError { Text(e).font(.footnote).foregroundStyle(.red) }
        } header: {
            Text("Phone tools")
        } footer: {
            Text("Carrier codes are sent from the Android phone's SIM and may cost money. Find phone rings the Android phone loudly for up to 30 seconds, until it is unlocked or you switch it off.")
        }
    }
}

/// One switch in the Internet section: shows the phone's state, greys out while a change is in flight.
struct NetToggle: View {
    @Environment(\.appModel) private var model
    let title: LocalizedStringKey
    let icon: String
    let what: String
    let value: Bool?

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        Toggle(isOn: Binding(get: { value ?? false }, set: { model.setNet(what, on: $0) })) {
            Label {
                HStack(spacing: 8) {
                    Text(title)
                    if model.netPending == what { ProgressView().controlSize(.small) }
                }
            } icon: {
                Image(systemName: icon)
            }
        }
        .tint(.green)
        .disabled(value == nil || model.netPending != nil || !model.linkState.isConnected)
    }
}

/// Full-screen QR scanner for the `tether1:` pairing code: the camera fills the screen with only Cancel, a short
/// instruction and "Enter Code Manually" over it (no text field or other content behind the camera); typing the
/// code is its own screen, so the keyboard never comes up behind the scanner.
struct PairingView: View {
    let done: (PairingCode?) -> Void
    @State private var error: String?
    @State private var manual = false
    @State private var cameraMissing = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if cameraMissing {
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill").font(.system(size: 40)).foregroundStyle(.white.opacity(0.6))
                    Text("Camera not available").font(.headline).foregroundStyle(.white)
                    Text("Allow camera access in Settings, or enter the code by hand.")
                        .font(.callout).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
                }
                .padding(32)
            } else {
                QRScanner(onCode: { text in
                    if let code = PairingCode.parse(text) { done(code) } else { error = String(localized: "That is not a PolTell pairing code.") }
                }, onUnavailable: { cameraMissing = true })
                .ignoresSafeArea()
                // Viewfinder: where to hold the code.
                RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.85), lineWidth: 3)
                    .frame(width: 250, height: 250).allowsHitTesting(false)
            }
            VStack {
                HStack {
                    Button("Cancel") { done(nil) }
                        .font(.body.weight(.semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(.black.opacity(0.45), in: Capsule())
                    Spacer()
                }
                .padding(.horizontal, 16)
                Spacer()
                Text(error ?? String(localized: "Scan the code shown in PolTell on the Android phone."))
                    .font(.callout).foregroundStyle(.white).multilineTextAlignment(.center)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 24)
                Button { manual = true } label: {
                    Label("Enter Code Manually", systemImage: "keyboard").font(.body.weight(.semibold))
                        .padding(.horizontal, 20).padding(.vertical, 12)
                }
                .foregroundStyle(.white).background(.white.opacity(0.2), in: Capsule())
                .padding(.top, 12).padding(.bottom, 24)
            }
        }
        .environment(\.colorScheme, .dark)   // a camera screen is dark in light mode too, as in Camera
        .statusBarHidden(false)
        .sheet(isPresented: $manual) {
            ManualPairingView { code in
                manual = false
                if let code { done(code) }
            }
        }
        #if DEBUG
        .onAppear { if ProcessInfo.processInfo.arguments.contains("-TetherDemoPairManual") { manual = true } }
        #endif
    }
}

/// Typing or pasting the `tether1:` code (from "Enter Code Manually").
struct ManualPairingView: View {
    let done: (PairingCode?) -> Void
    @State private var typed = ""
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("tether1:…", text: $typed, axis: .vertical)
                        .lineLimit(1...4).autocorrectionDisabled().textInputAutocapitalization(.never)
                        .font(.body.monospaced()).focused($focused).submitLabel(.done).onSubmit(use)
                    PasteButton(payloadType: String.self) { items in
                        if let s = items.first { typed = s.trimmingCharacters(in: .whitespacesAndNewlines) }
                    }
                } footer: {
                    Text(error ?? String(localized: "Paste or type a tether1: pairing code you have as text. The Android phone shows it as a QR code: scanning is quicker."))
                        .foregroundStyle(error == nil ? Color.secondary : Color.red)
                }
            }
            .navigationTitle("Enter Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { done(nil) } }
                ToolbarItem(placement: .confirmationAction) { Button("Pair", action: use).disabled(typed.isEmpty) }
            }
            .onAppear { focused = true }
        }
    }

    private func use() {
        if let code = PairingCode.parse(typed.trimmingCharacters(in: .whitespacesAndNewlines)) { done(code) }
        else { error = String(localized: "That is not a PolTell pairing code.") }
    }
}

struct QRScanner: UIViewControllerRepresentable {
    let onCode: (String) -> Void
    var onUnavailable: () -> Void = {}

    func makeUIViewController(context: Context) -> ScannerController {
        let c = ScannerController()
        c.onCode = onCode
        c.onUnavailable = onUnavailable
        return c
    }

    func updateUIViewController(_ vc: ScannerController, context: Context) {}

    final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var onCode: ((String) -> Void)?
        var onUnavailable: (() -> Void)?
        private let session = AVCaptureSession()
        private var last: String?

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            guard let cam = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: cam),
                  session.canAddInput(input) else {
                // No camera (simulator) or access denied: say so instead of a blank screen.
                DispatchQueue.main.async { self.onUnavailable?() }
                return
            }
            session.addInput(input)
            let out = AVCaptureMetadataOutput()
            guard session.canAddOutput(out) else { return }
            session.addOutput(out)
            out.setMetadataObjectsDelegate(self, queue: .main)
            out.metadataObjectTypes = [.qr]
            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            preview.frame = view.bounds
            view.layer.addSublayer(preview)
            DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            view.layer.sublayers?.first?.frame = view.bounds
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            session.stopRunning()
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard let s = (objects.first as? AVMetadataMachineReadableCodeObject)?.stringValue, s != last else { return }
            last = s
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onCode?(s)
        }
    }
}

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
