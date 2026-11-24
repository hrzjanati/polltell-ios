import Perception
import SwiftUI
import PolTellCore

/// Green strip on top of the app while a call runs with the call screen hidden.
struct ReturnToCallBanner: View {
    @State private var vm = InCallViewModel()

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        if let call = vm.returnableCall {
            Button { vm.returnToCall() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "phone.fill")
                    Text("Touch to return to call").font(.footnote.weight(.semibold))
                    Spacer()
                    CallStatusText(call: call).font(.footnote)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color.green)
            }
            .buttonStyle(.plain)
        }
    }
}
