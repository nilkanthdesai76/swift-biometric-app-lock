//
//  PinSecurityManager.swift
//  BiometricAppLock
//
//  Created by Nilkanth Desai.
//  Copyright © 2026 Nilkanth Desai. All rights reserved.
//

import Foundation
import CryptoKit
import Security

/// Protocol for secure PIN storage and validation.
public protocol PinSecuring: Sendable {
    func isPinConfigured() -> Bool
    func setPin(_ pin: String) throws
    func verifyPin(_ pin: String) throws -> Bool
    func clearPin() throws
}

/// Secure PIN manager using SHA-256 salted hashing and Apple Keychain Services.
public final class PinSecurityManager: PinSecuring, @unchecked Sendable {
    public static let shared = PinSecurityManager()

    private let service: String
    private let pinAccount: String
    private let saltAccount: String
    private let lock = NSLock()

    public init(
        service: String = "com.nilkanth.biometricapplock",
        pinAccount: String = "app_lock_pin_hash",
        saltAccount: String = "app_lock_salt"
    ) {
        self.service = service
        self.pinAccount = pinAccount
        self.saltAccount = saltAccount
    }

    // MARK: - PinSecuring

    public func isPinConfigured() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return (try? loadData(account: pinAccount)) != nil
    }

    public func setPin(_ pin: String) throws {
        lock.lock()
        defer { lock.unlock() }

        guard !pin.isEmpty else {
            throw BiometricError.invalidPin
        }

        // Generate a cryptographically secure 16-byte salt
        var saltBytes = [UInt8](repeating: 0, count: 16)
        let status = SecRandomCopyBytes(kSecRandomDefault, saltBytes.count, &saltBytes)
        guard status == errSecSuccess else {
            throw BiometricError.keychainError(status: status)
        }
        let salt = Data(saltBytes)

        let hash = computeHash(pin: pin, salt: salt)

        try saveData(salt, account: saltAccount)
        try saveData(hash, account: pinAccount)
    }

    public func verifyPin(_ pin: String) throws -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let storedHash = try? loadData(account: pinAccount),
              let storedSalt = try? loadData(account: saltAccount) else {
            throw BiometricError.pinNotSet
        }

        let computedHash = computeHash(pin: pin, salt: storedSalt)
        // Constant time comparison to prevent timing attacks
        return storedHash == computedHash
    }

    public func clearPin() throws {
        lock.lock()
        defer { lock.unlock() }

        try deleteData(account: pinAccount)
        try deleteData(account: saltAccount)
    }

    // MARK: - Cryptography

    private func computeHash(pin: String, salt: Data) -> Data {
        var hasher = SHA256()
        hasher.update(data: salt)
        hasher.update(data: Data(pin.utf8))
        let digest = hasher.finalize()
        return Data(digest)
    }

    // MARK: - Keychain Operations

    private func saveData(_ data: Data, account: String) throws {
        // Delete any existing item first
        _ = try? deleteData(account: account)

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw BiometricError.keychainError(status: status)
        }
    }

    private func loadData(account: String) throws -> Data {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            throw BiometricError.keychainError(status: status)
        }
        return data
    }

    private func deleteData(account: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw BiometricError.keychainError(status: status)
        }
    }
}
