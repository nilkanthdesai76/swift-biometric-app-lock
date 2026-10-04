# BiometricAppLock

[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2015+%20|%20macOS%2012+-blue.svg)](https://developer.apple.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![CI](https://github.com/nilkanthdesai76/swift-biometric-app-lock/actions/workflows/ci.yml/badge.svg)](https://github.com/nilkanthdesai76/swift-biometric-app-lock/actions/workflows/ci.yml)

A production-grade, zero-dependency biometric authentication and passcode lock system for SwiftUI. Features LocalAuthentication hardware integration (Face ID, Touch ID, Optic ID), salted SHA-256 Keychain PIN storage, app switcher privacy veils, auto-lock grace timers, and haptic error feedback.

![BiometricAppLock Architecture](assets/biometric_app_lock_diagram.svg)

---

## Features

- 🛡️ **Hardware Biometrics** — Seamless `LAContext` integration supporting Face ID, Touch ID, and Optic ID.
- 🔐 **Salted Keychain PINs** — Custom app PINs hashed with a cryptographically secure 16-byte random salt using CryptoKit SHA-256 and stored in Apple Keychain Services (`kSecClassGenericPassword`).
- 🙈 **Multitasking Privacy Veil** — Automatically obscures sensitive view hierarchies when backgrounded, preventing screenshots in the iOS App Switcher / macOS Dock.
- ⏱️ **Auto-Lock Grace Periods** — Configurable background timeouts (immediate, 30s, 1m, 5m) before re-locking.
- ⚡ **Cross-Platform Animation & Haptics** — Horizontal shake physics via `GeometryEffect` (zero iOS version runtime discrepancies) coupled with Apple Taptic Engine feedback.
- 🛑 **Rate Limiting & Lockout Penalties** — Exponential cooldown timers defending against automated brute-force attacks.
- 🧩 **Declarative ViewModifier** — Single-line `.appLock(coordinator:)` syntax wrapping any SwiftUI application.

---

## Requirements

| Platform | Minimum Deployment Target |
| :--- | :--- |
| **iOS** | 15.0+ |
| **macOS** | 12.0+ |
| **Swift** | 5.9+ / Swift 6 Ready |

---

## Installation

Add **BiometricAppLock** to your Xcode project or `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/nilkanthdesai76/swift-biometric-app-lock.git", from: "1.0.0")
]
```

Don't forget to add `NSFaceIDUsageDescription` to your app's `Info.plist`:

```xml
<key>NSFaceIDUsageDescription</key>
<string>Unlock sensitive documents and protect your personal data.</string>
```

---

## Quick Start

### 1. Simple App-Level Lock

```swift
import SwiftUI
import BiometricAppLock

@main
struct SecureApp: App {
    @StateObject private var lockCoordinator = LockStateCoordinator(
        configuration: LockConfiguration(
            authMethod: .biometricWithPinFallback(pinLength: 4),
            promptReason: "Unlock your financial vault",
            autoLockGracePeriod: 15, // 15 seconds grace period
            obscureOnBackground: true
        )
    )

    var body: some Scene {
        WindowGroup {
            ContentView()
                .appLock(coordinator: lockCoordinator)
        }
    }
}
```

### 2. Setting or Changing a PIN

```swift
let pinManager = PinSecurityManager.shared

do {
    // Hashes with 16-byte salt and saves into Keychain
    try pinManager.setPin("8492")
    print("PIN configured successfully")
} catch {
    print("Failed to set PIN: \(error.localizedDescription)")
}
```

### 3. Direct Biometric Authentication (Ad-Hoc)

```swift
let biometric = BiometricAuthManager.shared

Task {
    do {
        let authenticated = try await biometric.authenticate(
            reason: "Confirm your payment of $50.00",
            allowPasscodeFallback: true
        )
        if authenticated {
            processPayment()
        }
    } catch {
        print("Biometric auth failed: \(error.localizedDescription)")
    }
}
```

---

## Architecture

| Component | Responsibility |
| :--- | :--- |
| `BiometricAuthManager` | Wraps `LAContext` with async/await and maps OS errors to typed `BiometricError`. |
| `PinSecurityManager` | Generates CSPRNG salts, runs CryptoKit SHA-256 digests, and persists credentials in Keychain. |
| `LockStateCoordinator` | `@MainActor` state machine observing lifecycle notifications (`scenePhase`, background/active). |
| `BiometricLockView` | SwiftUI presentation view with responsive keypad, dot indicators, and error shake modifier. |
| `AppLockModifier` | ViewModifier injecting the privacy blur and coordinating modal overlay transitions. |

---

## Security Model

1. **No Plaintext Passcodes** — PINs are never stored in `UserDefaults`, memory caches, or unencrypted storage.
2. **Timing Attack Protection** — Salted hashes are evaluated with constant-time byte comparisons.
3. **App Switcher Protection** — High-radius gaussian blur prevents visual data leakage when switching apps.
4. **Hardware Key Enclave** — Leverages Apple's Secure Enclave indirectly through `LocalAuthentication`.

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
