import Perception
import SwiftUI
import PolTellCore

struct AddContactView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm = ContactEditorViewModel()

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        @Perception.Bindable var vm = vm
        NavigationStack {
            Form {
                Section { TextField("Name", text: $vm.name) }
                Section {
                    TextField("Phone", text: $vm.phone).keyboardType(.phonePad)
                    Picker("Type", selection: $vm.type) {
                        Text("Mobile").tag("mobile"); Text("Home").tag("home"); Text("Work").tag("work"); Text("Other").tag("other")
                    }
                    TextField("Email", text: $vm.email).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                }
                Section { Text("The contact is saved on your Android phone.").font(.footnote).foregroundStyle(.secondary) }
            }
            .scrollDismissesKeyboard(.interactively)
            .keyboardDoneButton()
            .navigationTitle("New contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vm.add()
                        dismiss()
                    }
                    .disabled(!vm.canAdd)
                }
            }
        }
    }
}
