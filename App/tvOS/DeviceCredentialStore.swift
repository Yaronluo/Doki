import Foundation
import Security

enum DeviceCredentialStore {
    private static let service = "com.doki.hub.device"
    static func token(for hub: URL) -> String? {
        var query = base(hub)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func save(_ token: String, for hub: URL) throws {
        let query = base(hub)
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = Data(token.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw URLError(.userAuthenticationRequired) }
    }
    static func clear(for hub: URL) { SecItemDelete(base(hub) as CFDictionary) }
    private static func base(_ hub: URL) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: hub.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))]
    }
}
