// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ReverieCore",
    products: [.library(name: "Reverie", targets: ["Reverie"])],
    targets: [
        .target(name: "Reverie", path: "Sources", exclude: ["Views.swift", "Store.swift", "ReverieApp.swift", "Assets.xcassets", "PrivacyInfo.xcprivacy", "CommercePlayback.swift", "BankPlayback.swift", "PortfolioPlayback.swift", "WalletPlayback.swift", "PredictionPlayback.swift", "Order.caf"], sources: ["Models.swift", "SessionStorage.swift", "PlaybackModels.swift", "MarketModels.swift"]),
        .testTarget(name: "ReverieCoreTests", dependencies: ["Reverie"], path: "Tests", exclude: ["PersistenceTests.swift"], sources: ["SimulationTests.swift", "ValidationTests.swift", "SessionStorageTests.swift", "SessionCodecTests.swift", "PlaybackModelTests.swift", "MarketModelTests.swift"])
    ],
    swiftLanguageModes: [.v5]
)
