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

    func testPortfolioAccountStateValidatesEveryAmountAndInterestRateWithoutAddingValue() {
        let amounts: [WritableKeyPath<PortfolioAccountState, Double>] = [
            \.cardBalance, \.availableCredit, \.cashBack, \.monthCashBack, \.statementAmount,
            \.monthlyInterest, \.highYieldCashEarnings, \.iraMatchEarnings
        ]
        for field in amounts {
            for value in [-1, 1_000_000_001, Double.infinity, -.infinity, .nan] {
                var state = PortfolioAccountState()
                state[keyPath: field] = value
                XCTAssertFalse(state.isValid)
                var profile = PortfolioProfile.starter(for: UUID())
                profile.accountState = state
                XCTAssertFalse(profile.isValid)
            }
            for value in [0.0, 1_000_000_000] {
                var state = PortfolioAccountState()
                state[keyPath: field] = value
                XCTAssertTrue(state.isValid)
            }
        }
        for rate in [-0.01, 100.01, Double.infinity, .nan] {
            var state = PortfolioAccountState()
            state.chequingInterestRate = rate
            XCTAssertFalse(state.isValid)
        }
        var profile = PortfolioProfile.starter(for: UUID(), theme: .wealthsimple)
        let total = profile.total(cash: 1234)
        profile.accountState.cardBalance = 999_000_000
        profile.accountState.highYieldCashEarnings = 5000
        profile.accountState.iraMatchEarnings = 8000
        XCTAssertTrue(profile.isValid)
        XCTAssertEqual(profile.total(cash: 1234), total)
    }

    func testNewCoinbaseAndMetaMaskStartersUseSeparateStablecoinAssets() throws {
        let sceneID = UUID()
        let coinbase = PortfolioProfile.starter(for: sceneID, theme: .coinbase)
        let usdc = try XCTUnwrap(coinbase.positions.first { $0.symbol == "USDC" })
        XCTAssertEqual(usdc.units, 0)
        XCTAssertEqual(usdc.price, 1)
        XCTAssertEqual(usdc.transferNetwork, "Ethereum")
        XCTAssertEqual(PortfolioProfile.availableAsset(symbol: "usdc"), usdc)
        let metamask = WalletProfile.starter(for: sceneID, theme: .metamask)
        let musd = try XCTUnwrap(metamask.holdings.first { $0.symbol == "MUSD" })
        XCTAssertEqual(musd.name, "MetaMask USD")
        XCTAssertEqual(musd.network, "Ethereum")
        XCTAssertEqual(musd.price, 1)
        XCTAssertEqual(musd.quantity, 1480)
        XCTAssertFalse(metamask.holdings.contains { $0.symbol == "USDC" })
        XCTAssertEqual(metamask.holdings, WalletProfile.starter(for: sceneID, theme: .metamask).holdings)
        XCTAssertTrue(WalletProfile.starter(for: sceneID, theme: .phantom).holdings.contains { $0.symbol == "USDC" })
    }

    func testMissingAccountStateUsesEmptyDefaultsForEveryThemeAndPreservesEditedAssets() throws {
        for theme in PortfolioTheme.allCases {
            var profile = PortfolioProfile.starter(for: UUID(), theme: theme)
            profile.positions[0].units = 0.5
            var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(profile)) as? [String: Any])
            json.removeValue(forKey: "accountState")
            let decoded = try JSONDecoder().decode(PortfolioProfile.self, from: JSONSerialization.data(withJSONObject: json))
            profile.accountState = PortfolioAccountState()
            XCTAssertEqual(decoded, profile)
            XCTAssertEqual(decoded.accountState, PortfolioAccountState())
        }
    }

    func testLegacyMarketArchiveDefaultsNewFieldsWithoutReseedingAssetsOrCash() throws {
        var scenes = StudioScene.examples
        let portfolioIndex = try XCTUnwrap(scenes.firstIndex { $0.kind == .portfolio })
        let walletIndex = try XCTUnwrap(scenes.firstIndex { $0.kind == .wallet })
        let predictionIndex = try XCTUnwrap(scenes.firstIndex { $0.kind == .prediction })
        scenes[portfolioIndex].balance = 1234.56
        scenes[walletIndex].balance = 345.67
        scenes[predictionIndex].balance = 890.12
        var portfolio = PortfolioProfile.starter(for: scenes[portfolioIndex].id, theme: .coinbase)
        portfolio.positions.removeAll { $0.symbol == "USDC" }
        portfolio.positions[0].units = 0.25
        portfolio.positions[0].price = 40000
        let asset = portfolio.positions[0]
        portfolio.transactions = [MarketTransaction(assetID: asset.id, symbol: asset.symbol, side: .buy, units: 0.01, price: 30000)]
        var wallet = WalletProfile.starter(for: scenes[walletIndex].id, theme: .metamask)
        let stablecoinIndex = try XCTUnwrap(wallet.holdings.firstIndex { $0.symbol == "MUSD" })
        wallet.holdings[stablecoinIndex].id = UUID()
        wallet.holdings[stablecoinIndex].symbol = "USDC"
        wallet.holdings[stablecoinIndex].name = "USD Coin"
        wallet.holdings[stablecoinIndex].quantity = 77.5
        let stablecoin = wallet.holdings[stablecoinIndex]
        wallet.transactions = [WalletTransaction(assetID: stablecoin.id, symbol: "USDC", network: stablecoin.network,
            address: wallet.address, kind: .receive, quantity: 7.5, price: 1)]
        var prediction = PredictionProfile.starter(for: scenes[predictionIndex].id)
        let tennisIDs = Set((prediction.games ?? []).filter { $0.league == "Tennis" }.map(\.marketID))
        prediction.markets.removeAll { tennisIDs.contains($0.id) }
        prediction.games?.removeAll { tennisIDs.contains($0.marketID) }
        let archive = Archive(scenes: scenes, events: [], activeID: scenes[portfolioIndex].id,
            portfolioProfiles: [portfolio], walletProfiles: [wallet], predictionProfiles: [prediction])
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: archive.encoded()) as? [String: Any])
        var portfolios = try XCTUnwrap(json["portfolioProfiles"] as? [[String: Any]])
        portfolios[0].removeValue(forKey: "accountState")
        portfolios[0].removeValue(forKey: "transfers")
        json["portfolioProfiles"] = portfolios
        var predictions = try XCTUnwrap(json["predictionProfiles"] as? [[String: Any]])
        for key in ["comboPositions", "comboTransactions"] { predictions[0].removeValue(forKey: key) }
        json["predictionProfiles"] = predictions
        let decoded = try Archive.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.scenes, scenes)
        XCTAssertEqual(decoded.portfolioProfiles[0], portfolio)
        XCTAssertEqual(decoded.portfolioProfiles[0].accountState, PortfolioAccountState())
        XCTAssertEqual(decoded.walletProfiles, [wallet])
        XCTAssertEqual(decoded.predictionProfiles, [prediction])
        XCTAssertNil(decoded.predictionProfiles[0].comboPositions)
        XCTAssertNil(decoded.predictionProfiles[0].comboTransactions)
        XCTAssertFalse(decoded.portfolioProfiles[0].positions.contains { $0.symbol == "USDC" })
        XCTAssertFalse(decoded.walletProfiles[0].holdings.contains { $0.symbol == "MUSD" })
        XCTAssertFalse((decoded.predictionProfiles[0].games ?? []).contains { $0.league == "Tennis" })
    }

    func testStarterTennisGameReferencesAnOpenSportsMarketAndSurvivesRoundTrip() throws {
        let profile = PredictionProfile.starter(for: UUID())
        let tennis = try XCTUnwrap(profile.games?.first { $0.league == "Tennis" })
        let market = try XCTUnwrap(profile.market(for: tennis.marketID))
        XCTAssertEqual(market.category, "Sports")
        XCTAssertTrue(market.isOpen)
        XCTAssertTrue(tennis.isValid)
        let restored = try JSONDecoder().decode(PredictionProfile.self, from: JSONEncoder().encode(profile))
        XCTAssertEqual(restored, profile)
        XCTAssertNil(restored.comboPositions)
        XCTAssertNil(restored.comboTransactions)
    }

    func testComboPricingAndCurrentValuationKeepPurchaseSnapshotUnchanged() throws {
        var profile = PredictionProfile.starter(for: UUID())
        profile.positions = []
        let legs = [PredictionComboLeg(marketID: profile.markets[0].id, outcome: .yes),
                    PredictionComboLeg(marketID: profile.markets[1].id, outcome: .no)]
        let prices = [profile.markets[0].yesPrice, profile.markets[1].noPrice]
        let questions = [profile.markets[0].question, profile.markets[1].question]
        let quote = PredictionComboQuote(legs: legs, questions: questions, legPrices: prices, totalCost: 25)
        let trade = PredictionComboTrade(legs: legs, questions: questions, legPrices: prices, totalCost: 25)
        XCTAssertTrue(trade.isValid)
        XCTAssertEqual(quote.combinedPrice, 0.64 * 0.28, accuracy: 0.000001)
        XCTAssertEqual(quote.potentialPayout, 25 / (0.64 * 0.28), accuracy: 0.000001)
        XCTAssertEqual(quote.multiplier, 1 / (0.64 * 0.28), accuracy: 0.000001)
        XCTAssertEqual(trade.shares, quote.potentialPayout)
        XCTAssertEqual(trade.entryCost, 25)
        profile.comboPositions = [trade]
        profile.comboTransactions = [trade]
        XCTAssertEqual(profile.positionsValue, 25, accuracy: 0.000001)
        profile.markets[0].yesPrice = 0.5
        profile.markets[1].yesPrice = 0.8
        profile.markets[0].question = "An edited question"
        XCTAssertEqual(profile.value(of: trade), trade.shares * 0.5 * 0.2, accuracy: 0.000001)
        XCTAssertEqual(profile.positionsValue, profile.value(of: trade))
        XCTAssertEqual(profile.total(cash: 975), 975 + trade.shares * 0.5 * 0.2, accuracy: 0.000001)
        XCTAssertEqual(profile.comboPositions, [trade])
        XCTAssertEqual(profile.comboTransactions, [trade])
        let restored = try JSONDecoder().decode(PredictionProfile.self, from: JSONEncoder().encode(profile))
        XCTAssertEqual(restored, profile)
        XCTAssertEqual(restored.comboTransactions?[0].questions, questions)
        XCTAssertEqual(restored.comboTransactions?[0].legPrices, prices)
        profile.markets[0].yesPrice = 0
        XCTAssertTrue(profile.isValid)
        XCTAssertEqual(profile.positionsValue, 0)
    }

    func testComboTradeRejectsMalformedLegsPricesCostsAndOverflow() {
        let profile = PredictionProfile.starter(for: UUID())
        let original = validCombo(for: profile)
        XCTAssertTrue(original.isValid)
        var trade = original
        trade.legs[1].marketID = trade.legs[0].marketID
        trade.legs[1].outcome = .no
        XCTAssertFalse(trade.isValid)
        trade = original
        trade.legs.removeLast()
        trade.questions.removeLast()
        trade.legPrices.removeLast()
        XCTAssertFalse(trade.isValid)
        trade = original
        trade.legs = (0..<9).map { _ in PredictionComboLeg(marketID: UUID(), outcome: .yes) }
        trade.questions = Array(repeating: "Question", count: 9)
        trade.legPrices = Array(repeating: 0.5, count: 9)
        XCTAssertFalse(trade.isValid)
        trade = original
        trade.questions.removeLast()
        XCTAssertFalse(trade.isValid)
        trade = original
        trade.legPrices.removeLast()
        XCTAssertFalse(trade.isValid)
        trade = original
        trade.questions[0] = " "
        XCTAssertFalse(trade.isValid)
        for price in [0, 1, -0.1, 1.1, Double.nan, .infinity] {
            trade = original
            trade.legPrices[0] = price
            XCTAssertFalse(trade.isValid)
        }
        for cost in [0, 0.001, -1, 1_000_000_001, Double.nan, .infinity] {
            trade = original
            trade.totalCost = cost
            XCTAssertFalse(trade.isValid)
        }
        trade = original
        trade.totalCost = 1_000_000_000
        XCTAssertFalse(trade.isValid, "Potential payout must fit the quantity limit")
        trade = original
        trade.legPrices = [Double.leastNonzeroMagnitude, Double.leastNonzeroMagnitude]
        XCTAssertFalse(trade.isValid)
        trade = original
        trade.date = Date(timeIntervalSince1970: .infinity)
        XCTAssertFalse(trade.isValid)
    }

    func testPredictionProfileRejectsMissingComboReferencesDuplicateIDsAndPositionLimit() {
        var profile = PredictionProfile.starter(for: UUID())
        let trade = validCombo(for: profile)
        profile.comboPositions = [trade]
        profile.comboTransactions = [trade]
        XCTAssertTrue(profile.isValid)
        profile.comboPositions = [trade, trade]
        XCTAssertFalse(profile.isValid)
        profile.comboPositions = [trade]
        profile.comboTransactions = [trade, trade]
        XCTAssertFalse(profile.isValid)
        profile.comboTransactions = [trade]
        profile.markets.removeFirst()
        profile.positions = []
        XCTAssertFalse(profile.isValid)
        profile = .starter(for: UUID())
        profile.comboPositions = (0..<100).map { _ in validCombo(for: profile) }
        XCTAssertTrue(profile.isValid)
        let extraTrade = validCombo(for: profile)
        profile.comboPositions?.append(extraTrade)
        XCTAssertFalse(profile.isValid)
    }

    private func validCombo(for profile: PredictionProfile) -> PredictionComboTrade {
        PredictionComboTrade(legs: [PredictionComboLeg(marketID: profile.markets[0].id, outcome: .yes),
                                   PredictionComboLeg(marketID: profile.markets[1].id, outcome: .no)],
            questions: [profile.markets[0].question, profile.markets[1].question],
            legPrices: [profile.markets[0].yesPrice, profile.markets[1].noPrice], totalCost: 25)
    }

    func testCommerceLineItemSnapshotsRoundTripWithoutCatalogReferencesAndLegacyFieldsDefaultToNil() throws {
        let scene = StudioScene.examples[0]
        var profile = CommerceProfile.starter(for: scene.id)
        let product = profile.products[0]
        let items = [CommerceOrderLineItem(productID: product.id, title: product.title, variant: "Natural",
            unitPrice: product.price, quantity: 2, symbol: product.symbol)]
        var event = SceneEvent(sceneID: scene.id, kind: .order, amount: 78, detail: "Two totes")
        event.itemCount = 2
        event.lineItems = items
        let order = CommerceOrder(id: event.id, number: 1029, customer: "Taylor", itemCount: 2,
            total: 78, date: event.date, fulfillment: .unfulfilled, isPaid: true, lineItems: items)
        profile.initialOrders = [order]
        profile.products = []
        let archive = Archive(scenes: [scene], events: [event], activeID: scene.id, commerceProfiles: [profile])
        let restored = try Archive.decode(archive.encoded())
        XCTAssertEqual(restored.events, [event])
        XCTAssertEqual(restored.commerceProfiles, [profile])
        XCTAssertEqual(restored.commerceProfiles[0].initialOrders[0].lineItems, items)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: archive.encoded()) as? [String: Any])
        var events = try XCTUnwrap(json["events"] as? [[String: Any]])
        events[0].removeValue(forKey: "lineItems")
        json["events"] = events
        var profiles = try XCTUnwrap(json["commerceProfiles"] as? [[String: Any]])
        var orders = try XCTUnwrap(profiles[0]["initialOrders"] as? [[String: Any]])
        orders[0].removeValue(forKey: "lineItems")
        profiles[0]["initialOrders"] = orders
        json["commerceProfiles"] = profiles
        let legacy = try Archive.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(legacy.scenes, [scene])
        XCTAssertNil(legacy.events[0].lineItems)
        XCTAssertNil(legacy.commerceProfiles[0].initialOrders[0].lineItems)
        XCTAssertEqual(legacy.events[0].amount, event.amount)
        XCTAssertEqual(legacy.commerceProfiles[0].initialOrders[0].total, order.total)
    }

    func testCommerceLineItemsValidateQuantitiesFinitePricesAndMatchingTotals() {
        let original = CommerceOrderLineItem(title: "Tote", unitPrice: 0.1, quantity: 3, symbol: "bag.fill")
        XCTAssertTrue(original.isValid)
        XCTAssertTrue(CommerceOrderLineItem.valid([original], itemCount: 3, total: 0.3))
        XCTAssertFalse(CommerceOrderLineItem.valid([original], itemCount: 2, total: 0.3))
        XCTAssertFalse(CommerceOrderLineItem.valid([original], itemCount: 3, total: 0.3001))
        XCTAssertFalse(CommerceOrderLineItem.valid([], itemCount: 0, total: 0))
        XCTAssertFalse(CommerceOrderLineItem.valid(Array(repeating: original, count: 101), itemCount: 303, total: 30.3))
        for quantity in [-1, 0, 1001, Int.max] {
            var item = original
            item.quantity = quantity
            XCTAssertFalse(item.isValid)
        }
        for price in [-1, 1_000_000_001, Double.nan, .infinity] {
            var item = original
            item.unitPrice = price
            XCTAssertFalse(item.isValid)
        }
        var item = original
        item.unitPrice = 1_000_000_000
        XCTAssertFalse(item.isValid)
        item = original
        item.title = " "
        XCTAssertFalse(item.isValid)
        item = original
        item.variant = " "
        XCTAssertFalse(item.isValid)
        item = original
        item.symbol = ""
        XCTAssertFalse(item.isValid)
        var event = SceneEvent(sceneID: UUID(), kind: .order, amount: 0.3, detail: "Order")
        event.itemCount = 3
        event.lineItems = [original]
        XCTAssertTrue(event.isValid)
        event.amount = 0.4
        XCTAssertFalse(event.isValid)
        event.amount = 0.3
        event.kind = .deposit
        XCTAssertFalse(event.isValid)
    }

    func testBankProductDefaultsPreserveLegacySavingsAndExplicitEmptyProductsStayEmpty() throws {
        for theme in BankTheme.allCases {
            var profile = BankProfile.starter(for: UUID())
            profile.theme = theme
            profile.savings = 777.5
            var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(profile)) as? [String: Any])
            json.removeValue(forKey: "products")
            let decoded = try JSONDecoder().decode(BankProfile.self, from: JSONSerialization.data(withJSONObject: json))
            XCTAssertEqual(decoded, profile)
            XCTAssertNil(decoded.products)
            XCTAssertEqual(decoded.referenceProducts, BankProduct.starters(for: theme))
            XCTAssertTrue(decoded.referenceProducts.allSatisfy(\.isValid))
        }
        var profile = BankProfile.starter(for: UUID())
        profile.theme = .citi
        profile.products = []
        let restored = try JSONDecoder().decode(BankProfile.self, from: JSONEncoder().encode(profile))
        XCTAssertEqual(restored.products, [])
        XCTAssertTrue(restored.referenceProducts.isEmpty)
    }

    func testBankProductValidationRejectsAmountsBadSuffixesDuplicatesAndProductOverflow() throws {
        let original = try XCTUnwrap(BankProduct.starters(for: .citi).first)
        XCTAssertEqual(original.rewardsUnit, "points")
        XCTAssertTrue(original.isValid)
        for amount in [-1, 1_000_000_001, Double.nan, .infinity] {
            var product = original
            product.balance = amount
            XCTAssertFalse(product.isValid)
            product = original
            product.minimumPayment = amount
            XCTAssertFalse(product.isValid)
            product = original
            product.rewards = amount
            XCTAssertFalse(product.isValid)
        }
        for suffix in ["123", "12345", "abcd", "12 4"] {
            var product = original
            product.suffix = suffix
            XCTAssertFalse(product.isValid)
        }
        var product = original
        product.name = " "
        XCTAssertFalse(product.isValid)
        product = original
        product.rewardsUnit = String(repeating: "x", count: 21)
        XCTAssertFalse(product.isValid)
        var profile = BankProfile.starter(for: UUID())
        profile.products = [original, original]
        XCTAssertFalse(profile.isValid)
        profile.products = (0..<20).map { _ in
            var copy = original
            copy.id = UUID()
            return copy
        }
        XCTAssertTrue(profile.isValid)
        product = original
        product.id = UUID()
        profile.products?.append(product)
        XCTAssertFalse(profile.isValid)
    }
}


