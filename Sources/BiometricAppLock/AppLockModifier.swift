//
//  AppLockModifier.swift
//  BiometricAppLock
//
//  Created by Nilkanth Desai.
//  Copyright © 2026 Nilkanth Desai. All rights reserved.
//

import SwiftUI
import Combine

/// View modifier presenting the biometric lock overlay and background privacy veil.
public struct AppLockModifier: ViewModifier {
    @ObservedObject public var coordinator: LockStateCoordinator

    public init(coordinator: LockStateCoordinator) {
        self.coordinator = coordinator
    }

    public func body(content: Content) -> some View {
        ZStack {
            content
                // Obscure app contents when privacy veil is triggered by app switcher
                .blur(radius: coordinator.isPrivacyVeilVisible ? 25 : 0)

            if coordinator.isPrivacyVeilVisible && !coordinator.isLocked {
                Color.black.opacity(0.85)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            if coordinator.isLocked {
                BiometricLockView(coordinator: coordinator)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(999)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: coordinator.isLocked)
        .animation(.easeInOut(duration: 0.2), value: coordinator.isPrivacyVeilVisible)
    }
}

public extension View {
    /// Applies biometric and PIN passcode protection to this view hierarchy.
    /// - Parameter coordinator: The coordinator governing lock state and security policies.
    func appLock(coordinator: LockStateCoordinator) -> some View {
        modifier(AppLockModifier(coordinator: coordinator))
    }
}
