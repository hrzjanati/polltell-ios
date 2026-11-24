import Perception
import SwiftUI
import PolTellCore

/// Edit an existing contact, laid out like the iOS Contacts editor: name, then phone and e-mail rows that
/// can be added, retyped and removed. Saving rewrites the contact on the Android phone.
struct EditContactView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm: ContactEditorViewModel

    init(contact: Contact) { _vm = State(initialValue: ContactEditorViewModel(contact: contact)) }

    // The editor's row types and the phone mapping live in the model; these keep their old names for callers and tests.
    typealias PhoneRow = EditablePhone
    static let custom = EditablePhone.custom
    static func phone(from row: PhoneRow) -> Phone { row.asPhone }

    var body: some View { WithPerceptionTracking { bodyContent } }

    @ViewBuilder private var bodyContent: some View {
        @Perception.Bindable var vm = vm
        NavigationStack {
            Form {
                Section {
                    HStack { Spacer(); Avatar(name: vm.avatarName, photo: vm.avatarPhoto, size: 80); Spacer() }
                        .listRowBackground(Color.clear)
                    TextField("Name", text: $vm.name)
                }
                Section {
                    ForEach($vm.phones) { $p in
                        HStack {
                            Picker("", selection: $p.type) {
                                if let label = p.label { Text(verbatim: label).tag(EditablePhone.custom) }
                                ForEach(vm.kinds, id: \.self) { Text(LocalizedStringKey($0.capitalized)).tag($0) }
                            }
                            .labelsHidden().fixedSize()
                            TextField("Phone", text: $p.number).keyboardType(.phonePad)
                                .environment(\.layoutDirection, .leftToRight)
                        }
                    }
                    .onDelete { vm.phones.remove(atOffsets: $0) }
                    Button { vm.addPhoneRow() } label: {
                        Label("Add phone", systemImage: "plus.circle.fill")
                    }
                }
                Section {
                    ForEach($vm.emails) { $e in
                        TextField("Email", text: $e.address).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                    }
                    .onDelete { vm.emails.remove(atOffsets: $0) }
                    Button { vm.addEmailRow() } label: {
                        Label("Add email", systemImage: "plus.circle.fill")
                    }
                }
                Section { Text("Changes are saved on your Android phone.").font(.footnote).foregroundStyle(.secondary) }
            }
            .scrollDismissesKeyboard(.interactively)
            .keyboardDoneButton()
            .navigationTitle("Edit contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { vm.update(); dismiss() }.disabled(!vm.canUpdate)
                }
            }
            .onAppear { vm.load() }
        }
    }
}
