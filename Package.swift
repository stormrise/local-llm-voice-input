// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LocalVoice",
    platforms: [
        .macOS(.v26)
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift.git", branch: "main"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", branch: "main"),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "1.3.3"),
    ],
    targets: [
        .target(
            name: "ASREngine",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "MLXFast", package: "mlx-swift"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "Tokenizers", package: "swift-transformers"),
            ],
            path: "Sources/ASREngine"
        ),
        .executableTarget(
    name: "LocalVoice",
            dependencies: [
                .target(name: "ASREngine"),
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "MLXFast", package: "mlx-swift"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "Tokenizers", package: "swift-transformers"),
            ],
            path: "Sources",
            exclude: [
                "Info.plist",
                "VocalType.entitlements",
                "VocalTypeCLI",
                "ASREngine"
            ],
            resources: [
                .process("Assets.xcassets"),
                .process("Config/default_config.json"),
                .copy("Resources")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "LocalVoiceTests",
            dependencies: ["LocalVoice"],
            path: "Tests/VocalTypeTests"
        ),
        .executableTarget(
            name: "LocalVoiceCLI",
            dependencies: [
                .target(name: "ASREngine"),
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "MLXFast", package: "mlx-swift"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "Tokenizers", package: "swift-transformers"),
            ],
            path: "Sources/VocalTypeCLI"
        ),
    ]
)
