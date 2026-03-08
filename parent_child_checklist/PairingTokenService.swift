//
//
//  PairingTokenService.swift
//  parent_child_checklist
//
//  QR token encoding/signing/verification used by parent (to show QR)
//  and child (to verify & bind the device).
//
//  DEV implementation: symmetric HMAC-SHA256 with an in-app secret.
//  PRODUCTION: replace with asymmetric signing or server/CloudKit-delivered secret.
//
//  Token format (headerless JWS-like):
//    base64url(JSON payload) + "." + base64url(HMAC256 signature)
//
//  JSON payload = PairingToken (see Models.swift):
//    {
//      "childId": UUID-string,
//      "issuedAt": ISO8601,
//      "expiresAt": ISO8601,
//      "nonce": base64-16/32 bytes,
//      "pairingEpoch": Int,
//      "familyId": UUID-string?,
//      "appVersion": String?
//    }
//

import Foundation
import CryptoKit

// MARK: - Errors

enum PairingTokenError: Error, LocalizedError {
    case malformedToken
    case badEncoding
    case badSignature
    case expired
    case clockSkewTooLarge
    case payloadDecodeFailed
    case unexpectedChildId
    case unexpectedEpoch
    case unexpectedFamilyId

    var errorDescription: String? {
        switch self {
        case .malformedToken: return "Malformed token."
        case .badEncoding: return "The token was not correctly base64url-encoded."
        case .badSignature: return "Signature verification failed."
        case .expired: return "The token has expired."
        case .clockSkewTooLarge: return "The token's timing is outside the allowed skew."
        case .payloadDecodeFailed: return "Could not decode the token payload."
        case .unexpectedChildId: return "Token childId does not match the requested child."
        case .unexpectedEpoch: return "Token epoch does not match the current pairing epoch."
        case .unexpectedFamilyId: return "Token family scope does not match."
        }
    }
}

// MARK: - Service

final class PairingTokenService {

    // MARK: Configuration

    struct Config {
        /// Allowed positive/negative clock skew when comparing `issuedAt` / `expiresAt` (seconds).
        var allowedClockSkew: TimeInterval = 90
        /// Default validity for newly created tokens (seconds).
        var defaultValidity: TimeInterval = 10 * 60 // 10 minutes
        /// Optional family scoping; include a familyId if you want to gate tokens to a single family.
        var familyId: UUID? = nil

        // DEV ONLY: HMAC secret for signing. Replace in production.
        /// IMPORTANT: Do NOT ship a real secret like this to the App Store.
        /// Move to server-/CloudKit-managed key, or switch to asymmetric signatures
        /// with a public key embedded in the app and private key stored securely.
        var devHMACSecret: Data = Data("DEV_SECRET_CHANGE_ME_ROTATE_ME".utf8)
    }

    private let config: Config

    init(config: Config = Config()) {
        self.config = config
    }

    // MARK: - Public API

    /// Parent side: make a signed token string to render as a QR code.
    /// - Parameters:
    ///   - childId: The child being paired.
    ///   - pairingEpoch: The current epoch from ChildProfile (used to invalidate old tokens).
    ///   - validFor: How long the token is valid.
    ///   - appVersion: Optional app version string to include (useful for support).
    /// - Returns: A compact token string "b64url(payload).b64url(signature)"
    func makeSignedToken(
        for childId: UUID,
        pairingEpoch: Int,
        validFor: TimeInterval? = nil,
        appVersion: String? = PairingTokenService.readAppVersion()
    ) throws -> String {

        let now = Date()
        let validity = validFor ?? config.defaultValidity
        let payload = PairingToken(
            childId: childId,
            issuedAt: now,
            expiresAt: now.addingTimeInterval(validity),
            nonce: PairingTokenService.generateNonceBase64(count: 24),
            pairingEpoch: pairingEpoch,
            familyId: config.familyId,
            appVersion: appVersion
        )

        let payloadData = try JSONEncoder.iso8601.encode(payload)
        let payloadB64 = Base64URL.encode(payloadData)

        let signature = try sign(payload: payloadData)
        let sigB64 = Base64URL.encode(signature)

        return payloadB64 + "." + sigB64
    }

