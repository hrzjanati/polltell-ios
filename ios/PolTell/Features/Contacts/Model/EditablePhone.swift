import Foundation
import PolTellCore

/// A phone row in the contact editor. `label`: the number's custom kind from the Android phone ("Satellite");
/// kept unless another kind is picked.
struct EditablePhone: Identifiable {
    let id = UUID()
    var number: String
    var type: String
    var label: String? = nil

    /// Picker tag for "keep the custom kind" (never sent: it goes out as type "other" with the label).
    static let custom = "custom"

    /// What the Android phone stores: a kept custom kind is sent with its label; picking a standard kind for a
    /// custom one sends an empty label (clears it); otherwise no label (protocol §5 contact.update).
    var asPhone: Phone {
        let n = number.trimmingCharacters(in: .whitespaces)
        if type == Self.custom, let label { return Phone(n: n, type: "other", label: label) }
        return Phone(n: n, type: type, label: label != nil ? "" : nil)
    }
}

/// An e-mail row in the contact editor.
struct EditableEmail: Identifiable {
    let id = UUID()
    var address: String
}
