// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "swift-biometric-app-lock",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "BiometricAppLock",
            targets: ["BiometricAppLock"]
        ),
    ],
    targets: [
        .target(
            name: "BiometricAppLock",
            dependencies: [],
            path: "Sources/BiometricAppLock"
        ),
        .testTarget(
            name: "BiometricAppLockTests",
            dependencies: ["BiometricAppLock"],
            path: "Tests/BiometricAppLockTests"
        ),
    ]
)
