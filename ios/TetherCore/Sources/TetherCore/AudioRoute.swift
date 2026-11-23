import Foundation

/// Call-audio routes, decided without AVFoundation so the rules can be tested: the app maps
/// `AVAudioSession.Port` raw values and port UIDs onto these and applies the resulting plan.
public enum RouteKind: String, Sendable, Equatable, CaseIterable {
    case receiver, speaker, bluetooth, car, wired, usb, airPlay, other

    /// Classifies an `AVAudioSession.Port` raw value (input or output).
    public init(port: String) {
        switch port {
        case "Receiver", "MicrophoneBuiltIn": self = .receiver
        case "Speaker": self = .speaker
        case "BluetoothHFP", "BluetoothA2DPOutput", "BluetoothLE": self = .bluetooth
        case "CarAudio": self = .car
        case "Headphones", "HeadsetMicrophone", "LineIn", "LineOut": self = .wired
        case "USBAudio": self = .usb
        case "AirPlay": self = .airPlay
        default: self = .other
        }
    }

    /// Audio leaves the iPhone itself (receiver or loudspeaker).
    public var isBuiltIn: Bool { self == .receiver || self == .speaker }
}

/// One entry of the call screen's audio menu.
public struct RouteOption: Sendable, Equatable, Identifiable {
    /// "iphone", "speaker", or the input port's UID for an accessory.
    public let id: String
    public let kind: RouteKind
    /// Shown on screen only (a device's own name); never logged.
    public let name: String
    public init(id: String, kind: RouteKind, name: String) { self.id = id; self.kind = kind; self.name = name }

    public static let iPhoneID = "iphone"
    public static let speakerID = "speaker"
}

/// An input the session offers (`availableInputs`), as port type + UID + name.
public struct RoutePort: Sendable, Equatable {
    public let type: String, uid: String, name: String
    public init(type: String, uid: String, name: String) { self.type = type; self.uid = uid; self.name = name }
}

/// What to do with the session for a choice: which input to prefer (nil: none / leave it to the system) and
/// whether to override the output to the loudspeaker.
public struct RoutePlan: Sendable, Equatable {
    public let preferredInputUID: String?
    public let speakerOverride: Bool
    public init(preferredInputUID: String?, speakerOverride: Bool) {
        self.preferredInputUID = preferredInputUID; self.speakerOverride = speakerOverride
    }
}

public enum AudioRoutes {
    /// The options for the menu: iPhone and Speaker always, then each accessory input (Bluetooth hands-free,
    /// car, wired headset, USB) once, in the session's order.
    public static func options(inputs: [RoutePort], hasReceiver: Bool = true) -> [RouteOption] {
        var out: [RouteOption] = []
        if hasReceiver { out.append(RouteOption(id: RouteOption.iPhoneID, kind: .receiver, name: "iPhone")) }
        out.append(RouteOption(id: RouteOption.speakerID, kind: .speaker, name: "Speaker"))
        var seen = Set<String>()
        for p in inputs {
            let k = RouteKind(port: p.type)
            guard !k.isBuiltIn, seen.insert(p.uid).inserted else { continue }
            out.append(RouteOption(id: p.uid, kind: k, name: p.name))
        }
        return out
    }

    /// The route in use from the current outputs (an accessory wins over the built-in ports).
    public static func current(outputs: [String]) -> RouteKind {
        let kinds = outputs.map(RouteKind.init(port:))
        if let accessory = kinds.first(where: { !$0.isBuiltIn }) { return accessory }
        if kinds.contains(.speaker) { return .speaker }
        return .receiver
    }

    /// The selected option for the current route: the accessory whose UID is in use (input or output), else the
    /// built-in one.
    public static func selected(outputs: [RoutePort], inputs: [RoutePort], options: [RouteOption]) -> String {
        let used = Set((outputs + inputs).map(\.uid))
        let ids = Set(options.map(\.id))
        // A hands-free device's input and output ports share their UID prefix (the Bluetooth address).
        for o in options where o.id != RouteOption.iPhoneID && o.id != RouteOption.speakerID {
            if used.contains(o.id) || used.contains(where: { sameDevice($0, o.id) }) { return o.id }
        }
        let kind = current(outputs: outputs.map(\.type))
        if kind == .speaker { return RouteOption.speakerID }
        if kind.isBuiltIn || !ids.contains(RouteOption.iPhoneID) { return ids.contains(RouteOption.iPhoneID) ? RouteOption.iPhoneID : RouteOption.speakerID }
        return kind.rawValue   // an output-only accessory (AirPlay…) not in the menu
    }

