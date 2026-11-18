// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TarotCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "TarotCore", targets: ["TarotCore"])],
    targets: [
        .target(name: "TarotCore"),
        .testTarget(name: "TarotCoreTests", dependencies: ["TarotCore"]),
    ]
)
