//
//  BiometricTypes.swift
//  BiometricAppLock
//
//  Created by Nilkanth Desai.
//  Copyright © 2026 Nilkanth Desai. All rights reserved.
//

import Foundation

/// Supported hardware biometric authentication modalities.
public enum BiometricType: String, Sendable, CaseIterable {
    case none
    case touchID
    case faceID
    case opticID

    public var displayName: String {
        switch self {
        case .none:
            return "Passcode"
        case .touchID:
            return "Touch ID"
        case .faceID:
            return "Face ID"
        case .opticID:
            return "Optic ID"
        }
    }

    public var systemImageName: String {
        switch self {
        case .none:
            return "lock.fill"
        case .touchID:
            return "touchid"
        case .faceID:
            return "faceid"
        case .opticID:
            return "opticid"
        }
    }
}

/// Authentication policy methods supported by the lock engine.
public enum AuthMethod: Sendable, Equatable {
    /// Authenticate solely using biometric hardware.
    case biometricOnly
    /// Authenticate using a custom app-level PIN.
    case pinOnly(length: Int)
    /// Primary biometric auth with instant custom PIN fallback.
    case biometricWithPinFallback(pinLength: Int)
    /// Delegate directly to system device passcode / biometrics via OS.
    case systemPasscode
}

/// Errors thrown or returned during authentication workflows.
public enum BiometricError: Error, LocalizedError, Sendable, Equatable {
    case biometricsNotAvailable
    case biometricsNotEnrolled
    case userCanceled
    case systemCanceled
    case authenticationFailed
    case biometryLockedOut
    case invalidPin
    case pinMismatch
    case pinNotSet
    case temporaryLockout(secondsRemaining: TimeInterval)
    case keychainError(status: Int32)
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .biometricsNotAvailable:
            return "Biometric authentication is not supported or unavailable on this device."
        case .biometricsNotEnrolled:
            return "No biometric identities (Face ID / Touch ID) are enrolled on this device."
        case .userCanceled:
            return "Authentication was canceled by the user."
        case .systemCanceled:
            return "Authentication was canceled by the system."
        case .authenticationFailed:
            return "Biometric verification failed."
        case .biometryLockedOut:
            return "Biometrics are temporarily locked out due to multiple failed attempts."
        case .invalidPin:
            return "The entered PIN is incorrect."
        case .pinMismatch:
            return "The PINs do not match."
        case .pinNotSet:
            return "No custom PIN has been configured."
        case .temporaryLockout(let seconds):
            return "Too many failed attempts. Please wait \(Int(seconds)) seconds."
        case .keychainError(let status):
            return "Secure Keychain operation failed with OSStatus \(status)."
        case .unknown(let message):
            return message
        }
    }
}

/// Comprehensive configuration controlling the lock overlay presentation and security timeouts.
public struct LockConfiguration: Sendable {
    /// Authentication strategy.
    public var authMethod: AuthMethod
    /// Prompt title displayed to the user when biometrics are invoked.
    public var promptReason: String
    /// Subtitle / hint displayed below the title in the PIN pad.
    public var subtitle: String?
    /// Grace period (in seconds) before the app re-locks after being placed in background.
    /// Default is `0` (instant lock).
    public var autoLockGracePeriod: TimeInterval
    /// When true, renders an opaque privacy veil over the app while backgrounded to obscure snapshot thumbnails in the App Switcher.
    public var obscureOnBackground: Bool
    /// Maximum consecutive incorrect PIN entries before a temporary lockout is enforced.
    public var maxFailedAttempts: Int
    /// Duration of penalty cooldown lockout when maximum failed attempts are exceeded.
    public var lockoutCooldown: TimeInterval
    /// Optional action triggered when user taps "Forgot PIN?".
    public var forgotPinAction: (@Sendable () -> Void)?

    public init(
        authMethod: AuthMethod = .biometricWithPinFallback(pinLength: 4),
        promptReason: String = "Unlock to access your secure data",
        subtitle: String? = nil,
        autoLockGracePeriod: TimeInterval = 0,
        obscureOnBackground: Bool = true,
        maxFailedAttempts: Int = 5,
        lockoutCooldown: TimeInterval = 30,
        forgotPinAction: (@Sendable () -> Void)? = nil
    ) {
        self.authMethod = authMethod
        self.promptReason = promptReason
        self.subtitle = subtitle
        self.autoLockGracePeriod = autoLockGracePeriod
        self.obscureOnBackground = obscureOnBackground
        self.maxFailedAttempts = maxFailedAttempts
        self.lockoutCooldown = lockoutCooldown
        self.forgotPinAction = forgotPinAction
    }
}
