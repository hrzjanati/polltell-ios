import Perception
import SwiftUI
import PolTellCore

/// SIM choice for a call or a conversation.
struct SimPicker: View {
    @Environment(\.appModel) private var model
    @Binding var sub: Int?

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        if model.sims.count > 1 {
            Menu {
                ForEach(model.sims) { sim in
                    Button {
                        sub = sim.sub
                    } label: {
                        Label("\(sim.name) · \(sim.carrier)", systemImage: sub == sim.sub ? "checkmark" : "simcard")
                    }
                }
                .onAppear { hideKeyboard() }   // the menu must not open under / over the keyboard
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "simcard")
                    Text(label).font(.caption.weight(.medium))
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color(.tertiarySystemFill), in: Capsule())
            }
        }
    }

    private var label: String {
        guard let sim = model.sims.first(where: { $0.sub == sub }) else { return String(localized: "SIM") }
        return sim.name.isEmpty ? "SIM \(sim.slot + 1)" : sim.name
    }
}
