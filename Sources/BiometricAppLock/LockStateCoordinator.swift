//
//  LockStateCoordinator.swift
//  BiometricAppLock
//
//  Created by Nilkanth Desai.
//  Copyright © 2026 Nilkanth Desai. All rights reserved.
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Observable coordinator managing the lifecycle, lock state, privacy veil, and cooldowns.
@MainActor
public final class LockStateCoordinator: ObservableObject {
    @Published public private(set) var isLocked: Bool = true
    @Published public private(set) var isPrivacyVeilVisible: Bool = false
    @Published public private(set) var failedAttempts: Int = 0
    @Published public private(set) var lockoutUntil: Date? = nil
    @Published public private(set) var biometricType: BiometricType = .none
    @Published public var enteredPin: String = ""
    @Published public var shakeTrigger: Bool = false
    @Published public var errorMessage: String? = nil

    public let configuration: LockConfiguration
    private let biometricManager: BiometricAuthenticating
    private let pinManager: PinSecuring
    private var lastBackgroundDate: Date?
    private var cancellables = Set<AnyCancellable>()

    public init(
        configuration: LockConfiguration = LockConfiguration(),
        biometricManager: BiometricAuthenticating = BiometricAuthManager.shared,
        pinManager: PinSecuring = PinSecurityManager.shared,
        initiallyLocked: Bool = true
    ) {
        self.configuration = configuration
        self.biometricManager = biometricManager
        self.pinManager = pinManager
        self.isLocked = initiallyLocked
        self.biometricType = biometricManager.supportedBiometricType()

        setupLifecycleObservers()
    }

    // MARK: - Authentication Actions

    /// Triggers biometric authentication if supported and not locked out.
    public func triggerBiometricAuthentication() async {
        guard !isLockedOut() else {
            errorMessage = BiometricError.temporaryLockout(secondsRemaining: remainingLockoutSeconds()).localizedDescription
            return
        }

        guard biometricType != .none else {
            return
        }

        do {
            let success = try await biometricManager.authenticate(
                reason: configuration.promptReason,
                allowPasscodeFallback: configuration.authMethod == .systemPasscode
            )
            if success {
                unlock()
            }
        } catch let error as BiometricError {
            if error != .userCanceled {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Evaluates entered PIN against the configured PIN in Keychain.
    public func submitPin() {
        guard !isLockedOut() else {
            errorMessage = BiometricError.temporaryLockout(secondsRemaining: remainingLockoutSeconds()).localizedDescription
            enteredPin = ""
            return
        }

        do {
            let isValid = try pinManager.verifyPin(enteredPin)
            if isValid {
                unlock()
            } else {
                handleFailedAttempt()
            }
        } catch {
            handleFailedAttempt(error: error.localizedDescription)
        }
    }

    /// Appends a digit to the PIN buffer and validates if target length reached.
    public func appendPinDigit(_ digit: String, targetLength: Int) {
        guard !isLockedOut() else { return }
        guard enteredPin.count < targetLength else { return }

        enteredPin.append(digit)
        if enteredPin.count == targetLength {
            submitPin()
        }
    }

    /// Deletes the trailing digit from the PIN buffer.
    public func deletePinDigit() {
        if !enteredPin.isEmpty {
            enteredPin.removeLast()
        }
    }

    // MARK: - State Transitions

    public func unlock() {
        isLocked = false
        isPrivacyVeilVisible = false
        failedAttempts = 0
        lockoutUntil = nil
        enteredPin = ""
        errorMessage = nil
    }

    public func lock() {
        isLocked = true
        enteredPin = ""
        errorMessage = nil
    }

    private func handleFailedAttempt(error: String? = nil) {
        failedAttempts += 1
        enteredPin = ""
        shakeTrigger.toggle()
        errorMessage = error ?? "Incorrect PIN. Try again."

        if failedAttempts >= configuration.maxFailedAttempts {
            lockoutUntil = Date().addingTimeInterval(configuration.lockoutCooldown)
            errorMessage = "Too many attempts. Cooldown for \(Int(configuration.lockoutCooldown))s."
        }
    }

    public func isLockedOut() -> Bool {
        guard let until = lockoutUntil else { return false }
        if Date() >= until {
            lockoutUntil = nil
            failedAttempts = 0
            errorMessage = nil
            return false
        }
        return true
    }

    public func remainingLockoutSeconds() -> TimeInterval {
        guard let until = lockoutUntil else { return 0 }
        return max(0, until.timeIntervalSinceNow)
    }

    // MARK: - Lifecycle Management

    private func setupLifecycleObservers() {
        #if canImport(UIKit)
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.configuration.obscureOnBackground {
                    self.isPrivacyVeilVisible = true
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.lastBackgroundDate = Date()
                if self.configuration.autoLockGracePeriod == 0 {
                    self.lock()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.evaluateGracePeriod()
                self.isPrivacyVeilVisible = false
            }
            .store(in: &cancellables)
        #elseif canImport(AppKit)
        NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.lastBackgroundDate = Date()
                if self.configuration.obscureOnBackground {
                    self.isPrivacyVeilVisible = true
                }
                if self.configuration.autoLockGracePeriod == 0 {
                    self.lock()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.evaluateGracePeriod()
                self.isPrivacyVeilVisible = false
            }
            .store(in: &cancellables)
        #endif
    }

    private func evaluateGracePeriod() {
        guard let backgroundDate = lastBackgroundDate else { return }
        lastBackgroundDate = nil

        let elapsed = Date().timeIntervalSince(backgroundDate)
        if elapsed >= configuration.autoLockGracePeriod {
            lock()
        }
    }
}
