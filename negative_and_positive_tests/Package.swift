// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LogisticsValidationTests",
    products: [.library(name: "ValidationCore", targets: ["ValidationCore"])],
    targets: [
        .target(name: "ValidationCore"),
        .testTarget(name: "ValidationCoreTests", dependencies: ["ValidationCore"])
    ]
)
