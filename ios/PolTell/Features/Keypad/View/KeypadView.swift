import Perception
import SwiftUI
import PolTellCore

struct KeypadView: View {
    @State private var vm = KeypadViewModel()

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        @Perception.Bindable var vm = vm
        VStack(spacing: 18) {
            Spacer()
            Text(vm.displayNumber)
                .font(.system(size: 36, weight: .regular))
                .lineLimit(1).minimumScaleFactor(0.5)
                .environment(\.layoutDirection, .leftToRight)
                .contextMenu {
                    Button { vm.paste() } label: { Label("Paste", systemImage: "doc.on.clipboard") }
                }
            if let name = vm.contactName {
                Text(name).font(.subheadline).foregroundStyle(.secondary)
            } else {
                Button { vm.paste() } label: {
                    Label("Paste", systemImage: "doc.on.clipboard").font(.caption)
                }
            }
            SimPicker(sub: $vm.sub)
            GlassGroup(spacing: 14) { VStack(spacing: 14) {
                ForEach(KeypadKey.rows.indices, id: \.self) { r in
                    HStack(spacing: 26) {
                        ForEach(KeypadKey.rows[r], id: \.digit) { k in
                            Button { vm.tap(k) } label: {
                                VStack(spacing: 0) {
                                    Text(k.digit).font(.system(size: 32, weight: .regular))
                                    Text(k.letters).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                                }
                                .frame(width: 78, height: 78)
                                .glassSurface(Circle())
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(LongPressGesture().onEnded { _ in vm.hold(k) })
                        }
                    }
                }
            } }
            .environment(\.layoutDirection, .leftToRight)
            HStack(spacing: 26) {
                Color.clear.frame(width: 78, height: 78)
                Button { vm.call() } label: {
                    Image(systemName: "phone.fill").font(.system(size: 30)).foregroundStyle(.white).accessibilityLabel(Text("Call"))
                        .frame(width: 78, height: 78).glassSurface(Circle(), tint: .green)
                }
                .disabled(!vm.canCall)
                Button { vm.backspace() } label: {
                    Image(systemName: "delete.left").font(.system(size: 24)).frame(width: 78, height: 78).accessibilityLabel(Text("Delete"))
                }
                .opacity(vm.number.isEmpty ? 0 : 1)
            }
            .environment(\.layoutDirection, .leftToRight)
            Spacer()
        }
        .onAppear { vm.appeared() }
        .onChangeCompat(of: vm.routedNumber) { _ in vm.takeRouted() }
    }
}

#if DEBUG
#Preview("Keypad") { KeypadView() }
#endif
