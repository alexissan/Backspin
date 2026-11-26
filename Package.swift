// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Backspin",
    defaultLocalization: "en",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "BackspinCore"),
        .target(name: "BackspinKit", dependencies: ["BackspinCore"]),
        .executableTarget(name: "Backspin", dependencies: ["BackspinCore", "BackspinKit"]),
        .testTarget(name: "BackspinTests", dependencies: ["BackspinCore"]),
    ]
)
