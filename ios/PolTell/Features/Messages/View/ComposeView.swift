import Perception
import SwiftUI
import PolTellCore

struct ComposeView: View {
    var initialTo = ""
    let done: (Int64?) -> Void
    @State private var vm = ComposeViewModel()
    private enum Field { case to, message }
    @FocusState private var field: Field?

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        @Perception.Bindable var vm = vm
        NavigationStack {
            Form {
                Section {
                    // Name or number (suggestions search both); Return moves on to the message.
                    TextField("To", text: $vm.to).keyboardType(.namePhonePad).textContentType(.telephoneNumber)
                        .autocorrectionDisabled().focused($field, equals: .to)
                        .submitLabel(.next).onSubmit { field = .message }
                    if !vm.to.isEmpty {
                        ForEach(vm.suggestions, id: \.number) { s in
                            Button { vm.to = s.number; field = .message } label: {
                                VStack(alignment: .leading) { Text(s.name); Text(vm.formatted(s.number)).font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                    }
                }
                Section {
                    TextField("Message", text: $vm.text, axis: .vertical).lineLimit(3...8).focused($field, equals: .message)
                    SimPicker(sub: $vm.sub)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .keyboardDoneButton()
            .navigationTitle("New message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { done(nil) } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { done(vm.send()) }.disabled(!vm.canSend)
                }
            }
            .onAppear {
                vm.appeared(initialTo: initialTo)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { field = vm.to.isEmpty ? .to : .message }
            }
        }
    }
}

#if DEBUG
#Preview("New message") { ComposeView { _ in } }
#endif
