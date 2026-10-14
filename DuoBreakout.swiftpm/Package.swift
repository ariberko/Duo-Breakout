// swift-tools-version: 5.9

// Open this folder in Swift Playgrounds on iPad to play the game right away.
// The real App Store app is built from the same code by project.yml.

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "Duo Breakout",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "Duo Breakout",
            targets: ["AppModule"],
            bundleIdentifier: "com.ariberkowitz.duobreakout.preview",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .gamepad),
            accentColor: .presetColor(.cyan),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ]
)
