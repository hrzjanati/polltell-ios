import Perception
import SwiftUI
import PolTellCore

/// The form state behind New contact and Edit contact: what is typed, whether it can be saved, and the save.
@MainActor @Perceptible
final class ContactEditorViewModel {
    var name = ""
    var phone = ""            // New contact: the single number
    var type = "mobile"       // New contact: its kind
    var email = ""            // New contact: the single address
    var phones: [EditablePhone] = []   // Edit contact
    var emails: [EditableEmail] = []

    let kinds = ["mobile", "home", "work", "main", "other"]
    @PerceptionIgnored private let model: AppModel
    @PerceptionIgnored private let existing: Contact?

    init(contact: Contact? = nil, model: AppModel? = nil) {
        existing = contact
        self.model = model ?? .shared
    }

    var isConnected: Bool { model.linkState.isConnected }
    var avatarName: String { name.isEmpty ? (existing?.name ?? "") : name }
    var avatarPhoto: String? { existing?.photo }

    var canAdd: Bool { !name.isEmpty && !(phone.isEmpty && email.isEmpty) }
    var canUpdate: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && isConnected }

    func add() {
        model.addContact(name: name, phones: phone.isEmpty ? [] : [Phone(n: phone, type: type)],
                         emails: email.isEmpty ? [] : [email])
    }

    func load() {
        guard let c = existing else { return }
        name = c.name
        phones = c.phones.map { p in
            let label = p.label.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 }
            return EditablePhone(number: p.n, type: label != nil ? EditablePhone.custom : (kinds.contains(p.type) ? p.type : "other"), label: label)
        }
        emails = c.emails.map { EditableEmail(address: $0) }
    }

    func update() {
        guard let c = existing else { return }
        let ps = phones.map(\.asPhone).filter { !$0.n.isEmpty }
        let es = emails.map { $0.address.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        model.updateContact(id: c.id, name: name.trimmingCharacters(in: .whitespaces), phones: ps, emails: es)
    }

    func addPhoneRow() { phones.append(EditablePhone(number: "", type: "mobile")) }
    func addEmailRow() { emails.append(EditableEmail(address: "")) }
}
