// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BrewGUI",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "BrewGUI", targets: ["BrewGUI"])
    ],
    targets: [
        .executableTarget(
            name: "BrewGUI",
            path: "Sources/BrewGUI"
        )
    ]
)
