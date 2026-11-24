import Perception
import SwiftUI
import PolTellCore

/// A call whose audio is on the other device (answered or dialed there): one tap moves it here.
struct RemoteCallBanner: View {
    @State private var vm = RootViewModel()

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        ForEach(vm.remoteCalls, id: \.cid) { c in
            HStack(spacing: 8) {
                Image(systemName: "arrow.left.arrow.right")
                VStack(alignment: .leading, spacing: 1) {
                    Text(vm.displayName(c.num)).font(.footnote.weight(.semibold)).lineLimit(1)
                    Text("On \(c.at ?? String(localized: "another device"))").font(.caption2).opacity(0.85)
                }
                Spacer()
                Button {
                    vm.take(c)
                } label: {
                    Text("Move here").font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(.white.opacity(0.22), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(Color.secondaryAccentSolid)
        }
    }
}
