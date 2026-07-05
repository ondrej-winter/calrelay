// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CalRelay", platforms: [.macOS(.v26)],
    products: [
        .executable(name: "calrelay", targets: ["CalRelayCLI"]), .executable(name: "CalRelayApp", targets: ["CalRelayApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.0.0")
    ],
    targets: [
        .target(
            name: "CalRelayKit", dependencies: [.product(name: "Yams", package: "Yams")], path: "Sources/CalRelayKit"),
        .executableTarget(name: "CalRelayApp", dependencies: ["CalRelayKit"], path: "Sources/CalRelayApp"),
        .executableTarget(
            name: "CalRelayCLI",
            dependencies: [
                "CalRelayKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ], path: "Sources/CalRelayCLI"),
        .executableTarget(name: "CalRelayKitTests", dependencies: ["CalRelayKit"], path: "Tests/CalRelayKitTests")
    ])
