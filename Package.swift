// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StretchCat",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "StretchCat",
            path: "Sources/StretchCat"
        )
    ]
)
