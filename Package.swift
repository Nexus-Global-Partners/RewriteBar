// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "RewriteBar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "RewriteBar", targets: ["RewriteBar"]),
        .executable(name: "RewriteCoreChecks", targets: ["RewriteCoreChecks"])
    ],
    targets: [
        .target(name: "RewriteCore"),
        .executableTarget(name: "RewriteBar", dependencies: ["RewriteCore"]),
        .executableTarget(name: "RewriteCoreChecks", dependencies: ["RewriteCore"]),
        .testTarget(name: "RewriteBarTests", dependencies: ["RewriteBar", "RewriteCore"])
    ]
)
