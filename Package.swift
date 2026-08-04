// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "RewriteBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "RewriteBar", targets: ["RewriteBar"]),
        .executable(name: "RewriteBenchmark", targets: ["RewriteBenchmark"]),
        .executable(name: "RewriteCoreChecks", targets: ["RewriteCoreChecks"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/ml-explore/mlx-swift.git",
            .upToNextMinor(from: "0.31.3")
        ),
        .package(
            url: "https://github.com/ml-explore/mlx-swift-lm.git",
            exact: "2.31.3"
        )
    ],
    targets: [
        .target(
            name: "RewriteCore"
        ),
        .executableTarget(
            name: "RewriteBar",
            dependencies: [
                "RewriteCore",
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm")
            ]
        ),
        .executableTarget(
            name: "RewriteCoreChecks",
            dependencies: ["RewriteCore"]
        ),
        .executableTarget(
            name: "RewriteBenchmark",
            dependencies: [
                "RewriteCore",
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm")
            ]
        )
    ]
)
