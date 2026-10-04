//
//  BiometricAuthManager.swift
//  BiometricAppLock
//
//  Created by Nilkanth Desai.
//  Copyright © 2026 Nilkanth Desai. All rights reserved.
//

import Foundation
import LocalAuthentication

/// Protocol defining biometric hardware interaction for testing and dependency injection.
public protocol BiometricAuthenticating: Sendable {
    func supportedBiometricType() -> BiometricType
    func canEvaluateBiometrics() -> Bool
    func authenticate(reason: String, allowPasscodeFallback: Bool) async throws -> Bool
}

/// Concrete actor managing Apple LocalAuthentication interactions.
public final class BiometricAuthManager: BiometricAuthenticating, @unchecked Sendable {
    public static let shared = BiometricAuthManager()

    public init() {}

    /// Inspects the device hardware and enrolled state to determine the active biometric modality.
    public func supportedBiometricType() -> BiometricType {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        switch context.biometryType {
        case .touchID:
            return .touchID
        case .faceID:
            return .faceID
        case .none:
            return .none
        case .opticID:
            return .opticID
        @unknown default:
            return .none
        }
    }

    /// Checks whether biometrics can currently be evaluated without error.
    public func canEvaluateBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Requests biometric verification asynchronously.
    /// - Parameters:
    ///   - reason: Localized prompt explaining the request.
    ///   - allowPasscodeFallback: When true, allows fallback to device passcode on failure.
    public func authenticate(reason: String, allowPasscodeFallback: Bool = false) async throws -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = allowPasscodeFallback ? nil : ""

        let policy: LAPolicy = allowPasscodeFallback
            ? .deviceOwnerAuthentication
            : .deviceOwnerAuthenticationWithBiometrics

        var error: NSError?
        guard context.canEvaluatePolicy(policy, error: &error) else {
            if let err = error {
                throw mapLAError(err)
            }
            throw BiometricError.biometricsNotAvailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(policy, localizedReason: reason) { success, evalError in
                if success {
                    continuation.resume(returning: true)
                } else if let evalError = evalError as? NSError {
                    continuation.resume(throwing: self.mapLAError(evalError))
                } else {
                    continuation.resume(throwing: BiometricError.authenticationFailed)
                }
            }
        }
    }

    // MARK: - Error Mapping

    private func mapLAError(_ error: NSError) -> BiometricError {
        guard error.domain == LAErrorDomain else {
            return .unknown(error.localizedDescription)
        }

        guard let laCode = LAError.Code(rawValue: error.code) else {
            return .unknown(error.localizedDescription)
        }

        switch laCode {
        case .authenticationFailed:
            return .authenticationFailed
        case .userCancel:
            return .userCanceled
        case .userFallback:
            return .userCanceled
        case .systemCancel:
            return .systemCanceled
        case .passcodeNotSet:
            return .biometricsNotEnrolled
        case .biometryNotAvailable, .touchIDNotAvailable:
            return .biometricsNotAvailable
        case .biometryNotEnrolled, .touchIDNotEnrolled:
            return .biometricsNotEnrolled
        case .biometryLockout, .touchIDLockout:
            return .biometryLockedOut
        default:
            return .unknown(error.localizedDescription)
        }
    }
}
