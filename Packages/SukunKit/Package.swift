// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SukunKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SukunKit", targets: ["SukunKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/batoulapps/adhan-swift", from: "1.4.0")
    ],
    targets: [
        .target(
            name: "SukunKit",
            dependencies: [.product(name: "Adhan", package: "adhan-swift")],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "SukunKitTests",
            dependencies: ["SukunKit"]
        )
    ]
)