extension MarketModelTests {
    func testTennisMetadataRejectsUnpairedScoresAndMalformedPointsAndRanks() throws {
        let seed = try XCTUnwrap(PredictionProfile.starter(for: UUID()).games?.first { $0.league == "Tennis" })
        XCTAssertEqual(seed.homeSetScores, [6, 4])
        XCTAssertEqual(seed.awaySetScores, [2, 1])
        XCTAssertTrue(seed.isValid)
        var game = seed
        game.awaySetScores = nil
        XCTAssertFalse(game.isValid)
        game = seed; game.awaySetScores = [2]
        XCTAssertFalse(game.isValid)
        game = seed; game.homeSetScores = [6, -1]
        XCTAssertFalse(game.isValid)
        game = seed; game.homePoint = "45"
        XCTAssertFalse(game.isValid)
        game = seed; game.awayRank = 0
        XCTAssertFalse(game.isValid)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(seed)) as? [String: Any])
        for key in ["homeSetScores", "awaySetScores", "homePoint", "awayPoint", "homeRank", "awayRank"] {
            json.removeValue(forKey: key)
        }
        let old = try JSONDecoder().decode(PredictionGame.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(old.homeSetScores)
        XCTAssertNil(old.awaySetScores)
        XCTAssertNil(old.homePoint)
        XCTAssertNil(old.homeRank)
        XCTAssertEqual(old.homeScore, seed.homeScore)
        XCTAssertEqual(old.awayScore, seed.awayScore)
        XCTAssertTrue(old.isValid)
    }
}
