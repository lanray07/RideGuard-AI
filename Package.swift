// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RideGuardCore",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v14)],
    products: [.library(name: "RideGuardCore", targets: ["RideGuardCore"])],
    targets: [
        .target(name: "RideGuardCore", path: "Sources/RideGuardCore"),
        .testTarget(name: "RideGuardCoreTests", dependencies: ["RideGuardCore"], path: "Tests/RideGuardCoreTests")
    ]
)