    /// The session changes for picking `id`. iPhone and Speaker prefer the built-in microphone, which takes the
    /// call off a hands-free device (removing only the speaker override would leave it there).
    public static func plan(for id: String, builtInMicUID: String?) -> RoutePlan {
        switch id {
        case RouteOption.iPhoneID: return RoutePlan(preferredInputUID: builtInMicUID, speakerOverride: false)
        case RouteOption.speakerID: return RoutePlan(preferredInputUID: builtInMicUID, speakerOverride: true)
        default: return RoutePlan(preferredInputUID: id, speakerOverride: false)
        }
    }

    /// The speaker button shows the real route only: on when the loudspeaker plays, whatever chose it.
    public static func speakerOn(outputs: [String]) -> Bool { current(outputs: outputs) == .speaker }

    /// The speaker choice to re-apply when the session is (re)activated: only when the call is still on the
    /// built-in ports; a headset or car that took the call wins.
    public static func reapplySpeaker(wanted: Bool, outputs: [String]) -> Bool {
        wanted && current(outputs: outputs).isBuiltIn
    }

    static func sameDevice(_ a: String, _ b: String) -> Bool {
        func base(_ s: String) -> Substring { s.split(separator: "-").first ?? Substring(s) }
        return a.count >= 12 && b.count >= 12 && base(a) == base(b)
    }
}

/// The I/O formats the engine was built with; a route change that alters them needs a new graph and converters
/// (a hands-free microphone runs at 16 or 8 kHz, the built-in one at 48 kHz).
public struct EngineFormat: Sendable, Equatable {
    public let inputRate: Double, inputChannels: Int, outputRate: Double, outputChannels: Int
    public init(inputRate: Double, inputChannels: Int, outputRate: Double, outputChannels: Int) {
        self.inputRate = inputRate; self.inputChannels = inputChannels
        self.outputRate = outputRate; self.outputChannels = outputChannels
    }
}

public enum EngineRebuild: Sendable, Equatable {
    /// Leave the engine alone.
    case keep
    /// Tear down and build a fresh engine (new graph, new converters), keeping the call's state.
    case rebuild
    /// The engine stopped itself on a configuration change but the formats are the same: start the same engine
    /// again (a fresh voice-processing engine posts another change when it starts, which looped on a real iPhone).
    case restart
    /// No usable input yet (the route is still settling): try again shortly.
    case retryLater
}

public enum EngineDecision {
    /// After `AVAudioEngineConfigurationChange` or a route change while a call's session is active.
    /// - running: the engine is running; built: the formats it was built with; now: the session's formats now.
    /// - engineRunning: the audio engine itself still runs. Starting a voice-processing engine posts a configuration
    ///   change and a route change of its own on a real iPhone; rebuilding for those started the next one, in a loop
    ///   (every ~0.4 s, no uplink, seen 2026-11-23). An engine that still runs in the same formats is left alone.
    /// - recentRebuilds: rebuilds in the last few seconds; past `maxRebuilds` only a stopped engine is rebuilt.
    public static let maxRebuilds = 4

    public static func onRouteEvent(sessionActive: Bool, running: Bool, configurationChanged: Bool,
                                    built: EngineFormat?, now: EngineFormat, engineRunning: Bool = false,
                                    recentRebuilds: Int = 0) -> EngineRebuild {
        guard sessionActive else { return .keep }
        if now.inputRate <= 0 || now.inputChannels <= 0 || now.outputRate <= 0 { return .retryLater }
        if !running { return .rebuild }
        let sameFormats = built.map { $0 == now } ?? false
        if engineRunning && (sameFormats || recentRebuilds >= maxRebuilds) { return .keep }
        if configurationChanged {
            // The engine stopped itself: the same one again when nothing changed, a fresh graph for new formats.
            if sameFormats || recentRebuilds >= maxRebuilds { return engineRunning ? .keep : .restart }
            return .rebuild
        }
        return sameFormats ? .keep : .rebuild
    }
}
