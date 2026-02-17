// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "sel-translator",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "SelTranslator",
            targets: ["SelTranslator"]
        )
    ],
    targets: [
        .executableTarget(
            name: "SelTranslator"
        )
    ]
)
