// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ZuntrioCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ZuntrioCore", targets: ["ZuntrioCore"]),
    ],
    targets: [
        .target(name: "ZuntrioCore"),
        .testTarget(name: "ZuntrioCoreTests", dependencies: ["ZuntrioCore"]),
    ]
)
