// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DrumKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "DrumKit", targets: ["DrumCore", "DrumAudio", "DrumAnalysis", "DrumLibrary", "DrumAI"]),
    ],
    targets: [
        .target(name: "DrumCore"),
        .target(name: "DrumAnalysis", dependencies: ["DrumCore"]),
        .target(name: "DrumAudio", dependencies: ["DrumCore", "DrumAnalysis"], resources: [.copy("Resources/Clicks")]),
        .target(name: "DrumLibrary", dependencies: ["DrumCore", "DrumAnalysis"]),
        .target(name: "DrumAI", dependencies: ["DrumCore", "DrumAnalysis", "DrumLibrary"]),
        .testTarget(name: "DrumCoreTests", dependencies: ["DrumCore"]),
        .testTarget(name: "DrumAnalysisTests", dependencies: ["DrumAnalysis"]),
        .testTarget(name: "DrumAudioTests", dependencies: ["DrumAudio"]),
        .testTarget(name: "DrumLibraryTests", dependencies: ["DrumLibrary"]),
        .testTarget(name: "DrumAITests", dependencies: ["DrumAI"]),
    ]
)
