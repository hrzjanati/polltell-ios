import Perception
import SwiftUI
@_spi(PolTellApp) import PolTellCore

/// Full-screen call UI in the style of the iOS Phone app: caller and status on top, a 3×2 grid of
/// round controls, the red end button centred below. Actions go through CallKit so the system
/// call state (lock screen, Dynamic Island, AirPods buttons) stays in sync.
struct InCallView: View {
    @State private var vm = InCallViewModel()

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        @Perception.Bindable var vm = vm
        if let call = vm.call {
            ZStack {
                background(call)
                VStack(spacing: 0) {
                    header(call)
                        .padding(.top, 60)
                    Spacer()
                    if vm.keypad {
                        KeypadPad(typed: $vm.typed) { d in vm.dtmf(call, d) }
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    } else if call.state == "ringing" {
                        incomingControls(call)
                    } else {
                        controls(call)
                    }
                    Spacer()
                    bottomRow(call)
                        .padding(.bottom, 48)
                }
                .padding(.horizontal, 32)
            }
            .foregroundStyle(.white)
            .preferredColorScheme(.dark)
            .animation(.easeInOut(duration: 0.2), value: vm.keypad)
            .onChangeCompat(of: call.uuid) { _ in vm.callChanged() }
        }
    }

    private func background(_ call: CallScreen) -> some View {
        ZStack {
            Color.black
            if let img = vm.photo(call) {
                // Like a contact poster: the caller's photo fills the screen, softened so the controls stay readable.
                GeometryReader { geo in
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height).clipped()
                        .blur(radius: 28, opaque: true)
                }
                LinearGradient(colors: [.black.opacity(0.25), .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
            } else {
                LinearGradient(colors: [Color("AccentColor").opacity(0.55), Color("AccentColor").opacity(0.12), .black],
                               startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [Color("AccentColor").opacity(0.35), .clear], center: .init(x: 0.5, y: 0.62),
                               startRadius: 10, endRadius: 320)
            }
        }
        .ignoresSafeArea()
    }

    private func header(_ call: CallScreen) -> some View {
        VStack(spacing: 8) {
            HStack {
                Button { vm.hideScreen() } label: {
                    Image(systemName: "chevron.down").font(.body.weight(.semibold))
                        .frame(width: 44, height: 44).glassSurface(Circle())
                }
                .accessibilityLabel(Text("Hide call screen"))
                Spacer()
                if let sim = vm.simName(call) {
                    Label(sim, systemImage: "simcard").font(.footnote.weight(.medium)).opacity(0.7)
                }
            }
            if !vm.keypad, let img = vm.photo(call) {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: 112, height: 112).clipShape(Circle())
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
                    .padding(.top, 4).padding(.bottom, 6)
            }
            if vm.keypad && !vm.typed.isEmpty {
                Text(vm.typed).font(.largeTitle.weight(.light)).lineLimit(1).minimumScaleFactor(0.5)
                    .environment(\.layoutDirection, .leftToRight)
            } else {
                Text(vm.title(call))
                    .font(.largeTitle)
                    .lineLimit(1).minimumScaleFactor(0.5)
            }
            CallStatusText(call: call)
                .font(.body)
                .opacity(0.75)
        }
        .frame(maxWidth: .infinity)
    }

    private func controls(_ call: CallScreen) -> some View {
        let enabled = call.state != "ended"
        return GlassGroup { Grid(horizontalSpacing: 26, verticalSpacing: 26) {
            GridRow {
                if call.routes.contains(where: { !$0.kind.isBuiltIn }) {
                    AudioRouteMenu(call: call) { (routeID: String) in vm.selectRoute(routeID) }
                } else {
                    RoundControl(icon: call.speaker ? "speaker.wave.3.fill" : "speaker.wave.2.fill", label: "Speaker", on: call.speaker) {
                        vm.toggleSpeaker(call)
                    }
                }
                RoundControl(icon: call.held ? "pause.fill" : "pause", label: "Hold", on: call.held) {
                    vm.toggleHold(call)
                }
                .disabled(call.state != "active" && call.state != "holding")
                RoundControl(icon: call.muted ? "mic.slash.fill" : "mic.slash", label: "Mute", on: call.muted) {
                    vm.toggleMute(call)
                }
            }
            GridRow {
                RoundControl(icon: "person.badge.plus", label: "Add", on: false) {}
                    .disabled(true).opacity(0.4)
                RoundControl(icon: "circle.grid.3x3.fill", label: "Keypad", on: false) { vm.keypad = true }
                RoundControl(icon: "person.crop.circle", label: "Contacts", on: false) {
                    vm.showContacts()
                }
            }
        } }
        .disabled(!enabled)
    }

    private func incomingControls(_ call: CallScreen) -> some View {
        HStack {
            VStack(spacing: 10) {
                CallButton(color: .red, icon: "phone.down.fill") { vm.end(call) }
                Text("Decline").font(.footnote)
            }
            Spacer()
            VStack(spacing: 10) {
                CallButton(color: .green, icon: "phone.fill") { vm.answer(call) }
                Text("Accept").font(.footnote)
            }
        }
        .padding(.horizontal, 12)
    }

    @ViewBuilder private func bottomRow(_ call: CallScreen) -> some View {
        if call.state == "ringing" {
            EmptyView()
        } else {
            ZStack {
                CallButton(color: .red, icon: "phone.down.fill") { vm.end(call) }
                    .disabled(call.state == "ended")
                    .opacity(call.state == "ended" ? 0.5 : 1)
                if vm.keypad {
                    HStack {
                        Spacer()
                        Button("Hide") { vm.keypad = false }.font(.body).padding(.trailing, 8)
                    }
                }
            }
        }
    }
}

#if DEBUG
#Preview("In call") {
    let _ = { AppModel.shared.callScreen = CallScreen(uuid: UUID(), number: "+15550101", name: "Hossein Rezazadeh", state: "active",
                                                      incoming: true, connectedAt: Date().addingTimeInterval(-42), sub: 3) }()
    InCallView()
}
#Preview("Dialing") {
    let _ = { AppModel.shared.callScreen = CallScreen(uuid: UUID(), number: "+15550101", name: "Hossein Rezazadeh", state: "dialing",
                                                      incoming: false, connectedAt: nil, sub: 3) }()
    InCallView()
}
#endif
