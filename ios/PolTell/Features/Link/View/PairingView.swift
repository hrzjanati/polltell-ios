import AVFoundation
import Perception
import SwiftUI
import PolTellCore

/// Full-screen QR scanner for the `tether1:` pairing code: the camera fills the screen with only Cancel, a short
/// instruction and "Enter Code Manually" over it (no text field or other content behind the camera); typing the
/// code is its own screen, so the keyboard never comes up behind the scanner.
struct PairingView: View {
    let done: (PairingCode?) -> Void
    @State private var vm = PairingViewModel()

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        @Perception.Bindable var vm = vm
        ZStack {
            Color.black.ignoresSafeArea()
            if vm.cameraMissing {
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill").font(.system(size: 40)).foregroundStyle(.white.opacity(0.6))
                    Text("Camera not available").font(.headline).foregroundStyle(.white)
                    Text("Allow camera access in Settings, or enter the code by hand.")
                        .font(.callout).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
                }
                .padding(32)
            } else {
                QRScanner(onCode: { text in
                    if let code = vm.scanned(text) { done(code) }
                }, onUnavailable: { vm.cameraMissing = true })
                .ignoresSafeArea()
                // Viewfinder: where to hold the code.
                RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.85), lineWidth: 3)
                    .frame(width: 250, height: 250).allowsHitTesting(false)
            }
            VStack {
                HStack {
                    Button("Cancel") { done(nil) }
                        .font(.body.weight(.semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(.black.opacity(0.45), in: Capsule())
                    Spacer()
                }
                .padding(.horizontal, 16)
                Spacer()
                Text(vm.error ?? String(localized: "Scan the code shown in PolTell on the Android phone."))
                    .font(.callout).foregroundStyle(.white).multilineTextAlignment(.center)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 24)
                Button { vm.manual = true } label: {
                    Label("Enter Code Manually", systemImage: "keyboard").font(.body.weight(.semibold))
                        .padding(.horizontal, 20).padding(.vertical, 12)
                }
                .foregroundStyle(.white).background(.white.opacity(0.2), in: Capsule())
                .padding(.top, 12).padding(.bottom, 24)
            }
        }
        .environment(\.colorScheme, .dark)   // a camera screen is dark in light mode too, as in Camera
        .statusBarHidden(false)
        .sheet(isPresented: $vm.manual) {
            ManualPairingView { code in
                vm.manual = false
                if let code { done(code) }
            }
        }
        #if DEBUG
        .onAppear { if ProcessInfo.processInfo.arguments.contains("-PolTellDemoPairManual") { vm.manual = true } }
        #endif
    }
}

/// Typing or pasting the `tether1:` code (from "Enter Code Manually").
struct ManualPairingView: View {
    let done: (PairingCode?) -> Void
    @State private var vm = PairingViewModel()
    @FocusState private var focused: Bool

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        @Perception.Bindable var vm = vm
        NavigationStack {
            Form {
                Section {
                    TextField("tether1:…", text: $vm.typed, axis: .vertical)
                        .lineLimit(1...4).autocorrectionDisabled().textInputAutocapitalization(.never)
                        .font(.body.monospaced()).focused($focused).submitLabel(.done).onSubmit { if let code = vm.submitTyped() { done(code) } }
                    PasteButton(payloadType: String.self) { items in
                        if let s = items.first { vm.paste(s) }
                    }
                } footer: {
                    Text(vm.error ?? String(localized: "Paste or type a tether1: pairing code you have as text. The Android phone shows it as a QR code: scanning is quicker."))
                        .foregroundStyle(vm.error == nil ? Color.secondary : Color.red)
                }
            }
            .navigationTitle("Enter Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { done(nil) } }
                ToolbarItem(placement: .confirmationAction) { Button("Pair") { if let code = vm.submitTyped() { done(code) } }.disabled(vm.typed.isEmpty) }
            }
            .onAppear { focused = true }
        }
    }
}

struct QRScanner: UIViewControllerRepresentable {
    let onCode: (String) -> Void
    var onUnavailable: () -> Void = {}

    func makeUIViewController(context: Context) -> ScannerController {
        let c = ScannerController()
        c.onCode = onCode
        c.onUnavailable = onUnavailable
        return c
    }

    func updateUIViewController(_ vc: ScannerController, context: Context) {}

    final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var onCode: ((String) -> Void)?
        var onUnavailable: (() -> Void)?
        private let session = AVCaptureSession()
        private var last: String?

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            guard let cam = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: cam),
                  session.canAddInput(input) else {
                // No camera (simulator) or access denied: say so instead of a blank screen.
                DispatchQueue.main.async { self.onUnavailable?() }
                return
            }
            session.addInput(input)
            let out = AVCaptureMetadataOutput()
            guard session.canAddOutput(out) else { return }
            session.addOutput(out)
            out.setMetadataObjectsDelegate(self, queue: .main)
            out.metadataObjectTypes = [.qr]
            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            preview.frame = view.bounds
            view.layer.addSublayer(preview)
            DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            view.layer.sublayers?.first?.frame = view.bounds
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            session.stopRunning()
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard let s = (objects.first as? AVMetadataMachineReadableCodeObject)?.stringValue, s != last else { return }
            last = s
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onCode?(s)
        }
    }
}

#if DEBUG
#Preview("Pairing") { PairingView { _ in } }
#Preview("Manual pairing") { ManualPairingView { _ in } }
#endif
