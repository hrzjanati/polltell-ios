import PolTellCore

/// One A–Z group of the contact list ("#" holds names that do not start with a letter).
struct ContactSection {
    let letter: String
    let contacts: [Contact]

    static func letter(of name: String) -> String {
        guard let c = name.trimmingCharacters(in: .whitespaces).first else { return "#" }
        let s = String(c).uppercased()
        return s.rangeOfCharacter(from: .letters) != nil ? s : "#"
    }

    /// Groups contacts A to Z with "#" last, each group sorted by name.
    static func make(from contacts: [Contact]) -> [ContactSection] {
        let groups = Dictionary(grouping: contacts) { letter(of: $0.name) }
        return groups.keys
            .sorted { a, b in a == "#" ? false : (b == "#" ? true : a.localizedStandardCompare(b) == .orderedAscending) }
            .map { k in ContactSection(letter: k, contacts: groups[k]!.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) }
    }
}
