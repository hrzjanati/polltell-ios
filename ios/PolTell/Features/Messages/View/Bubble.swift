import Perception
import SwiftUI
import PolTellCore

/// Message bubble outline: a rounded rectangle, with the small tail Messages draws on the last bubble of a run.
struct BubbleShape: Shape {
    var mine: Bool
    var tail: Bool

    func path(in rect: CGRect) -> Path {
        let r: CGFloat = min(18, rect.height / 2)
        var p = Path(roundedRect: rect, cornerRadius: r, style: .continuous)
        if tail {
            // Drawn for the trailing (outgoing) side, then mirrored for incoming bubbles.
            var t = Path()
            let x = rect.maxX, y = rect.maxY
            t.move(to: CGPoint(x: x - r, y: y))
            t.addLine(to: CGPoint(x: x - 4, y: y))
            t.addQuadCurve(to: CGPoint(x: x + 6, y: y), control: CGPoint(x: x + 1, y: y + 0.5))
            t.addQuadCurve(to: CGPoint(x: x, y: y - 9), control: CGPoint(x: x + 0.5, y: y - 2))
            t.addLine(to: CGPoint(x: x, y: y - r))
            t.closeSubpath()
            if !mine {
                t = t.applying(CGAffineTransform(translationX: rect.minX + rect.maxX, y: 0).scaledBy(x: -1, y: 1))
            }
            if #available(iOS 17, *) { p = p.union(t) } else { p = Path(p.cgPath.union(t.cgPath)) }   // not addPath: opposite winding would punch a notch where the two overlap
        }
        return p
    }
}

struct Bubble: View {
    @Environment(\.layoutDirection) private var direction
    let message: Sms
    var tail = true
    @State private var vm: BubbleViewModel

    init(message: Sms, tail: Bool = true) {
        self.message = message
        self.tail = tail
        _vm = State(initialValue: BubbleViewModel(message: message))
    }

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        @Perception.Bindable var vm = vm
        let mine = !message.incoming
        // The shape is drawn in left-to-right coordinates; in right-to-left layouts the sides swap.
        let onRight = (direction == .leftToRight) == mine
        let rich = RichTextCache.shared.entry(for: message, mine: mine)
        VStack(alignment: mine ? .trailing : .leading, spacing: 4) {
            HStack(spacing: 0) {
                if mine { Spacer(minLength: 60) }
                Text(rich.text)
                    // The text's own direction (Persian / English) decides its alignment, whatever the app language.
                    .environment(\.layoutDirection, rich.parsed.rightToLeft ? .rightToLeft : .leftToRight)
                    .multilineTextAlignment(.leading)
                    .tint(mine ? .white : Color("AccentColor"))
                    .padding(.horizontal, 13).padding(.vertical, 8)
                    .foregroundStyle(mine ? .white : .primary)
                    .background(mine ? Color.green : Color(.systemGray5), in: BubbleShape(mine: onRight, tail: tail))
                    .contentShape(.contextMenuPreview, BubbleShape(mine: onRight, tail: false))
                    .environment(\.openURL, OpenURLAction { url in handle(url) })
                    .contextMenu { menu(rich.parsed) }
                if message.box == 5 {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red).padding(.leading, 6)
                }
                if !mine { Spacer(minLength: 60) }
            }
            // One-time code: a one-tap copy button under the bubble, as Messages does.
            if message.incoming, let code = rich.parsed.code {
                Button { vm.copy(code) } label: {
                    Label("Copy code \(code)", systemImage: "doc.on.doc")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
        }
        .padding(.horizontal, 4)
        .confirmationDialog("Delete Message", isPresented: $vm.confirmDelete, titleVisibility: .visible) {
            Button("Delete Message", role: .destructive) { vm.delete() }
        } message: {
            Text("This message will be deleted from your Android phone and all your devices.")
        }
        .confirmationDialog(vm.phone ?? "", isPresented: Binding(get: { vm.phone != nil }, set: { if !$0 { vm.phone = nil } }),
                            titleVisibility: .visible) {
            if let n = vm.phone {
                Button("Call \(n)") { vm.call(n) }
                Button("Send message") { vm.sendMessage(to: n) }
                Button("Copy") { vm.copyNumber(n) }
            }
        }
    }

    private func handle(_ url: URL) -> OpenURLAction.Result {
        switch RichTextAction(url) {
        case .copyCode(let c): vm.copy(c); return .handled
        case .phone(let n): hideKeyboard(); vm.phone = n; return .handled
        case .system(let u): return .systemAction(u)
        }
    }

    @ViewBuilder private func menu(_ p: ParsedMessage) -> some View {
        Button { vm.copyBody() } label: { Label("Copy", systemImage: "doc.on.doc") }
            .onAppear { hideKeyboard() }
        ForEach(Array(p.entities.enumerated()), id: \.offset) { _, e in
            switch e.kind {
            case .code(let c):
                Button { vm.copy(c) } label: { Label("Copy code \(c)", systemImage: "number") }
            case .link(let url):
                Button { vm.copyLink(url) } label: { Label("Copy link", systemImage: "link") }
                ShareLink(item: url) { Label("Share link", systemImage: "square.and.arrow.up") }
            case .phone(let n):
                Button { vm.call(n) } label: { Label("Call \(n)", systemImage: "phone") }
                Button { vm.copyRaw(n) } label: { Label("Copy \(n)", systemImage: "doc.on.doc") }
            case .email(let a):
                Button { vm.copyRaw(a) } label: { Label("Copy \(a)", systemImage: "envelope") }
            case .address:
                EmptyView()
            }
        }
        Divider()
        Button(role: .destructive) { hideKeyboard(); vm.confirmDelete = true } label: { Label("Delete", systemImage: "trash") }
        Text(Date(millis: message.date).formatted(date: .abbreviated, time: .shortened))
    }
}
