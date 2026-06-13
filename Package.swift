// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StretchCat",
    platforms: [.macOS(.v13)],
    targets: [
        // Pure, platform-agnostic logic (exercises + scheduling math).
        // Unit-tested and kept in lockstep with the Windows port.
        .target(
            name: "StretchCatCore",
            path: "Sources/StretchCatCore"
        ),
        .executableTarget(
            name: "StretchCat",
            dependencies: ["StretchCatCore"],
            path: "Sources/StretchCat"
        ),
        .testTarget(
            name: "StretchCatCoreTests",
            dependencies: ["StretchCatCore"],
            path: "Tests/StretchCatCoreTests"
        ),
    ]
)
