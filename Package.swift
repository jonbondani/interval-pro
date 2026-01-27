// swift-tools-version: 5.9
// Package manifest for IntervalPro dependencies

import PackageDescription

let package = Package(
    name: "IntervalProDependencies",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "IntervalProDependencies",
            targets: ["IntervalProDependencies"]
        )
    ],
    dependencies: [
        // Firebase - Analytics & Crashlytics
        .package(
            url: "https://github.com/firebase/firebase-ios-sdk.git",
            from: "10.0.0"
        ),
    ],
    targets: [
        .target(
            name: "IntervalProDependencies",
            dependencies: [
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),
            ]
        )
    ]
)

// Note: Spotify SDK should be added manually as it requires custom integration
// Garmin Connect IQ SDK should be added via the Garmin developer portal
