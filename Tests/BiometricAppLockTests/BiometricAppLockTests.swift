//
//  BiometricAppLockTests.swift
//  BiometricAppLockTests
//
//  Created by Nilkanth Desai.
//  Copyright © 2026 Nilkanth Desai. All rights reserved.
//

import XCTest
@testable import BiometricAppLock

final class MockBiometricManager: BiometricAuthenticating, @unchecked Sendable {
    var mockedType: BiometricType = .faceID
    var canEvaluate: Bool = true
    var shouldSucceed: Bool = true
    var errorToThrow: BiometricError? = nil

    func supportedBiometricType() -> BiometricType {
        return mockedType
    }

    func canEvaluateBiometrics() -> Bool {
        return canEvaluate
    }

    func authenticate(reason: String, allowPasscodeFallback: Bool) async throws -> Bool {
        if let error = errorToThrow {
            throw error
        }
        return shouldSucceed
    }
}

final class MockPinManager: PinSecuring, @unchecked Sendable {
    var storedPin: String? = "1234"

    func isPinConfigured() -> Bool {
        return storedPin != nil
    }

    func setPin(_ pin: String) throws {
        storedPin = pin
    }

    func verifyPin(_ pin: String) throws -> Bool {
        guard let stored = storedPin else {
            throw BiometricError.pinNotSet
        }
        return stored == pin
    }

    func clearPin() throws {
        storedPin = nil
    }
}

@MainActor
final class BiometricAppLockTests: XCTestCase {

    func testBiometricTypeProperties() {
        XCTAssertEqual(BiometricType.none.displayName, "Passcode")
        XCTAssertEqual(BiometricType.touchID.displayName, "Touch ID")
        XCTAssertEqual(BiometricType.faceID.displayName, "Face ID")
        XCTAssertEqual(BiometricType.opticID.displayName, "Optic ID")

        XCTAssertEqual(BiometricType.none.systemImageName, "lock.fill")
        XCTAssertEqual(BiometricType.touchID.systemImageName, "touchid")
        XCTAssertEqual(BiometricType.faceID.systemImageName, "faceid")
        XCTAssertEqual(BiometricType.opticID.systemImageName, "opticid")
    }

    func testLockConfigurationDefaults() {
        let config = LockConfiguration()
        XCTAssertEqual(config.autoLockGracePeriod, 0)
        XCTAssertTrue(config.obscureOnBackground)
        XCTAssertEqual(config.maxFailedAttempts, 5)
        XCTAssertEqual(config.lockoutCooldown, 30)
    }

    func testPinEntryAndUnlock() {
        let mockPin = MockPinManager()
        mockPin.storedPin = "5678"
        let mockBio = MockBiometricManager()
        let config = LockConfiguration(authMethod: .pinOnly(length: 4))

        let coordinator = LockStateCoordinator(
            configuration: config,
            biometricManager: mockBio,
            pinManager: mockPin,
            initiallyLocked: true
        )

        XCTAssertTrue(coordinator.isLocked)
        XCTAssertEqual(coordinator.enteredPin, "")

        coordinator.appendPinDigit("5", targetLength: 4)
        coordinator.appendPinDigit("6", targetLength: 4)
        XCTAssertEqual(coordinator.enteredPin, "56")

        coordinator.deletePinDigit()
        XCTAssertEqual(coordinator.enteredPin, "5")

        coordinator.appendPinDigit("6", targetLength: 4)
        coordinator.appendPinDigit("7", targetLength: 4)
        coordinator.appendPinDigit("8", targetLength: 4)

        // After 4 digits, submitPin is triggered automatically
        XCTAssertFalse(coordinator.isLocked)
        XCTAssertEqual(coordinator.enteredPin, "")
        XCTAssertEqual(coordinator.failedAttempts, 0)
    }

    func testInvalidPinTriggersShakeAndFailedCount() {
        let mockPin = MockPinManager()
        mockPin.storedPin = "1111"
        let mockBio = MockBiometricManager()
        let config = LockConfiguration(authMethod: .pinOnly(length: 4), maxFailedAttempts: 3, lockoutCooldown: 5)

        let coordinator = LockStateCoordinator(
            configuration: config,
            biometricManager: mockBio,
            pinManager: mockPin,
            initiallyLocked: true
        )

        coordinator.enteredPin = "9999"
        coordinator.submitPin()

        XCTAssertTrue(coordinator.isLocked)
        XCTAssertEqual(coordinator.failedAttempts, 1)
        XCTAssertTrue(coordinator.shakeTrigger)
        XCTAssertNotNil(coordinator.errorMessage)
    }

    func testFailedAttemptsTriggersLockout() {
        let mockPin = MockPinManager()
        mockPin.storedPin = "1111"
        let mockBio = MockBiometricManager()
        let config = LockConfiguration(authMethod: .pinOnly(length: 4), maxFailedAttempts: 2, lockoutCooldown: 10)

        let coordinator = LockStateCoordinator(
            configuration: config,
            biometricManager: mockBio,
            pinManager: mockPin,
            initiallyLocked: true
        )

        coordinator.enteredPin = "0000"
        coordinator.submitPin()
        XCTAssertFalse(coordinator.isLockedOut())

        coordinator.enteredPin = "0000"
        coordinator.submitPin()
        XCTAssertTrue(coordinator.isLockedOut())
        XCTAssertGreaterThan(coordinator.remainingLockoutSeconds(), 0)

        // Attempting to append pin while locked out is rejected
        coordinator.appendPinDigit("1", targetLength: 4)
        XCTAssertEqual(coordinator.enteredPin, "")
    }

    func testBiometricAuthenticationSuccess() async {
        let mockBio = MockBiometricManager()
        mockBio.mockedType = .faceID
        mockBio.shouldSucceed = true

        let coordinator = LockStateCoordinator(
            biometricManager: mockBio,
            initiallyLocked: true
        )

        XCTAssertTrue(coordinator.isLocked)
        await coordinator.triggerBiometricAuthentication()
        XCTAssertFalse(coordinator.isLocked)
    }

    func testBiometricAuthenticationFailure() async {
        let mockBio = MockBiometricManager()
        mockBio.mockedType = .faceID
        mockBio.errorToThrow = .authenticationFailed

        let coordinator = LockStateCoordinator(
            biometricManager: mockBio,
            initiallyLocked: true
        )

        XCTAssertTrue(coordinator.isLocked)
        await coordinator.triggerBiometricAuthentication()
        XCTAssertTrue(coordinator.isLocked)
        XCTAssertEqual(coordinator.errorMessage, BiometricError.authenticationFailed.localizedDescription)
    }

    func testBiometricErrorDescriptions() {
        XCTAssertNotNil(BiometricError.biometricsNotAvailable.errorDescription)
        XCTAssertNotNil(BiometricError.biometricsNotEnrolled.errorDescription)
        XCTAssertNotNil(BiometricError.userCanceled.errorDescription)
        XCTAssertNotNil(BiometricError.systemCanceled.errorDescription)
        XCTAssertNotNil(BiometricError.biometryLockedOut.errorDescription)
        XCTAssertNotNil(BiometricError.pinMismatch.errorDescription)
        XCTAssertNotNil(BiometricError.pinNotSet.errorDescription)
        XCTAssertNotNil(BiometricError.temporaryLockout(secondsRemaining: 15).errorDescription)
        XCTAssertNotNil(BiometricError.keychainError(status: -50).errorDescription)
        XCTAssertEqual(BiometricError.unknown("Custom err").errorDescription, "Custom err")
    }
}
