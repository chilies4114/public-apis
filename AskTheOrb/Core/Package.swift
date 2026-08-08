// swift-tools-version: 5.9
import PackageDescription

// OrbCore is deliberately UI-free and platform-agnostic so the prediction
// logic, probability scales and entitlement rules can be unit tested on any
// machine (including CI runners without Xcode). The SwiftUI app target lives in
// the Xcode project generated from project.yml and depends on this package.
let package = Package(
    name: "OrbCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "OrbCore", targets: ["OrbCore"])
    ],
    targets: [
        .target(
            name: "OrbCore",
            path: "Sources/OrbCore"
        ),
        .testTarget(
            name: "OrbCoreTests",
            dependencies: ["OrbCore"],
            path: "Tests/OrbCoreTests"
        )
    ]
)
