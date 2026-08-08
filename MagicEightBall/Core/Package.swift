// swift-tools-version: 5.9
import PackageDescription

// EightBallCore is deliberately UI-free and platform-agnostic so the prediction
// logic, probability scales and entitlement rules can be unit tested on any
// machine (including CI runners without Xcode). The SwiftUI app target lives in
// the Xcode project generated from project.yml and depends on this package.
let package = Package(
    name: "EightBallCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "EightBallCore", targets: ["EightBallCore"])
    ],
    targets: [
        .target(
            name: "EightBallCore",
            path: "Sources/EightBallCore"
        ),
        .testTarget(
            name: "EightBallCoreTests",
            dependencies: ["EightBallCore"],
            path: "Tests/EightBallCoreTests"
        )
    ]
)
