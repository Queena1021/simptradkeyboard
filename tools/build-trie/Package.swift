// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "build-trie",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: "../../KeyboardCore")
    ],
    targets: [
        .executableTarget(
            name: "build-trie",
            dependencies: ["KeyboardCore"]
        )
    ]
)
