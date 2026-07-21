// swift-tools-version: 6.0
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
            ],
            // Package-wide tools-version 6.0 is only here to get Swift
            // Testing auto-linked into RamonaTests below (needs 6.0+); the
            // app itself isn't written for Swift 6's strict concurrency
            // checking, so it stays pinned to language mode 5.
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "RamonaTests",
            dependencies: ["Ramona"],
            path: "Tests/RamonaTests",
            // CommandLineTools (no full Xcode.app on this machine) ships
            // Testing.framework but doesn't wire its search path into
            // `swift test` the way Xcode's toolchain does - add it explicitly.
            swiftSettings: [
                .unsafeFlags(["-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker", "-rpath", "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
                ])
            ]
        )
    ]
)