    /// Child side: verify signature + timing and decode the token.
    /// Throws if signature is invalid or token is outside allowed time window.
    func verifyAndDecode(_ token: String) throws -> PairingToken {
        let components = token.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 2 else { throw PairingTokenError.malformedToken }

        let payloadB64 = String(components[0])
        let sigB64 = String(components[1])

        guard let payloadData = Base64URL.decode(payloadB64),
              let sigData = Base64URL.decode(sigB64) else {
            throw PairingTokenError.badEncoding
        }

        // 1) Signature check
        let ok = try verifySignature(payload: payloadData, signature: sigData)
        guard ok else { throw PairingTokenError.badSignature }

        // 2) Decode JSON
        guard let tokenObj = try? JSONDecoder.iso8601.decode(PairingToken.self, from: payloadData) else {
            throw PairingTokenError.payloadDecodeFailed
        }

        // 3) Timing checks with skew
        try validateTiming(of: tokenObj)

        // 4) Optional family scope check
        if let expected = config.familyId, let provided = tokenObj.familyId, expected != provided {
            throw PairingTokenError.unexpectedFamilyId
        }

        return tokenObj
    }

    /// High-level helper used by the child flow to fully validate a token
    /// against the tapped child AND the current epoch fetched from CloudKit.
    /// - Parameters:
    ///   - tokenString: The raw token string (from QR scan / pasted / imported).
    ///   - expectedChildId: The child the user tapped in "Who are you?".
    ///   - expectedEpoch: The current pairingEpoch from ChildProfile (CloudKit).
    /// - Returns: Decoded PairingToken if everything matches.
    func verifyAll(
        tokenString: String,
        expectedChildId: UUID,
        expectedEpoch: Int
    ) throws -> PairingToken {
        let tok = try verifyAndDecode(tokenString)
        guard tok.childId == expectedChildId else { throw PairingTokenError.unexpectedChildId }
        guard tok.pairingEpoch == expectedEpoch else { throw PairingTokenError.unexpectedEpoch }
        return tok
    }

    // MARK: - Private helpers: sign/verify/timing

    private func sign(payload: Data) throws -> Data {
        let key = SymmetricKey(data: config.devHMACSecret)
        let mac = HMAC<SHA256>.authenticationCode(for: payload, using: key)
        return Data(mac)
    }

    private func verifySignature(payload: Data, signature: Data) throws -> Bool {
        let key = SymmetricKey(data: config.devHMACSecret)
        let expected = HMAC<SHA256>.authenticationCode(for: payload, using: key)
        return Data(expected) == signature
    }

    private func validateTiming(of token: PairingToken) throws {
        let now = Date()
        let skew = config.allowedClockSkew

        // issuedAt must not be too far in the future
        if token.issuedAt.timeIntervalSince(now) > skew {
            throw PairingTokenError.clockSkewTooLarge
        }
        // expiresAt must be >= now - skew
        if now.timeIntervalSince(token.expiresAt) > skew {
            throw PairingTokenError.expired
        }
    }

    // MARK: - Utilities

    static func generateNonceBase64(count: Int = 24) -> String {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        if status != errSecSuccess {
            // Fallback: UUID-based
            return Data(UUID().uuidString.utf8).base64EncodedString()
        }
        return Data(bytes).base64EncodedString()
    }

    static func readAppVersion() -> String? {
        if let dict = Bundle.main.infoDictionary {
            let ver = dict["CFBundleShortVersionString"] as? String
            let build = dict["CFBundleVersion"] as? String
            if let ver, let build { return "\(ver) (\(build))" }
            if let ver { return ver }
            if let build { return build }
        }
        return nil
    }
}

// MARK: - Base64URL helpers (no padding, URL-safe)

enum Base64URL {
    static func encode(_ data: Data) -> String {
        var s = data.base64EncodedString()
        s = s.replacingOccurrences(of: "+", with: "-")
             .replacingOccurrences(of: "/", with: "_")
             .replacingOccurrences(of: "=", with: "")
        return s
    }

    static func decode(_ string: String) -> Data? {
        var s = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Pad to multiple of 4
        let pad = s.count % 4
        if pad != 0 { s.append(String(repeating: "=", count: 4 - pad)) }

        return Data(base64Encoded: s)
    }
}

// MARK: - JSONCoders with ISO8601 dates

extension JSONEncoder {
    static var iso8601: JSONEncoder {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        return enc
    }
}

extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }
}
