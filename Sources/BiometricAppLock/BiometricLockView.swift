//
//  BiometricLockView.swift
//  BiometricAppLock
//
//  Created by Nilkanth Desai.
//  Copyright © 2026 Nilkanth Desai. All rights reserved.
//

import SwiftUI
import Combine

#if canImport(UIKit)
import UIKit
#endif

/// Geometry effect providing a clean horizontal shake animation for incorrect PIN entries across all OS versions.
public struct ShakeEffect: GeometryEffect {
    public var amount: CGFloat = 10
    public var shakesPerUnit: CGFloat = 3
    public var animatableData: CGFloat

    public init(shakes: CGFloat, amount: CGFloat = 10, shakesPerUnit: CGFloat = 3) {
        self.animatableData = shakes
        self.amount = amount
        self.shakesPerUnit = shakesPerUnit
    }

    public func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = amount * sin(animatableData * .pi * shakesPerUnit)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

/// SwiftUI View rendering an Apple-standard biometric unlock & PIN entry screen.
public struct BiometricLockView: View {
    @ObservedObject public var coordinator: LockStateCoordinator
    @State private var shakeCount: CGFloat = 0

    public init(coordinator: LockStateCoordinator) {
        self.coordinator = coordinator
    }

    private var pinLength: Int {
        switch coordinator.configuration.authMethod {
        case .pinOnly(let length):
            return length
        case .biometricWithPinFallback(let length):
            return length
        default:
            return 4
        }
    }

    public var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // Header
                headerSection

                // PIN dots indicator
                pinDotsView
                    .modifier(ShakeEffect(shakes: shakeCount))
                    .onChange(of: coordinator.shakeTrigger) { _ in
                        withAnimation(.default) {
                            shakeCount += 1
                        }
                        triggerErrorHaptic()
                    }

                // Error message
                if let errorMessage = coordinator.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .transition(.opacity)
                }

                Spacer()

                // Number Pad
                keypadGrid
                    .padding(.bottom, 24)

                // Optional Forgot PIN Button
                if let forgotAction = coordinator.configuration.forgotPinAction {
                    Button(action: forgotAction) {
                        Text("Forgot PIN?")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 16)
                }
            }
            .padding(.horizontal, 24)
        }
        .task {
            // Auto trigger biometrics on view display if configured
            if case .biometricWithPinFallback = coordinator.configuration.authMethod {
                await coordinator.triggerBiometricAuthentication()
            } else if coordinator.configuration.authMethod == .biometricOnly {
                await coordinator.triggerBiometricAuthentication()
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: coordinator.biometricType.systemImageName)
                .font(.system(size: 44, weight: .light))
                .foregroundColor(.white)

            Text("Enter Passcode")
                .font(.title2.bold())
                .foregroundColor(.white)

            if let subtitle = coordinator.configuration.subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var pinDotsView: some View {
        HStack(spacing: 18) {
            ForEach(0..<pinLength, id: \.self) { index in
                Circle()
                    .fill(index < coordinator.enteredPin.count ? Color.white : Color.white.opacity(0.2))
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.4), lineWidth: 1)
                    )
            }
        }
        .padding(.vertical, 8)
    }

    private var keypadGrid: some View {
        VStack(spacing: 20) {
            ForEach(0..<3) { row in
                HStack(spacing: 32) {
                    ForEach(1...3, id: \.self) { col in
                        let digit = String(row * 3 + col)
                        keypadButton(title: digit) {
                            handleDigit(digit)
                        }
                    }
                }
            }

            // Bottom row: Biometric / 0 / Delete
            HStack(spacing: 32) {
                // Biometrics shortcut button
                if coordinator.biometricType != .none {
                    Button {
                        triggerKeyHaptic()
                        Task {
                            await coordinator.triggerBiometricAuthentication()
                        }
                    } label: {
                        Image(systemName: coordinator.biometricType.systemImageName)
                            .font(.system(size: 26))
                            .foregroundColor(.white)
                            .frame(width: 72, height: 72)
                    }
                } else {
                    Spacer().frame(width: 72, height: 72)
                }

                // Digit 0
                keypadButton(title: "0") {
                    handleDigit("0")
                }

                // Delete button
                Button {
                    triggerKeyHaptic()
                    coordinator.deletePinDigit()
                } label: {
                    Image(systemName: "delete.backward")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                        .frame(width: 72, height: 72)
                }
            }
        }
    }

    private func keypadButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            triggerKeyHaptic()
            action()
        }) {
            Text(title)
                .font(.system(size: 30, weight: .regular))
                .foregroundColor(.white)
                .frame(width: 72, height: 72)
                .background(Circle().fill(Color.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions & Haptics

    private func handleDigit(_ digit: String) {
        coordinator.appendPinDigit(digit, targetLength: pinLength)
    }

    private func triggerKeyHaptic() {
        #if canImport(UIKit)
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.prepare()
        impact.impactOccurred()
        #endif
    }

    private func triggerErrorHaptic() {
        #if canImport(UIKit)
        let notification = UINotificationFeedbackGenerator()
        notification.prepare()
        notification.notificationOccurred(.error)
        #endif
    }
}
