// swift-tools-version: 5.9
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
