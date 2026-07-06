import Foundation
import Security

final class KeychainManager: @unchecked Sendable {
    static let shared = KeychainManager()
    private let service = "com.cliptranslator.api-keys"

    private init() {}

    func getAPIKey(for provider: TranslationProvider) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8)
        else {
            if status == errSecItemNotFound {
                throw TranslationError.noAPIKey
            }
            throw TranslationError.keychainError("Failed to retrieve API key (OSStatus \(status))")
        }

        return key
    }

    func setAPIKey(_ key: String, for provider: TranslationProvider) throws {
        // Delete existing entry first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
            kSecValueData as String: key.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw TranslationError.keychainError("Failed to store API key (OSStatus \(status))")
        }
    }

    // MARK: - In-Memory Cache

    private var cachedKeys: [TranslationProvider: String] = [:]

    func getCachedAPIKey(for provider: TranslationProvider) throws -> String {
        if let cached = cachedKeys[provider] {
            return cached
        }
        let key = try getAPIKey(for: provider)
        cachedKeys[provider] = key
        return key
    }

    func invalidateCache(for provider: TranslationProvider) {
        cachedKeys[provider] = nil
    }
}
