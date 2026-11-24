import CryptoKit
import Foundation
import Security
import PolTellCore

/// Throwaway identity for demo mode: never paired, nothing stored.
final class MemoryIdentityStore: IdentityStore {
    private let key = P256.KeyAgreement.PrivateKey()
    func staticKey() -> P256.KeyAgreement.PrivateKey { key }
    var peerKey: Data?
    var peerName: String?
    var peripheralID: UUID?
}

/// Link identity in the Keychain (available after first unlock, so BLE background wake works while locked).
final class KeychainIdentityStore: IdentityStore {
    private let service = "app.tether.identity"

    private func read(_ account: String) -> Data? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: account, kSecReturnData as String: true,
                                kSecMatchLimit as String: kSecMatchLimitOne]
        var out: CFTypeRef?
        return SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess ? out as? Data : nil
    }

    private func write(_ account: String, _ data: Data?) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: account]
        SecItemDelete(q as CFDictionary)
        guard let data else { return }
        var add = q
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    func staticKey() -> P256.KeyAgreement.PrivateKey {
        if let d = read("static"), let k = try? P256.KeyAgreement.PrivateKey(rawRepresentation: d) { return k }
        let k = P256.KeyAgreement.PrivateKey()
        write("static", k.rawRepresentation)
        return k
    }

    var peerKey: Data? {
        get { read("peer") }
        set { write("peer", newValue) }
    }

    var peerName: String? {
        get { read("peerName").flatMap { String(data: $0, encoding: .utf8) } }
        set { write("peerName", newValue.map { Data($0.utf8) }) }
    }

    var peripheralID: UUID? {
        get { read("peripheral").flatMap { String(data: $0, encoding: .utf8) }.flatMap(UUID.init) }
        set { write("peripheral", newValue.map { Data($0.uuidString.utf8) }) }
    }
}
