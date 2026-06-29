import Foundation
import Security
import StoreKit

enum KeychainStore {
    static let service = "com.badrimgu.lk"

    static func set(_ value: String, key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        var attrs = query
        attrs[kSecValueData as String] = data
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attrs as CFDictionary, nil)
    }

    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func remove(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func clearAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum AppStoreRegion {
    /// Happ ships as two separate App Store apps — a Russia-only listing and a
    /// Global one (different bundle IDs). We hand out the right download link
    /// by the user's real App Store storefront, not the phone's language.
    /// Read it at the moment of use — the storefront can change if the user
    /// switches their Apple ID country.
    static func isRussia() async -> Bool {
        if let cc = await Storefront.current?.countryCode {
            return cc.uppercased() == "RUS"   // ISO 3166-1 alpha-3
        }
        return Locale.current.region?.identifier.uppercased() == "RU"
    }
}
