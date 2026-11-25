import Perception
import SwiftUI
import PolTellCore

#if DEBUG
/// Debug builds only: try the extensions (protocol §7) against the linked Android phone. Not translated on purpose.
struct DeveloperSection: View {
    @Environment(\.appModel) private var model
    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        Section {
            Button { model.echoTest() } label: { Text(verbatim: "Echo round trip (x.tether.echo)") }
                .disabled(!model.linkState.isConnected)
            if let line = model.extensionLine { Text(verbatim: line).font(.footnote) }
            Text(verbatim: model.extensions.summary).font(.caption2.monospaced()).foregroundStyle(.secondary)
        } header: {
            Text(verbatim: "Developer")
        } footer: {
            Text(verbatim: "Debug builds only. Add your own feature: docs/EXTENDING.md.")
        }
    }
}
#endif
