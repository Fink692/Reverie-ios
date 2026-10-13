import XCTest
@testable import Reverie

final class MarketModelTests: XCTestCase {
    func testEveryThemeHasValidDeterministicStarterAssets() {
        let sceneID = UUID()
        for theme in PortfolioTheme.allCases {
            let profile = PortfolioProfile.starter(for: sceneID, theme: theme)
            XCTAssertTrue(profile.isValid, theme.name)
            XCTAssertFalse(profile.positions.isEmpty)
            XCTAssertEqual(profile.positions, PortfolioProfile.starter(for: sceneID, theme: theme).positions)
            XCTAssertTrue(profile.transactions.isEmpty)
        }
        for theme in WalletTheme.allCases {
            let profile = WalletProfile.starter(for: sceneID, theme: theme)
            XCTAssertTrue(profile.isValid, theme.name)
            XCTAssertFalse(profile.holdings.isEmpty)
            XCTAssertEqual(profile.holdings, WalletProfile.starter(for: sceneID, theme: theme).holdings)
        }
        XCTAssertTrue(PredictionProfile.starter(for: sceneID).isValid)
    }

    func testOldArchivesDefaultTheThreeNewProfileArrays() throws {
        let scenes = Array(StudioScene.examples.prefix(3))
        let archive = Archive(scenes: scenes, events: [], activeID: scenes[0].id)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: archive.encoded()) as? [String: Any])
        for key in ["portfolioProfiles", "walletProfiles", "predictionProfiles"] { json.removeValue(forKey: key) }
        let decoded = try Archive.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.scenes, scenes)
        XCTAssertTrue(decoded.portfolioProfiles.isEmpty)
        XCTAssertTrue(decoded.walletProfiles.isEmpty)
        XCTAssertTrue(decoded.predictionProfiles.isEmpty)
    }

    func testPortfolioWithoutTransferHistoryDecodesWithAnEmptyArray() throws {
        let profile = PortfolioProfile.starter(for: UUID(), theme: .coinbase)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(profile)) as? [String: Any])
        json.removeValue(forKey: "transfers")
        let decoded = try JSONDecoder().decode(PortfolioProfile.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded, profile)
        XCTAssertTrue(decoded.transfers.isEmpty)
    }

    func testAllProfileKindsAndEmbeddedTransactionsSurviveArchiveRoundTrip() throws {
        let scenes = StudioScene.examples
        let portfolioScene = try XCTUnwrap(scenes.first { $0.kind == .portfolio })
        let walletScene = try XCTUnwrap(scenes.first { $0.kind == .wallet })
        let predictionScene = try XCTUnwrap(scenes.first { $0.kind == .prediction })
        var portfolio = PortfolioProfile.starter(for: portfolioScene.id, theme: .coinbase)
        let asset = portfolio.positions[0]
        portfolio.transactions = [MarketTransaction(assetID: asset.id, symbol: asset.symbol, side: .buy, units: 0.01, price: asset.price)]
        var wallet = WalletProfile.starter(for: walletScene.id, theme: .phantom)
        let token = wallet.holdings[0]
        wallet.transactions = [WalletTransaction(assetID: token.id, symbol: token.symbol, network: token.network,
            address: token.address ?? wallet.address, kind: .receive, quantity: 0.25, price: token.price)]
        var prediction = PredictionProfile.starter(for: predictionScene.id)
        let market = prediction.markets[0]
        prediction.transactions = [PredictionTrade(marketID: market.id, question: market.question, outcome: .no,
            side: .buy, shares: 20, price: market.noPrice)]
        let archive = Archive(scenes: scenes, events: [], activeID: scenes[0].id,
            portfolioProfiles: [portfolio], walletProfiles: [wallet], predictionProfiles: [prediction])
        let decoded = try Archive.decode(archive.encoded())
        XCTAssertEqual(decoded.portfolioProfiles, [portfolio])
        XCTAssertEqual(decoded.walletProfiles, [wallet])
        XCTAssertEqual(decoded.predictionProfiles, [prediction])
    }

    func testAssetBoundsDuplicateIdentitiesAndBrokenHistoryReferencesAreRejected() {
        var portfolio = PortfolioProfile.starter(for: UUID())
        portfolio.positions[0].price = .infinity
        XCTAssertFalse(portfolio.isValid)
        portfolio = .starter(for: UUID())
        portfolio.positions.append(portfolio.positions[0])
        XCTAssertFalse(portfolio.isValid)
        portfolio = .starter(for: UUID())
        portfolio.transactions = [MarketTransaction(assetID: UUID(), symbol: "AAPL", side: .buy, units: 1, price: 20)]
        XCTAssertFalse(portfolio.isValid)
        portfolio.transactions = [MarketTransaction(assetID: portfolio.positions[0].id, symbol: "WRONG", side: .buy, units: 1, price: 20)]
        XCTAssertFalse(portfolio.isValid)
        var wallet = WalletProfile.starter(for: UUID())
        wallet.holdings[0].quantity = 1_000_000_000
        XCTAssertFalse(wallet.isValid)
        wallet = .starter(for: UUID())
        wallet.holdings[0].chart = [0, .nan]
        XCTAssertFalse(wallet.isValid)
        wallet = .starter(for: UUID())
        wallet.transactions = [WalletTransaction(assetID: wallet.holdings[0].id, symbol: wallet.holdings[0].symbol,
            network: "Wrong network", address: wallet.address, kind: .receive, quantity: 1, price: 20)]
        XCTAssertFalse(wallet.isValid)
        var prediction = PredictionProfile.starter(for: UUID())
        prediction.positions[0].marketID = UUID()
        XCTAssertFalse(prediction.isValid)
        prediction = .starter(for: UUID())
        prediction.positions.append(prediction.positions[0])
        XCTAssertFalse(prediction.isValid)
    }

    func testArchiveRejectsWrongKindsOrMissingScenesAndCombinedAccountOverflow() {
        let scenes = StudioScene.examples
        let wrong = PortfolioProfile.starter(for: scenes[0].id)
        XCTAssertFalse(Archive(scenes: scenes, events: [], activeID: scenes[0].id, portfolioProfiles: [wrong]).isValid)
        XCTAssertFalse(Archive(scenes: scenes, events: [], activeID: scenes[0].id,
            walletProfiles: [.starter(for: UUID())]).isValid)
        let portfolioScene = scenes.first { $0.kind == .portfolio }!
        var oversizedScenes = scenes
        oversizedScenes[oversizedScenes.firstIndex { $0.id == portfolioScene.id }!].balance = 1_000_000_000
        XCTAssertFalse(Archive(scenes: oversizedScenes, events: [], activeID: scenes[0].id,
            portfolioProfiles: [.starter(for: portfolioScene.id)]).isValid)
    }

    func testPredictionOutcomesAndClosedBoundariesRemainConsistent() {
        var market = PredictionProfile.starter(for: UUID()).markets[0]
        XCTAssertEqual(market.price(for: .yes) + market.price(for: .no), 1, accuracy: 0.000001)
        XCTAssertTrue(market.isOpen)
        market.closeDate = .distantPast
        XCTAssertTrue(market.isValid)
        XCTAssertFalse(market.isOpen)
        market.closeDate = .distantFuture
        market.yesPrice = 1
        XCTAssertTrue(market.isValid)
        XCTAssertFalse(market.isOpen)
        let zeroPrice = PredictionTrade(marketID: market.id, question: market.question, outcome: .no,
            side: .buy, shares: 10, price: 0)
        XCTAssertFalse(zeroPrice.isValid)
        market.yesPrice = -0.01
        XCTAssertFalse(market.isValid)
    }

    func testWalletMetadataRejectsPrivatePhraseTextAndInvalidPublicAddresses() {
        var wallet = WalletProfile.starter(for: UUID())
        wallet.address = "word word word word word word word word word word word word"
        XCTAssertFalse(wallet.isValid)
        wallet.address = "short"
        XCTAssertFalse(wallet.isValid)
        wallet.address = String(repeating: "a", count: 121)
        XCTAssertFalse(wallet.isValid)
        wallet.address = "0x0000000000000000000000000000000000000000"
        XCTAssertTrue(wallet.isValid)
    }
}
