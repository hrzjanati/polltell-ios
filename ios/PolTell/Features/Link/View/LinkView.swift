import AVFoundation
import Perception
import SwiftUI
import PolTellCore

struct LinkView: View {
    @State private var vm = LinkViewModel()

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        @Perception.Bindable var vm = vm
        NavigationStack {
            ScrollViewReader { scroller in
            List {
                Section {
                    LinkDashboard(stateLine: vm.stateLine, onScan: { vm.startScanning() })
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
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

                if let s = vm.status {
                    Section {
                        InternetControls(status: s)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    VPNSection().id("vpn")
                    if let t = s.tools, t.ussd == true || t.find == true || t.ringer == true {
                        PhoneToolsSection(status: s, tools: t).id("phonetools")
                    }
                    FoldSection(title: "Call audio") {
                        LabeledContent("Audio helper", value: s.helper.state == "running" ? String(localized: "Running") : String(localized: "Stopped"))
                        if let m = s.helper.method { LabeledContent("Method", value: m) }
                        if let q = s.helper.silent {
                            LabeledContent("Android phone silent", value: q == "full" ? String(localized: "Yes") :
                                q == "earpiece" ? String(localized: "Earpiece only") : String(localized: "No"))
                        }
                        if let a = vm.audioStats {
                            LabeledContent("Last call") {
                                Text(String(format: "buffer %.0f ms · jitter %.1f ms · gaps %d", a.delayMs, a.jitterMs, a.underruns))
                                    .font(.caption.monospacedDigit())
                            }
                        }
                        Button("Run call-audio self-test") { vm.runSelftest() }
                            .disabled(!vm.isConnected)
                        if let st = vm.selftest {
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
                            Text("\(vm.blockedCount)")
                        } label: {
                            Label("Blocked Contacts", systemImage: "hand.raised")
                        }
                    }
                } footer: {
                    Text("Kept on the Android phone and shared by all your devices.")
                }

                FoldSection(title: "Sync and pairing", footer: "On the Android phone, open PolTell and tap Pair iPhone, then scan the code (or paste it). Calls, messages, contacts and call history stay between your devices; there is no server.") {
                    if let last = vm.lastSync {
                        LabeledContent("Last sync", value: last.formatted(date: .omitted, time: .shortened))
                    }
                    Button("Sync everything again") { vm.syncAll() }.disabled(!vm.isConnected)
                    NavigationLink("Link log") { LinkLogView() }
                    if vm.isPaired {
                        Button("Unpair", role: .destructive) { vm.confirmUnpair = true }
                    }
                }
            }
            #if DEBUG
            // -PolTellDemoVPN: start scrolled to the VPN section (screenshots).
            .onAppear {
                if ProcessInfo.processInfo.arguments.contains("-PolTellDemoPair") || ProcessInfo.processInfo.arguments.contains("-PolTellDemoPairManual") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { vm.scanning = true }
                }
                if ProcessInfo.processInfo.arguments.contains("-PolTellDemoPhoneTools") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { scroller.scrollTo("phonetools", anchor: .top) }
                }
                if ProcessInfo.processInfo.arguments.contains("-PolTellDemoVPN") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { scroller.scrollTo("vpn", anchor: .top) }
                }
            }
            #endif
            }
            .navigationTitle("Link")
            .onAppear { vm.appeared() }
            .onChangeCompat(of: vm.isConnected) { _ in vm.connectionChanged() }
            // Full screen: nothing of the Link tab shows around or behind the camera.
            .fullScreenCover(isPresented: $vm.scanning) {
                PairingView { vm.paired($0) }
                .environment(\.appModel, AppModel.shared)
            }
            .confirmationDialog("Forget the Android phone and delete synced data from this iPhone?", isPresented: $vm.confirmUnpair,
                                titleVisibility: .visible) {
                Button("Unpair", role: .destructive) { vm.unpair() }
            }
        }
    }
}

#if DEBUG
#Preview("Link") { LinkView() }
#endif
