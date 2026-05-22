// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Authenticator",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Authenticator", targets: ["Authenticator"]),
        .library(name: "AuthenticatorCore", targets: ["AuthenticatorCore"]),
    ],
    targets: [
        .target(
            name: "AuthenticatorCore",
            path: "Sources/AuthenticatorCore"
        ),
        .target(
            name: "AuthenticatorPlatform",
            dependencies: ["AuthenticatorCore"],
            path: "Sources/AuthenticatorPlatform"
        ),
        .executableTarget(
            name: "Authenticator",
            dependencies: ["AuthenticatorCore", "AuthenticatorPlatform"],
            path: "Sources/Authenticator"
        ),
        .testTarget(
            name: "AuthenticatorCoreTests",
            dependencies: ["AuthenticatorCore"],
            path: "Tests/AuthenticatorCoreTests"
        ),
    ]
)
