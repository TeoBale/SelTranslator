// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "sel-translator",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "SelTranslator", targets: ["SelTranslator"]),
        .library(name: "SelTranslatorCore", targets: ["SelTranslatorCore"])
    ],
    targets: [
        .target(name: "SelTranslatorCore"),
        .executableTarget(name: "SelTranslator", dependencies: ["SelTranslatorCore"]),
        .testTarget(name: "SelTranslatorCoreTests", dependencies: ["SelTranslatorCore"]),
    ]
)
