// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "TranslationCore", platforms: [.macOS("26.0")], products: [.library(name: "TranslationCore", targets: ["TranslationCore"])], targets: [.target(name: "TranslationCore"), .testTarget(name: "TranslationCoreTests", dependencies: ["TranslationCore"])])
