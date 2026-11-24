import AVFoundation
import Perception
import SwiftUI
import PolTellCore

/// What a status card means.
struct LinkInfoView: View {
    let title: LocalizedStringKey
    let icon: String
    let ok: Bool
    let text: LocalizedStringKey

    var body: some View {
        List {
            Section {
                Label { Text(ok ? "OK" : "Needs attention") } icon: {
                    Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill").foregroundStyle(ok ? .green : .orange)
                }
                Text(text).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Details of one SIM, with its network type (5G / 4G / 3G / 2G) and, with two SIMs, which one carries data.
struct SimDetailView: View {
    @State private var vm = InternetViewModel()
    let sim: SimInfo

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        List {
            Section {
                LabeledContent("Name", value: sim.name)
                LabeledContent("Carrier", value: sim.carrier)
                LabeledContent("Signal") { SimStatus(sim: sim, showName: false) }
                if sim.roaming == true { LabeledContent("Roaming", value: String(localized: "Yes")) }
            }
            Section {
                if let mode = vm.net?.mode(slot: sim.slot) {
                    Picker(selection: Binding(get: { mode }, set: { vm.setNetworkMode(slot: sim.slot, $0) })) {
                        ForEach(["5G", "4G", "3G", "2G"], id: \.self) { Text($0).tag($0) }
                    } label: {
                        Label {
                            HStack(spacing: 8) {
                                Text("Network")
                                if vm.pending == "rat\(sim.slot)" { ProgressView().controlSize(.small) }
                            }
                        } icon: { Image(systemName: "cellularbars") }
                    }
                    .disabled(vm.isLocked)
                }
                if vm.simCount > 1, let current = vm.net?.dataSub {
                    Button {
                        vm.setDataSim(sim.sub)
                    } label: {
                        Label(current == sim.sub ? "Used for mobile data" : "Use for mobile data", systemImage: current == sim.sub ? "checkmark.circle.fill" : "antenna.radiowaves.left.and.right")
                    }
                    .disabled(current == sim.sub || vm.isLocked)
                }
            }
        }
        .navigationTitle("SIM \(sim.slot + 1) · \(sim.name)")
        .navigationBarTitleDisplayMode(.inline)
    }
}
