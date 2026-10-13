// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ReverieCore",
    products: [.library(name: "Reverie", targets: ["Reverie"])],
    targets: [
        .target(name: "Reverie", path: "Sources", exclude: ["Views.swift", "Store.swift", "ReverieApp.swift", "Assets.xcassets", "PrivacyInfo.xcprivacy"], sources: ["Models.swift", "SessionStorage.swift"]),
        .testTarget(name: "ReverieCoreTests", dependencies: ["Reverie"], path: "Tests", exclude: ["PersistenceTests.swift"], sources: ["SimulationTests.swift", "ValidationTests.swift", "SessionStorageTests.swift", "SessionCodecTests.swift"])
    ],
    swiftLanguageModes: [.v5]
)
