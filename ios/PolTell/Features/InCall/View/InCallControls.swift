import Perception
import SwiftUI
@_spi(PolTellApp) import PolTellCore

/// "calling…", "00:42", "on hold", "Call ended" – ticking once a second.
struct CallStatusText: View {
    let call: CallScreen

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            Text(status(at: ctx.date)).monospacedDigit()
        }
    }

    private func status(at now: Date) -> String {
        switch call.state {
        case "dialing", "connecting": String(localized: "calling…")
        case "ringing": String(localized: "Incoming call")
        case "holding": String(localized: "On hold")
        case "ended": String(localized: "Call ended")
        default:
            if let t = call.connectedAt {
                Duration.seconds(Int(now.timeIntervalSince(t))).formatted(.time(pattern: .minuteSecond))
            } else { "" }
        }
    }
}

/// The call's audio menu once a headset, car or other accessory is available (like the Phone app's "Audio"):
/// iPhone, Speaker and each accessory, with the current one checked. It follows routes chosen elsewhere.
struct AudioRouteMenu: View {
    let call: CallScreen
    let select: (String) -> Void
    @Environment(\.isEnabled) private var enabled

    static func icon(_ k: RouteKind) -> String {
        switch k {
        case .receiver: "iphone"
        case .speaker: "speaker.wave.3.fill"
        case .bluetooth: "headphones"
        case .car: "car.fill"
        case .wired: "headphones"
        case .usb: "cable.connector"
        case .airPlay: "airplayaudio"
        case .other: "speaker.wave.2.fill"
        }
    }

    var body: some View {
        let onAccessory = !call.route.isBuiltIn
        Menu {
            ForEach(call.routes) { r in
                Button { select(r.id) } label: {
                    if r.id == call.selectedRoute { Label(r.id == RouteOption.speakerID ? String(localized: "Speaker") : r.name, systemImage: "checkmark") }
                    else { Label(r.id == RouteOption.speakerID ? String(localized: "Speaker") : r.name, systemImage: Self.icon(r.kind)) }
                }
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: Self.icon(call.route == .receiver ? .speaker : call.route))
                    .font(.system(size: 28, weight: .regular))
                    .frame(width: 78, height: 78)
                    .foregroundStyle(onAccessory || call.speaker ? Color.black : Color.white)
                    .glassSurface(Circle(), tint: onAccessory || call.speaker ? .white : nil)
                Text("Audio").font(.footnote.weight(.medium)).foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.45)
        .accessibilityLabel(Text("Audio"))
    }
}

struct RoundControl: View {
    let icon: String
    let label: LocalizedStringKey
    let on: Bool
    let action: () -> Void
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .regular))
                    .frame(width: 78, height: 78)
                    .foregroundStyle(on ? Color.black : Color.white)
                    .glassSurface(Circle(), tint: on ? .white : nil)
                Text(label).font(.footnote.weight(.medium))
            }
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.45)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

struct CallButton: View {
    let color: Color
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 78, height: 78)
                .glassSurface(Circle(), tint: color)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(icon.contains("down") ? "End" : icon.contains("xmark") ? "Decline" : "Answer"))
    }
}

/// DTMF keypad shown inside the call screen.
struct KeypadPad: View {
    @Binding var typed: String
    let send: (String) -> Void
    private let keys: [[(String, String)]] = [
        [("1", ""), ("2", "ABC"), ("3", "DEF")],
        [("4", "GHI"), ("5", "JKL"), ("6", "MNO")],
        [("7", "PQRS"), ("8", "TUV"), ("9", "WXYZ")],
        [("*", ""), ("0", "+"), ("#", "")],
    ]

    var body: some View {
        GlassGroup(spacing: 16) { VStack(spacing: 16) {
            ForEach(keys.indices, id: \.self) { r in
                HStack(spacing: 26) {
                    ForEach(keys[r], id: \.0) { k in
                        Button {
                            typed.append(k.0)
                            send(k.0)
                        } label: {
                            VStack(spacing: 0) {
                                Text(k.0).font(.system(size: 34, weight: .regular))
                                if !k.1.isEmpty { Text(k.1).font(.caption2.weight(.semibold)).opacity(0.7) }
                            }
                            .frame(width: 78, height: 78)
                            .glassSurface(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        }
        .environment(\.layoutDirection, .leftToRight)
    }
}
