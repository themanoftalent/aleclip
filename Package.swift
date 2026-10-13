// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "aleclip",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "aleclip", targets: ["aleclip"]),
        .executable(name: "test-runner", targets: ["test-runner"])
    ],
    targets: [
        .target(
            name: "AleClipCore",
            path: "Sources/aleclip"
        ),
        .executableTarget(
            name: "aleclip",
            dependencies: ["AleClipCore"],
            path: "Sources/aleclipApp",
            sources: ["main.swift"]
        ),
        .executableTarget(
            name: "test-runner",
            dependencies: ["AleClipCore"],
            path: "Sources/testRunner",
            sources: ["main.swift"]
        )
    ]
)
