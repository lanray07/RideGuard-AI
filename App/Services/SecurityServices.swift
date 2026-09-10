import Foundation
import Security
import LocalAuthentication

enum SecureStoreError: Error { case status(OSStatus), invalidData }

/// Only tokens belong here. Precise ride coordinates must not be stored in defaults or logs.
struct KeychainStore {
    private let service = "com.rideguard.credentials"
    func save(_ data: Data, account: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service, kSecAttrAccount as String: account]
        let attributes: [String: Any] = [kSecValueData as String: data,
                                        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound { status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil) }
        guard status == errSecSuccess else { throw SecureStoreError.status(status) }
    }
    func read(account: String) throws -> Data? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service, kSecAttrAccount as String: account,
                                    kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw SecureStoreError.status(status) }
        guard let data = result as? Data else { throw SecureStoreError.invalidData }
        return data
    }
    func delete(account: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service, kSecAttrAccount as String: account]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw SecureStoreError.status(status) }
    }
}

@MainActor
enum PrivacyUnlock {
    static func authenticate() async throws {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw error ?? NSError(domain: "RideGuard", code: 1, userInfo: [NSLocalizedDescriptionKey: "Set a device passcode to export sensitive ride data."])
        }
        let approved = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Export your RideGuard history and saved locations.")
        guard approved else { throw CancellationError() }
    }
}
