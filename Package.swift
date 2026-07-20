// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Ramona",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.4")
    ],
    targets: [
        .executableTarget(
            name: "Ramona",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/Ramona",
            resources: [
                .copy("Resources/Species"),
                .copy("Resources/Items"),
                .copy("Resources/Sprites")
            ]
        )
    ]
)
