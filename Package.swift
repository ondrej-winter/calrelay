// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CalRelay",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "calrelay", targets: ["CalRelay"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0")
    ],
    targets: [
        .target(
            name: "CalRelayCore",
            path: "Sources/CalRelayCore"
        ),
        .executableTarget(
            name: "CalRelay",
            dependencies: [
                "CalRelayCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/CalRelay"
        ),
        .executableTarget(
            name: "CalRelayContractTests",
            dependencies: ["CalRelayCore"],
            path: "Tests/CalRelayContractTests"
        )
    ]
)