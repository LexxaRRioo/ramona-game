// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Ramona",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Ramona",
            path: "Sources/Ramona",
            resources: [
                .copy("Resources/Species"),
                .copy("Resources/Items"),
                .copy("Resources/Sprites")
            ]
        )
    ]
)
