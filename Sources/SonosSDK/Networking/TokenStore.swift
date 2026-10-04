//
//  TokenStore.swift
//  SonosSDK
//
//  Created on 2026-10-04.
//

import Foundation
import Security

/// Persists the OAuth token between launches.
///
/// `TokenManager` hands over the token already encoded, so an implementation only has to keep the bytes.
public protocol TokenStoring: Sendable {
    /// The stored token data, or `nil` if nothing is stored
    func loadTokenData() throws -> Data?

    /// Replace the stored token data
    func saveTokenData(_ data: Data) throws

    /// Remove the stored token data; succeeds if nothing is stored
    func deleteTokenData() throws
}

/// Keeps the token in a generic password item in the Keychain.
///
/// The item becomes readable once the device has been unlocked after boot, so background refreshes keep
/// working on iOS, and it never leaves the device: it is not synced to iCloud Keychain or restored onto
/// another device. On macOS the item lives in the user's login keychain, which needs no keychain entitlement,
/// ignores the accessibility class and never syncs.
public struct KeychainTokenStore: TokenStoring {

    /// A Keychain call failed with `status`
    public struct KeychainError: Error, Equatable, CustomStringConvertible {
        public let status: OSStatus

        public var description: String {
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error"
            return "Keychain error \(status): \(message)"
        }
    }

    public let service: String
    public let account: String

    public init(service: String = "com.sonossdk.token", account: String = "oauth") {
        self.service = service
        self.account = account
    }

    public func loadTokenData() throws -> Data? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError(status: status)
        }
    }

    public func saveTokenData(_ data: Data) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        var status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(baseQuery.merging(attributes) { $1 } as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw KeychainError(status: status)
        }
    }

    public func deleteTokenData() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

/// Keeps the token in memory only, for tests and previews
public final class InMemoryTokenStore: TokenStoring, @unchecked Sendable {

    private let lock = NSLock()
    private var tokenData: Data?

    public init(tokenData: Data? = nil) {
        self.tokenData = tokenData
    }

    public func loadTokenData() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return tokenData
    }

    public func saveTokenData(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        tokenData = data
    }

    public func deleteTokenData() {
        lock.lock()
        defer { lock.unlock() }
        tokenData = nil
    }
}
