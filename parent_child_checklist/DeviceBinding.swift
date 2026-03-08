//
//  DeviceBinding.swift
//  parent_child_checklist
//
//  Created by George Gauci on 8/3/2026.
//


//
//  DeviceBindingStore.swift
//  parent_child_checklist
//
//  Stores the device→child binding (who this device belongs to) in the Keychain.
//  Used by the child pairing flow so a child only pairs once per device.
//

import Foundation
import Security

/// A small, serializable record describing the current device binding.
struct DeviceBinding: Codable, Equatable {
    /// The child this device is bound to.
    let childId: UUID
    /// Optional epoch/version used to invalidate old pairings when the parent resets.
    let epoch: Int
    /// When the binding was created on this device.
    let boundAt: Date
}

/// Keychain-backed store for the device’s bound child.
final class DeviceBindingStore {

    static let shared = DeviceBindingStore()

    // Service/account identifiers for Keychain item
    // (Choose a unique reverse-DNS string for your app.)
    private let service = "com.parent-child-checklist.binding"
    private let account = "boundChild.v1"

    private init() { }

    // MARK: - Public API

    /// Returns the current binding if present.
    func current() -> DeviceBinding? {
        guard let data = try? keychainLoad() else { return nil }
        return try? JSONDecoder().decode(DeviceBinding.self, from: data)
    }

    /// Returns true if the device is bound to the given child (and, if provided, epoch matches).
    func isBound(to childId: UUID, epoch: Int? = nil) -> Bool {
        guard let binding = current(), binding.childId == childId else { return false }
        if let epoch { return binding.epoch == epoch }
        return true
    }

    /// Binds this device to a child. Overwrites any existing binding.
    func bind(to childId: UUID, epoch: Int = 0, at date: Date = Date()) throws {
        let payload = DeviceBinding(childId: childId, epoch: epoch, boundAt: date)
        let data = try JSONEncoder().encode(payload)
        if try keychainExists() {
            try keychainUpdate(data: data)
        } else {
            try keychainSave(data: data)
        }
    }

    /// Clears the binding (the device becomes unpaired).
    func unbind() throws {
        try keychainDelete()
    }

    // MARK: - Keychain helpers

    private func keychainQueryBase() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            // Accessible after first unlock is a practical balance for this use case.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
    }

    private func keychainExists() throws -> Bool {
        var query = keychainQueryBase()
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = false
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        switch status {
        case errSecSuccess: return true
        case errSecItemNotFound: return false
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func keychainLoad() throws -> Data {
        var query = keychainQueryBase()
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { throw KeychainError.unexpectedData }
            return data
        case errSecItemNotFound:
            throw KeychainError.notFound
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func keychainSave(data: Data) throws {
        var query = keychainQueryBase()
        query[kSecValueData as String] = data
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    private func keychainUpdate(data: Data) throws {
        let query = keychainQueryBase()
        let attrs: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    private func keychainDelete() throws {
        let query = keychainQueryBase()
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: - Errors

    enum KeychainError: Error, LocalizedError {
        case notFound
        case unexpectedData
        case unexpectedStatus(OSStatus)

        var errorDescription: String? {
            switch self {
            case .notFound: return "Binding not found."
            case .unexpectedData: return "Unexpected data returned from Keychain."
            case .unexpectedStatus(let status): return "Keychain error: \(status)"
            }
        }
    }
}
