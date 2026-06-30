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
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.0.0")
    ],
    targets: [
        .target(
            name: "CalRelayCore",
            path: "Sources/CalRelayCore"
        ),
        .target(
            name: "CalRelayAdapters",
            dependencies: [
                "CalRelayCore",
                .product(name: "Yams", package: "Yams")
            ],
            path: "Sources/CalRelayAdapters"
        ),
        .executableTarget(
            name: "CalRelay",
            dependencies: [
                "CalRelayCore",
                "CalRelayAdapters",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/CalRelay"
        ),
        .testTarget(
            name: "CalRelayContractTests",
            dependencies: [
                "CalRelayCore",
                "CalRelayAdapters"
            ],
            path: "Tests/CalRelayContractTests"
        )
    ]
)