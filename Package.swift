// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "ConsoleSwitcher",
    platforms: [
        .macOS(.v12)
    ],
    targets: [
        .executableTarget(
            name: "ConsoleSwitcher",
            path: "Sources/ConsoleSwitcher"
        )
    ]
)
