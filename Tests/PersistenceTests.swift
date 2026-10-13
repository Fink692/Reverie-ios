import XCTest
@testable import Reverie

@MainActor final class PersistenceTests: XCTestCase {
    private func temporaryFile() -> URL { FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".json") }
    func testSavedSelectionAndEventSurviveReload() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = StudioStore(fileURL: file)
        store.select(store.scenes[1])
        let original = store.active
        let event = try XCTUnwrap(store.emit(kind: .deposit, amount: 80, detail: "Arrival"))
        let restored = StudioStore(fileURL: file)
        XCTAssertNil(restored.error)
        XCTAssertEqual(restored.activeID, original.id)
        XCTAssertEqual(restored.active.balance, original.balance + 80)
        XCTAssertEqual(restored.activity.first?.id, event.id)
    }
    func testDeletedSceneRemovesItsEventsAndPreservesAnActiveScene() {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = StudioStore(fileURL: file)
        let old = store.active
        _ = store.emit(kind: .order, amount: 50, detail: "Temporary")
        store.delete(old)
        XCTAssertFalse(store.scenes.contains { $0.id == old.id })
        XCTAssertFalse(store.events.contains { $0.sceneID == old.id })
        XCTAssertNotEqual(store.activeID, old.id)
        while store.scenes.count > 1 { store.delete(store.active) }
        store.delete(store.active)
        XCTAssertEqual(store.scenes.count, 1)
    }
    func testInvalidEventDoesNotMutateTotalsOrHistory() {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = StudioStore(fileURL: file)
        let original = store.active
        XCTAssertNil(store.emit(kind: .order, amount: .infinity, detail: "Invalid"))
        XCTAssertEqual(store.active, original)
        XCTAssertTrue(store.events.isEmpty)
    }
    func testCorruptSaveReportsErrorAndLeavesOriginalUntouched() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let corrupt = Data("not valid json".utf8)
        try corrupt.write(to: file)
        let store = StudioStore(fileURL: file)
        XCTAssertNotNil(store.error)
        XCTAssertFalse(store.scenes.isEmpty)
        XCTAssertEqual(try Data(contentsOf: file), corrupt)
    }
    func testFailedSaveDoesNotPretendAnEventWasRecorded() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let file = directory.appending(path: "session.json")
        let store = StudioStore(fileURL: file)
        let before = store.active
        XCTAssertNil(store.emit(kind: .order, amount: 50, detail: "Unsaved"))
        XCTAssertEqual(store.active, before)
        XCTAssertTrue(store.events.isEmpty)
        XCTAssertNotNil(store.error)
    }
    func testSavedCuePersistsAndCanBeRenamed() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = StudioStore(fileURL: file)
        var cue = NotificationPreset(name: "First name", kind: .order, amount: 49, detail: "Order", delay: 5, count: 3)
        XCTAssertTrue(store.savePreset(cue))
        cue.name = "Second name"
        XCTAssertTrue(store.savePreset(cue))
        let restored = StudioStore(fileURL: file)
        XCTAssertEqual(restored.presets, [cue])
    }
    func testInvalidImportLeavesCurrentSessionIntact() async throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = StudioStore(fileURL: file)
        let before = store.scenes
        let imported = await store.importSession(Data("broken".utf8))
        XCTAssertFalse(imported)
        XCTAssertEqual(store.scenes, before)
        XCTAssertNotNil(store.error)
    }

    func testPlaybackProfilesSurviveAnUnrelatedEventSave() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = StudioStore(fileURL: file)
        let commerceID = store.scenes[0].id
        let bankID = store.scenes[1].id
        XCTAssertTrue(store.preparePlayback(for: commerceID))
        var bank = store.bankProfile(for: bankID)
        bank.theme = .revolut
        XCTAssertTrue(store.updateBankProfile(bank))
        XCTAssertNotNil(store.emit(kind: .deposit, amount: 10, detail: "Income", sceneID: bankID))
        let restored = StudioStore(fileURL: file)
        XCTAssertEqual(restored.bankProfile(for: bankID).theme, .revolut)
        XCTAssertEqual(restored.commerceProfile(for: commerceID).products.count, 3)
    }
    func testNewOrderUsesCapturedSceneAndCustomerMetadata() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = StudioStore(fileURL: file)
        let scene = store.scenes[0]
        store.select(store.scenes[1])
        let event = try XCTUnwrap(store.addCommerceOrder(sceneID: scene.id, customer: "Taylor", itemCount: 4, total: 100))
        XCTAssertEqual(store.activeID, store.scenes[1].id)
        let order = try XCTUnwrap(store.commerceOrders(for: scene.id).first { $0.id == event.id })
        XCTAssertEqual(order.customer, "Taylor")
        XCTAssertEqual(order.itemCount, 4)
        XCTAssertEqual(order.number, 1001 + scene.orders)
        XCTAssertTrue(store.setOrderStatus(orderID: order.id, sceneID: scene.id, status: .fulfilled))
        XCTAssertEqual(store.commerceOrders(for: scene.id).first { $0.id == order.id }?.fulfillment, .fulfilled)
    }

    func testSavingsTransfersUseCapturedAccountAndPersistConservedFunds() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = StudioStore(fileURL: file)
        let activeBefore = store.active
        let bankBefore = store.scenes[1]
        let savingsBefore = store.bankProfile(for: bankBefore.id).savings
        XCTAssertTrue(store.bankProfiles.isEmpty)

        XCTAssertTrue(store.transferSavings(sceneID: bankBefore.id, amount: 125.5, toSavings: true))
        var expectedBank = bankBefore
        expectedBank.balance -= 125.5
        XCTAssertEqual(store.scenes.first { $0.id == bankBefore.id }, expectedBank)
        XCTAssertEqual(store.bankProfile(for: bankBefore.id).savings, savingsBefore + 125.5)
        XCTAssertEqual(expectedBank.balance + store.bankProfile(for: bankBefore.id).savings,
                       bankBefore.balance + savingsBefore, accuracy: 0.000001)
        XCTAssertEqual(store.active, activeBefore)
        let outgoing = try XCTUnwrap(store.events.first)
        XCTAssertEqual(outgoing.sceneID, bankBefore.id)
        XCTAssertEqual(outgoing.kind, .payment)
        XCTAssertEqual(outgoing.amount, 125.5)
        XCTAssertEqual(outgoing.savingsTransfer, true)

        let restored = StudioStore(fileURL: file)
        XCTAssertEqual(restored.scenes.first { $0.id == bankBefore.id }, expectedBank)
        XCTAssertEqual(restored.bankProfile(for: bankBefore.id).savings, savingsBefore + 125.5)
        XCTAssertEqual(restored.events, [outgoing])
        XCTAssertTrue(restored.transferSavings(sceneID: bankBefore.id, amount: 125.5, toSavings: false))
        XCTAssertEqual(restored.scenes.first { $0.id == bankBefore.id }, bankBefore)
        XCTAssertEqual(restored.bankProfile(for: bankBefore.id).savings, savingsBefore)
        XCTAssertEqual(restored.active, activeBefore)
        XCTAssertEqual(restored.events.map(\.kind), [.deposit, .payment])
        XCTAssertTrue(restored.events.allSatisfy { $0.sceneID == bankBefore.id && $0.savingsTransfer == true })
        let finalReload = StudioStore(fileURL: file)
        XCTAssertEqual(finalReload.scenes, restored.scenes)
        XCTAssertEqual(finalReload.bankProfiles, restored.bankProfiles)
        XCTAssertEqual(finalReload.events, restored.events)
    }

    func testSavingsTransferRejectsInvalidAmountsSourcesAndSceneReferences() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = StudioStore(fileURL: file)
        let bank = store.scenes[1]
        XCTAssertTrue(store.preparePlayback(for: bank.id))
        for amount in [Double.nan, .infinity, -.infinity, -1, 0, 0.001, 1_000_000_001] {
            for toSavings in [true, false] {
                try assertRejectedSavingsTransfer(store, sceneID: bank.id, amount: amount, toSavings: toSavings, fileURL: file)
            }
        }
        try assertRejectedSavingsTransfer(store, sceneID: bank.id, amount: bank.balance + 1, toSavings: true, fileURL: file)
        try assertRejectedSavingsTransfer(store, sceneID: bank.id, amount: store.bankProfile(for: bank.id).savings + 1, toSavings: false, fileURL: file)
        try assertRejectedSavingsTransfer(store, sceneID: store.scenes[0].id, amount: 1, toSavings: true, fileURL: file)
        try assertRejectedSavingsTransfer(store, sceneID: UUID(), amount: 1, toSavings: false, fileURL: file)
    }

    func testSavingsTransferRejectsDestinationOverflowWithoutChangingSavedSession() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = StudioStore(fileURL: file)
        var bank = store.scenes[1]
        var profile = store.bankProfile(for: bank.id)
        profile.savings = 1_000_000_000
        XCTAssertTrue(store.updateBankProfile(profile))
        try assertRejectedSavingsTransfer(store, sceneID: bank.id, amount: 0.01, toSavings: true, fileURL: file)
        bank.balance = 1_000_000_000
        XCTAssertTrue(store.update(bank))
        try assertRejectedSavingsTransfer(store, sceneID: bank.id, amount: 0.01, toSavings: false, fileURL: file)
    }

    func testFailedSavingsTransferSaveDoesNotPartiallyCreateProfileOrHistory() throws {
        let missingDirectory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let file = missingDirectory.appending(path: "session.json")
        let store = StudioStore(fileURL: file)
        let before = try XCTUnwrap(store.exportData())
        XCTAssertFalse(store.transferSavings(sceneID: store.scenes[1].id, amount: 10, toSavings: true))
        XCTAssertEqual(store.exportData(), before)
        XCTAssertTrue(store.bankProfiles.isEmpty)
        XCTAssertTrue(store.events.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertNotNil(store.error)
    }

    func testOrderPaymentOverridesPersistAndPreserveFulfillmentWithoutReapplyingTotals() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = StudioStore(fileURL: file)
        let commerceBefore = store.scenes[0]
        XCTAssertTrue(store.preparePlayback(for: commerceBefore.id))
        let order = try XCTUnwrap(store.commerceOrders(for: commerceBefore.id).first)
        XCTAssertTrue(order.isPaid)
        XCTAssertTrue(store.setOrderPaid(orderID: order.id, sceneID: commerceBefore.id, isPaid: false))
        let restored = StudioStore(fileURL: file)
        XCTAssertEqual(restored.commerceOrders(for: commerceBefore.id).first { $0.id == order.id }?.isPaid, false)
        XCTAssertTrue(restored.setOrderStatus(orderID: order.id, sceneID: commerceBefore.id, status: .fulfilled))
        XCTAssertTrue(restored.setOrderPaid(orderID: order.id, sceneID: commerceBefore.id, isPaid: true))
        let finalReload = StudioStore(fileURL: file)
        let updatedOrder = try XCTUnwrap(finalReload.commerceOrders(for: commerceBefore.id).first { $0.id == order.id })
        XCTAssertTrue(updatedOrder.isPaid)
        XCTAssertEqual(updatedOrder.fulfillment, .fulfilled)
        XCTAssertEqual(finalReload.scenes.first { $0.id == commerceBefore.id }, commerceBefore)
        XCTAssertTrue(finalReload.events.isEmpty)
        let beforeUnknown = try XCTUnwrap(finalReload.exportData())
        let savedBytes = try Data(contentsOf: file)
        XCTAssertFalse(finalReload.setOrderPaid(orderID: UUID(), sceneID: commerceBefore.id, isPaid: false))
        XCTAssertEqual(finalReload.exportData(), beforeUnknown)
        XCTAssertEqual(try Data(contentsOf: file), savedBytes)
    }

    private func assertRejectedSavingsTransfer(_ store: StudioStore, sceneID: UUID, amount: Double, toSavings: Bool,
                                               fileURL: URL, file: StaticString = #filePath, line: UInt = #line) throws {
        let before = try XCTUnwrap(store.exportData())
        let savedBytes = try Data(contentsOf: fileURL)
        XCTAssertFalse(store.transferSavings(sceneID: sceneID, amount: amount, toSavings: toSavings), file: file, line: line)
        XCTAssertEqual(store.exportData(), before, file: file, line: line)
        XCTAssertEqual(try Data(contentsOf: fileURL), savedBytes, file: file, line: line)
    }

}

extension PersistenceTests {
    func testPortfolioAccountPresentationPersistsWithoutChangingCashAssetsOrHistory() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = StudioStore(fileURL: file)
        let scene = try XCTUnwrap(store.scenes.first { $0.kind == .portfolio })
        let original = store.portfolioProfile(for: scene.id)
        var state = original.accountState
        state.twoStepEnabled = true
        state.autopay = true
        state.locked = true
        state.cardBalance = 125.5
        state.availableCredit = 3000
        state.cashBack = 37
        state.monthCashBack = 22
        state.statementAmount = 370
        state.chequingInterestRate = 2.25
        state.monthlyInterest = 37.5
        state.highYieldCashEarnings = 1000
        state.iraMatchEarnings = 225
        XCTAssertTrue(store.updatePortfolioAccountState(sceneID: scene.id, state: state))
        var expected = original
        expected.accountState = state
        XCTAssertEqual(store.portfolioProfile(for: scene.id), expected)
        XCTAssertEqual(store.scenes.first { $0.id == scene.id }, scene)
        XCTAssertEqual(expected.total(cash: scene.balance), original.total(cash: scene.balance))
        XCTAssertTrue(store.events.isEmpty)
        let restored = StudioStore(fileURL: file)
        XCTAssertNil(restored.error)
        XCTAssertEqual(restored.portfolioProfile(for: scene.id), expected)
        XCTAssertEqual(restored.scenes, store.scenes)
        state.availableCredit = .nan
        try assertRejectedSessionMutation(restored, fileURL: file) {
            restored.updatePortfolioAccountState(sceneID: scene.id, state: state)
        }
        try assertRejectedSessionMutation(restored, fileURL: file) {
            restored.updatePortfolioAccountState(sceneID: restored.scenes[0].id, state: PortfolioAccountState())
        }
    }

    func testAddingMissingCoinbaseUSDCSeedsZeroUnitsAndTradesWithoutCreditingCash() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = StudioStore(fileURL: file)
        let scene = try XCTUnwrap(store.scenes.first { $0.kind == .portfolio })
        var legacy = PortfolioProfile.starter(for: scene.id, theme: .coinbase)
        legacy.positions.removeAll { $0.symbol == "USDC" }
        XCTAssertTrue(store.updatePortfolioProfile(legacy))
        XCTAssertTrue(store.addPortfolioMarketAsset(sceneID: scene.id, symbol: "usdc"))
        let added = store.portfolioProfile(for: scene.id)
        let usdc = try XCTUnwrap(added.positions.first { $0.symbol == "USDC" })
        XCTAssertEqual(usdc.units, 0)
        XCTAssertEqual(usdc.price, 1)
        XCTAssertEqual(Array(added.positions.dropLast()), legacy.positions)
        XCTAssertEqual(added.total(cash: scene.balance), legacy.total(cash: scene.balance))
        XCTAssertEqual(store.scenes.first { $0.id == scene.id }, scene)
        let beforeDuplicate = store.exportData()
        let savedBeforeDuplicate = try Data(contentsOf: file)
        XCTAssertTrue(store.addPortfolioMarketAsset(sceneID: scene.id, symbol: "UsDc"))
        XCTAssertEqual(store.exportData(), beforeDuplicate)
        XCTAssertEqual(try Data(contentsOf: file), savedBeforeDuplicate)
        let buy = try XCTUnwrap(store.executeMarketTrade(sceneID: scene.id, assetID: usdc.id, side: .buy, units: 125))
        let cashAfterBuy = try XCTUnwrap(store.scenes.first { $0.id == scene.id }).balance
        XCTAssertEqual(buy.total, 125)
        XCTAssertEqual(cashAfterBuy, scene.balance - 125)
        XCTAssertEqual(store.portfolioProfile(for: scene.id).total(cash: cashAfterBuy), legacy.total(cash: scene.balance), accuracy: 0.000001)
        let received = try XCTUnwrap(store.executePortfolioTransfer(sceneID: scene.id, assetID: usdc.id,
            kind: .receive, quantity: 25, address: "0x0000000000000000000000000000000000000011"))
        let finalProfile = store.portfolioProfile(for: scene.id)
        XCTAssertEqual(received.network, "Ethereum")
        XCTAssertEqual(finalProfile.positions.first { $0.id == usdc.id }?.units, 150)
        XCTAssertEqual(store.scenes.first { $0.id == scene.id }?.balance, cashAfterBuy)
        XCTAssertTrue(store.events.isEmpty)
        let restored = StudioStore(fileURL: file)
        XCTAssertEqual(restored.portfolioProfile(for: scene.id), finalProfile)
        XCTAssertEqual(restored.scenes, store.scenes)
        for (sceneID, symbol) in [(scene.id, "UNAVAILABLE"), (UUID(), "AAPL"), (store.scenes[0].id, "AAPL")] {
            try assertRejectedSessionMutation(store, fileURL: file) {
                store.addPortfolioMarketAsset(sceneID: sceneID, symbol: symbol)
            }
        }
    }

    func testComboQuoteIsReadOnlyAndPurchaseConservesCashValueWithPersistedSnapshots() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = StudioStore(fileURL: file)
        let scene = try XCTUnwrap(store.scenes.first { $0.kind == .prediction })
        XCTAssertTrue(store.preparePlayback(for: scene.id))
        let original = store.predictionProfile(for: scene.id)
        let activeID = store.activeID
        let legs = comboLegs(for: original)
        let memoryBeforeQuote = store.exportData()
        let diskBeforeQuote = try Data(contentsOf: file)
        let quote = try XCTUnwrap(store.quotePredictionCombo(sceneID: scene.id, legs: legs, cost: 25))
        XCTAssertEqual(quote.legPrices, [original.markets[0].yesPrice, original.markets[1].noPrice])
        XCTAssertEqual(quote.combinedPrice, 0.64 * 0.28, accuracy: 0.000001)
        XCTAssertEqual(quote.potentialPayout, 25 / (0.64 * 0.28), accuracy: 0.000001)
        XCTAssertEqual(store.exportData(), memoryBeforeQuote)
        XCTAssertEqual(try Data(contentsOf: file), diskBeforeQuote)
        let trade = try XCTUnwrap(store.tradePredictionCombo(sceneID: scene.id, legs: legs, cost: 25, expectedQuote: quote))
        let purchased = store.predictionProfile(for: scene.id)
        let updatedScene = try XCTUnwrap(store.scenes.first { $0.id == scene.id })
        var expectedScene = scene
        expectedScene.balance -= 25
        XCTAssertEqual(updatedScene, expectedScene)
        XCTAssertEqual(purchased.positions, original.positions)
        XCTAssertEqual(purchased.transactions, original.transactions)
        XCTAssertEqual(purchased.comboPositions, [trade])
        XCTAssertEqual(purchased.comboTransactions, [trade])
        XCTAssertEqual(trade.legPrices, quote.legPrices)
        XCTAssertEqual(trade.questions, quote.questions)
        XCTAssertEqual(trade.totalCost, 25)
        XCTAssertEqual(purchased.value(of: trade), 25, accuracy: 0.000001)
        XCTAssertEqual(purchased.total(cash: updatedScene.balance), original.total(cash: scene.balance), accuracy: 0.000001)
        XCTAssertEqual(store.activeID, activeID)
        XCTAssertTrue(store.events.isEmpty)
        var edited = purchased
        edited.markets[0].yesPrice = 0.55
        edited.markets[1].yesPrice = 0.8
        edited.markets[0].question = "Updated local market question"
        XCTAssertTrue(store.updatePredictionProfile(edited))
        XCTAssertEqual(store.predictionProfile(for: scene.id).comboPositions, [trade])
        XCTAssertEqual(store.predictionProfile(for: scene.id).comboTransactions, [trade])
        XCTAssertEqual(edited.value(of: trade), trade.shares * 0.55 * 0.2, accuracy: 0.000001)
        let restored = StudioStore(fileURL: file)
        XCTAssertNil(restored.error)
        XCTAssertEqual(restored.predictionProfile(for: scene.id), edited)
        XCTAssertEqual(restored.scenes.first { $0.id == scene.id }, updatedScene)
        XCTAssertEqual(restored.activeID, activeID)
    }

    func testComboRejectsInvalidInputsAndStaleQuoteWithoutChangingSavedSession() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = StudioStore(fileURL: file)
        let scene = try XCTUnwrap(store.scenes.first { $0.kind == .prediction })
        XCTAssertTrue(store.preparePlayback(for: scene.id))
        let profile = store.predictionProfile(for: scene.id)
        let legs = comboLegs(for: profile)
        for cost in [0, 0.001, -1, Double.nan, .infinity, 1_000_000_001, scene.balance + 1] {
            try assertRejectedSessionMutation(store, fileURL: file) {
                store.tradePredictionCombo(sceneID: scene.id, legs: legs, cost: cost) != nil
            }
        }
        let duplicate = [legs[0], PredictionComboLeg(marketID: legs[0].marketID, outcome: .no)]
        let tooMany = (0..<9).map { _ in PredictionComboLeg(marketID: UUID(), outcome: .yes) }
        for invalidLegs in [[], [legs[0]], duplicate, tooMany,
                            [legs[0], PredictionComboLeg(marketID: UUID(), outcome: .yes)]] {
            try assertRejectedSessionMutation(store, fileURL: file) {
                store.tradePredictionCombo(sceneID: scene.id, legs: invalidLegs, cost: 25) != nil
            }
        }
        for sceneID in [UUID(), store.scenes[0].id] {
            try assertRejectedSessionMutation(store, fileURL: file) {
                store.tradePredictionCombo(sceneID: sceneID, legs: legs, cost: 25) != nil
            }
        }
        let staleQuote = try XCTUnwrap(store.quotePredictionCombo(sceneID: scene.id, legs: legs, cost: 25))
        var edited = profile
        edited.markets[0].yesPrice = 0.5
        XCTAssertTrue(store.updatePredictionProfile(edited))
        try assertRejectedSessionMutation(store, fileURL: file) {
            store.tradePredictionCombo(sceneID: scene.id, legs: legs, cost: 25, expectedQuote: staleQuote) != nil
        }
        XCTAssertNotNil(store.quotePredictionCombo(sceneID: scene.id, legs: legs, cost: 25))
        edited.markets[0].closeDate = .distantPast
        XCTAssertTrue(store.updatePredictionProfile(edited))
        try assertRejectedSessionMutation(store, fileURL: file) {
            store.tradePredictionCombo(sceneID: scene.id, legs: legs, cost: 25) != nil
        }
        edited.markets[0].closeDate = .distantFuture
        edited.markets[0].yesPrice = 1e-12
        edited.markets[1].yesPrice = 1 - 1e-12
        XCTAssertTrue(store.updatePredictionProfile(edited))
        try assertRejectedSessionMutation(store, fileURL: file) {
            store.tradePredictionCombo(sceneID: scene.id, legs: legs, cost: 25) != nil
        }
    }

    func testFailedNewProfileAndItemizedOrderSavesDoNotCreateProfilesOrChangeCash() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let file = directory.appending(path: "session.json")
        let store = StudioStore(fileURL: file)
        let portfolio = try XCTUnwrap(store.scenes.first { $0.kind == .portfolio })
        let prediction = try XCTUnwrap(store.scenes.first { $0.kind == .prediction })
        let bank = try XCTUnwrap(store.scenes.first { $0.kind == .banking })
        let commerce = try XCTUnwrap(store.scenes.first { $0.kind == .commerce })
        let legs = comboLegs(for: store.predictionProfile(for: prediction.id))
        let before = store.exportData()
        var state = PortfolioAccountState()
        state.twoStepEnabled = true
        XCTAssertFalse(store.updatePortfolioAccountState(sceneID: portfolio.id, state: state))
        XCTAssertEqual(store.exportData(), before)
        XCTAssertFalse(store.addPortfolioMarketAsset(sceneID: portfolio.id, symbol: "USDC"))
        XCTAssertEqual(store.exportData(), before)
        XCTAssertNil(store.tradePredictionCombo(sceneID: prediction.id, legs: legs, cost: 25))
        XCTAssertEqual(store.exportData(), before)
        XCTAssertFalse(store.updateBankProducts(sceneID: bank.id, products: BankProduct.starters(for: .citi)))
        XCTAssertEqual(store.exportData(), before)
        let items = [CommerceOrderLineItem(title: "Unsaved tote", unitPrice: 39, quantity: 2, symbol: "bag.fill")]
        XCTAssertNil(store.addCommerceOrder(sceneID: commerce.id, customer: "Taylor", lineItems: items))
        XCTAssertEqual(store.exportData(), before)
        XCTAssertTrue(store.portfolioProfiles.isEmpty)
        XCTAssertTrue(store.predictionProfiles.isEmpty)
        XCTAssertTrue(store.bankProfiles.isEmpty)
        XCTAssertTrue(store.commerceProfiles.isEmpty)
        XCTAssertTrue(store.events.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertNotNil(store.error)
    }

    func testItemizedCommerceOrderCapturesSceneAccountingAndSurvivesCatalogEditsAndDeletion() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = StudioStore(fileURL: file)
        let scene = try XCTUnwrap(store.scenes.first { $0.kind == .commerce })
        XCTAssertTrue(store.preparePlayback(for: scene.id))
        let profile = store.commerceProfile(for: scene.id)
        let tote = profile.products[0]
        let hoodie = profile.products[1]
        let items = [CommerceOrderLineItem(productID: tote.id, title: tote.title, variant: "Natural",
                        unitPrice: tote.price, quantity: 2, symbol: tote.symbol),
                     CommerceOrderLineItem(productID: hoodie.id, title: hoodie.title, variant: "Medium",
                        unitPrice: hoodie.price, quantity: 1, symbol: hoodie.symbol)]
        store.select(store.scenes[1])
        let activeBefore = store.active
        let event = try XCTUnwrap(store.addCommerceOrder(sceneID: scene.id, customer: "  Taylor  ", lineItems: items))
        XCTAssertEqual(event.lineItems, items)
        XCTAssertEqual(event.itemCount, 3)
        XCTAssertEqual(event.amount, 167)
        XCTAssertEqual(event.customerName, "Taylor")
        let updatedScene = try XCTUnwrap(store.scenes.first { $0.id == scene.id })
        XCTAssertEqual(updatedScene.balance, scene.balance + 167)
        XCTAssertEqual(updatedScene.sales, scene.sales + 167)
        XCTAssertEqual(updatedScene.orders, scene.orders + 1)
        XCTAssertEqual(updatedScene.audience, scene.audience)
        XCTAssertEqual(store.active, activeBefore)
        var edited = profile
        edited.products[0].title = "Renamed tote"
        edited.products[0].price = 999
        edited.products.removeAll { $0.id == hoodie.id }
        XCTAssertTrue(store.updateCommerceProfile(edited))
        XCTAssertTrue(store.setOrderStatus(orderID: event.id, sceneID: scene.id, status: .fulfilled))
        XCTAssertTrue(store.setOrderPaid(orderID: event.id, sceneID: scene.id, isPaid: false))
        let restored = StudioStore(fileURL: file)
        XCTAssertNil(restored.error)
        let order = try XCTUnwrap(restored.commerceOrders(for: scene.id).first { $0.id == event.id })
        XCTAssertEqual(order.lineItems, items)
        XCTAssertEqual(order.itemCount, 3)
        XCTAssertEqual(order.total, 167)
        XCTAssertEqual(order.fulfillment, .fulfilled)
        XCTAssertFalse(order.isPaid)
        XCTAssertEqual(restored.events.first { $0.id == event.id }?.lineItems, items)
        XCTAssertEqual(restored.scenes.first { $0.id == scene.id }, updatedScene)
        XCTAssertEqual(restored.active, activeBefore)
        XCTAssertEqual(restored.commerceProfile(for: scene.id).products, edited.products)
    }

    func testInvalidItemizedOrdersDoNotChangeCashOrderCountsOrSavedHistory() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = StudioStore(fileURL: file)
        let scene = try XCTUnwrap(store.scenes.first { $0.kind == .commerce })
        XCTAssertTrue(store.preparePlayback(for: scene.id))
        let original = CommerceOrderLineItem(title: "Tote", unitPrice: 39, quantity: 1, symbol: "bag.fill")
        var invalid = original
        invalid.quantity = 0
        var infinite = original
        infinite.unitPrice = .infinity
        var overflow = original
        overflow.unitPrice = 1_000_000_000
        overflow.quantity = 2
        var tooMany = original
        tooMany.quantity = 1000
        var expensive = original
        expensive.unitPrice = 1_000_000_000
        for items in [[], [invalid], [infinite], [overflow], [tooMany, original], [expensive, expensive]] {
            try assertRejectedSessionMutation(store, fileURL: file) {
                store.addCommerceOrder(sceneID: scene.id, customer: "Taylor", lineItems: items) != nil
            }
        }
        for customer in [" ", String(repeating: "x", count: 81)] {
            try assertRejectedSessionMutation(store, fileURL: file) {
                store.addCommerceOrder(sceneID: scene.id, customer: customer, lineItems: [original]) != nil
            }
        }
        for sceneID in [UUID(), store.scenes[1].id] {
            try assertRejectedSessionMutation(store, fileURL: file) {
                store.addCommerceOrder(sceneID: sceneID, customer: "Taylor", lineItems: [original]) != nil
            }
        }
        try assertRejectedSessionMutation(store, fileURL: file) {
            store.emit(kind: .order, amount: 40, detail: "Mismatched total", sceneID: scene.id,
                itemCount: 1, lineItems: [original]) != nil
        }
        try assertRejectedSessionMutation(store, fileURL: file) {
            store.emit(kind: .order, amount: 39, detail: "Mismatched quantity", sceneID: scene.id,
                itemCount: 2, lineItems: [original]) != nil
        }
    }

    func testBankProductEditsPersistWithoutCreditingCheckingSavingsOrHistory() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = StudioStore(fileURL: file)
        let scene = try XCTUnwrap(store.scenes.first { $0.kind == .banking })
        var profile = store.bankProfile(for: scene.id)
        profile.theme = .citi
        profile.savings = 777.5
        XCTAssertTrue(store.updateBankProfile(profile))
        var products = profile.referenceProducts
        products[0].balance = 1100.25
        products[0].rewards = 99000
        products[0].minimumPayment = 25
        products[0].paymentDue = "November 2"
        products[0].cardFrozen = true
        products.append(try XCTUnwrap(BankProduct.starters(for: .bankOfAmerica).first { $0.kind == .investment }))
        XCTAssertTrue(store.updateBankProducts(sceneID: scene.id, products: products))
        profile.products = products
        XCTAssertEqual(store.bankProfile(for: scene.id), profile)
        XCTAssertEqual(store.scenes.first { $0.id == scene.id }, scene)
        XCTAssertTrue(store.events.isEmpty)
        let restored = StudioStore(fileURL: file)
        XCTAssertEqual(restored.bankProfile(for: scene.id), profile)
        XCTAssertEqual(restored.scenes, store.scenes)
        try assertRejectedSessionMutation(restored, fileURL: file) {
            restored.updateBankProducts(sceneID: scene.id, products: [products[0], products[0]])
        }
        var invalid = products[0]
        invalid.rewards = .nan
        try assertRejectedSessionMutation(restored, fileURL: file) {
            restored.updateBankProducts(sceneID: scene.id, products: [invalid])
        }
        for sceneID in [UUID(), restored.scenes[0].id] {
            try assertRejectedSessionMutation(restored, fileURL: file) {
                restored.updateBankProducts(sceneID: sceneID, products: products)
            }
        }
        XCTAssertTrue(restored.updateBankProducts(sceneID: scene.id, products: []))
        let cleared = StudioStore(fileURL: file)
        XCTAssertEqual(cleared.bankProfile(for: scene.id).products, [])
        XCTAssertTrue(cleared.bankProfile(for: scene.id).referenceProducts.isEmpty)
        XCTAssertEqual(cleared.bankProfile(for: scene.id).savings, profile.savings)
        XCTAssertEqual(cleared.scenes.first { $0.id == scene.id }, scene)
    }

    private func comboLegs(for profile: PredictionProfile) -> [PredictionComboLeg] {
        [PredictionComboLeg(marketID: profile.markets[0].id, outcome: .yes),
         PredictionComboLeg(marketID: profile.markets[1].id, outcome: .no)]
    }

    private func assertRejectedSessionMutation(_ store: StudioStore, fileURL: URL,
                                               file: StaticString = #filePath, line: UInt = #line,
                                               _ operation: () -> Bool) throws {
        let memory = try XCTUnwrap(store.exportData(), file: file, line: line)
        let disk = try Data(contentsOf: fileURL)
        XCTAssertFalse(operation(), file: file, line: line)
        XCTAssertEqual(store.exportData(), memory, file: file, line: line)
        XCTAssertEqual(try Data(contentsOf: fileURL), disk, file: file, line: line)
    }

    func testStyledOrderAccountingAndSavedCueMetadataSurviveReload() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = StudioStore(fileURL: file)
        let scene = store.scenes[0]
        let event = try XCTUnwrap(store.emit(kind: .order, amount: 179.25, detail: "Weekend collection", sceneID: scene.id,
            customerName: "Morgan Hale", itemCount: 3, orderNumber: 2088, style: .shopifyOrder, customTitle: "Checkout completed"))
        XCTAssertEqual(event.orderNumber, 2088)
        XCTAssertEqual(event.customerName, "Morgan Hale")
        XCTAssertEqual(event.itemCount, 3)
        XCTAssertEqual(event.title, "Checkout completed")
        XCTAssertEqual(store.active.balance, scene.balance + 179.25)
        XCTAssertEqual(store.active.orders, scene.orders + 1)
        var cue = NotificationPreset(name: "Weekend checkout", kind: .order, amount: 179.25,
            detail: "Weekend collection", delay: 300, count: 2)
        cue.style = .shopifyOrder
        cue.interval = 30
        cue.customerName = "Morgan Hale"
        cue.itemCount = 3
        cue.orderNumber = 2088
        cue.customTitle = "Checkout completed"
        XCTAssertTrue(store.savePreset(cue))
        let savedBytes = try Data(contentsOf: file)
        var invalid = cue
        invalid.interval = .infinity
        XCTAssertFalse(store.savePreset(invalid))
        invalid = cue
        invalid.itemCount = 0
        XCTAssertFalse(store.savePreset(invalid))
        invalid = cue
        invalid.kind = .payment
        XCTAssertFalse(store.savePreset(invalid))
        XCTAssertEqual(store.presets, [cue])
        XCTAssertEqual(try Data(contentsOf: file), savedBytes)
        let restored = StudioStore(fileURL: file)
        XCTAssertNil(restored.error)
        XCTAssertEqual(restored.events, [event])
        XCTAssertEqual(restored.presets, [cue])
        XCTAssertEqual(restored.active, store.active)
    }

    func testNonAccountingOrUnavailableStylesCannotMutateTheDashboard() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = StudioStore(fileURL: file)
        store.save()
        let memory = store.exportData()
        let disk = try Data(contentsOf: file)
        XCTAssertNil(store.emit(kind: NotificationStyle.custom.eventKind, amount: 25, detail: "Fictional milestone",
            style: .custom, customTitle: "Milestone reached"))
        XCTAssertNil(store.emit(kind: .payment, amount: 25, detail: "Wrong kind", style: .shopifyOrder))
        XCTAssertNil(store.emit(kind: .order, amount: 25, detail: "Wrong scene", sceneID: store.scenes[1].id, style: .shopifyOrder))
        XCTAssertNil(store.emit(kind: .order, amount: 25, detail: "Invalid items", itemCount: 0, style: .shopifyOrder))
        XCTAssertNil(store.emit(kind: .order, amount: 25, detail: "Invalid title", style: .shopifyOrder, customTitle: String(repeating: "x", count: 81)))
        XCTAssertEqual(store.exportData(), memory)
        XCTAssertEqual(try Data(contentsOf: file), disk)
    }

    func testCoinbaseTransfersChangeCryptoUnitsAndBasisWithoutChangingCash() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = StudioStore(fileURL: file)
        let scene = try XCTUnwrap(store.scenes.first { $0.kind == .portfolio })
        let profile = PortfolioProfile.starter(for: scene.id, theme: .coinbase)
        XCTAssertTrue(store.updatePortfolioProfile(profile))
        let asset = profile.positions[0]
        let address = "1111111111111111111114oLvT2"
        let received = try XCTUnwrap(store.executePortfolioTransfer(sceneID: scene.id, assetID: asset.id,
            kind: .receive, quantity: 0.02, address: address))
        let afterReceive = store.portfolioProfile(for: scene.id).positions[0]
        XCTAssertEqual(afterReceive.units, asset.units + 0.02, accuracy: 0.000001)
        XCTAssertEqual(afterReceive.averageCost, (asset.costBasis + received.total) / afterReceive.units, accuracy: 0.000001)
        let sent = try XCTUnwrap(store.executePortfolioTransfer(sceneID: scene.id, assetID: asset.id,
            kind: .send, quantity: 0.01, address: address))
        let updated = store.portfolioProfile(for: scene.id)
        XCTAssertEqual(updated.positions[0].units, asset.units + 0.01, accuracy: 0.000001)
        XCTAssertEqual(updated.positions[0].averageCost, afterReceive.averageCost)
        XCTAssertEqual(updated.transfers.map(\.id), [sent.id, received.id])
        XCTAssertTrue(updated.transactions.isEmpty)
        XCTAssertTrue(store.events.isEmpty)
        XCTAssertEqual(store.scenes.first { $0.id == scene.id }, scene)
        XCTAssertEqual(store.activeID, StudioScene.examples[0].id)
        let before = store.exportData()
        XCTAssertNil(store.executePortfolioTransfer(sceneID: scene.id, assetID: asset.id, kind: .send,
            quantity: asset.units + 1, address: address))
        XCTAssertNil(store.executePortfolioTransfer(sceneID: scene.id, assetID: asset.id, kind: .receive,
            quantity: 0.1, address: "bad address"))
        XCTAssertEqual(store.exportData(), before)
        let restored = StudioStore(fileURL: file)
        XCTAssertNil(restored.error)
        XCTAssertEqual(restored.portfolioProfile(for: scene.id), updated)
        XCTAssertEqual(restored.scenes.first { $0.id == scene.id }, scene)
    }

    func testPortfolioBuySellConservesValueAndPersistsCapturedSceneAccounting() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = StudioStore(fileURL: file)
        let scene = try XCTUnwrap(store.scenes.first { $0.kind == .portfolio })
        let activeBefore = store.activeID
        let original = store.portfolioProfile(for: scene.id)
        let asset = original.positions[0]
        let buy = try XCTUnwrap(store.executeMarketTrade(sceneID: scene.id, assetID: asset.id, side: .buy, units: 2))
        XCTAssertEqual(buy.price, asset.price)
        XCTAssertEqual(store.portfolioProfile(for: scene.id).positions[0].averageCost,
            (asset.costBasis + buy.total) / (asset.units + 2), accuracy: 0.000001)
        let sell = try XCTUnwrap(store.executeMarketTrade(sceneID: scene.id, assetID: asset.id, side: .sell, units: 3))
        let profile = store.portfolioProfile(for: scene.id)
        let updatedScene = try XCTUnwrap(store.scenes.first { $0.id == scene.id })
        XCTAssertEqual(profile.positions[0].units, asset.units - 1)
        XCTAssertEqual(updatedScene.balance, scene.balance - buy.total + sell.total, accuracy: 0.000001)
        XCTAssertEqual(profile.total(cash: updatedScene.balance), original.total(cash: scene.balance), accuracy: 0.000001)
        XCTAssertEqual(updatedScene.sales, scene.sales)
        XCTAssertEqual(updatedScene.orders, scene.orders)
        XCTAssertEqual(updatedScene.audience, scene.audience)
        XCTAssertEqual(store.activeID, activeBefore)
        XCTAssertTrue(store.events.isEmpty)
        XCTAssertEqual(profile.transactions.map(\.id), [sell.id, buy.id])
        let restored = StudioStore(fileURL: file)
        XCTAssertNil(restored.error)
        XCTAssertEqual(restored.portfolioProfile(for: scene.id), profile)
        XCTAssertEqual(restored.scenes.first { $0.id == scene.id }, updatedScene)
        XCTAssertEqual(restored.activeID, activeBefore)
    }

    func testWalletTransfersAndSwapPersistTokenHistoryWithoutChangingSceneCash() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = StudioStore(fileURL: file)
        let scene = try XCTUnwrap(store.scenes.first { $0.kind == .wallet })
        let activeBefore = store.activeID
        let original = store.walletProfile(for: scene.id)
        let token = original.holdings[0]
        let destination = original.holdings[1]
        let address = "0x0000000000000000000000000000000000000011"
        let sent = try XCTUnwrap(store.walletTransfer(sceneID: scene.id, assetID: token.id, kind: .send, quantity: 0.25, address: address))
        let received = try XCTUnwrap(store.walletTransfer(sceneID: scene.id, assetID: token.id, kind: .receive,
            quantity: 0.1, address: token.address ?? original.address))
        let beforeSwap = store.walletProfile(for: scene.id).fiatValue
        XCTAssertTrue(store.swapWallet(sceneID: scene.id, fromAssetID: token.id, toAssetID: destination.id, quantity: 0.5))
        let profile = store.walletProfile(for: scene.id)
        XCTAssertEqual(profile.holdings[0].quantity, token.quantity - 0.25 + 0.1 - 0.5, accuracy: 0.000001)
        XCTAssertEqual(profile.holdings[1].quantity, destination.quantity + 0.5 * token.price / destination.price, accuracy: 0.000001)
        XCTAssertEqual(profile.fiatValue, beforeSwap, accuracy: 0.000001)
        XCTAssertEqual(profile.transactions.count, 4)
        XCTAssertEqual(profile.transactions[2].id, received.id)
        XCTAssertEqual(profile.transactions[3].id, sent.id)
        XCTAssertEqual(sent.address, address)
        XCTAssertEqual(store.scenes.first { $0.id == scene.id }, scene)
        XCTAssertEqual(store.activeID, activeBefore)
        XCTAssertTrue(store.events.isEmpty)
        let restored = StudioStore(fileURL: file)
        XCTAssertNil(restored.error)
        XCTAssertEqual(restored.walletProfile(for: scene.id), profile)
    }

    func testPredictionOutcomeBuySellPreservesCashValueAndWeightedBasisOnReload() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = StudioStore(fileURL: file)
        let scene = try XCTUnwrap(store.scenes.first { $0.kind == .prediction })
        let original = store.predictionProfile(for: scene.id)
        let market = original.markets[0]
        let activeBefore = store.activeID
        let yesBuy = try XCTUnwrap(store.tradePrediction(sceneID: scene.id, marketID: market.id, outcome: .yes, side: .buy, shares: 50))
        let noBuy = try XCTUnwrap(store.tradePrediction(sceneID: scene.id, marketID: market.id, outcome: .no, side: .buy, shares: 20))
        let noSell = try XCTUnwrap(store.tradePrediction(sceneID: scene.id, marketID: market.id, outcome: .no, side: .sell, shares: 5))
        let profile = store.predictionProfile(for: scene.id)
        let yes = try XCTUnwrap(profile.positions.first { $0.marketID == market.id && $0.outcome == .yes })
        let no = try XCTUnwrap(profile.positions.first { $0.marketID == market.id && $0.outcome == .no })
        XCTAssertEqual(yes.shares, 300)
        XCTAssertEqual(yes.averagePrice, (250 * 0.58 + yesBuy.total) / 300, accuracy: 0.000001)
        XCTAssertEqual(no.shares, 15)
        XCTAssertEqual(no.averagePrice, market.noPrice)
        let cash = try XCTUnwrap(store.scenes.first { $0.id == scene.id }).balance
        XCTAssertEqual(cash, scene.balance - yesBuy.total - noBuy.total + noSell.total, accuracy: 0.000001)
        XCTAssertEqual(profile.total(cash: cash), original.total(cash: scene.balance), accuracy: 0.000001)
        XCTAssertEqual(store.activeID, activeBefore)
        XCTAssertTrue(store.events.isEmpty)
        let restored = StudioStore(fileURL: file)
        XCTAssertEqual(restored.predictionProfile(for: scene.id), profile)
        XCTAssertEqual(restored.scenes.first { $0.id == scene.id }?.balance, cash)
    }

    func testRejectedMarketOperationsLeaveMemoryAndSavedBytesUnchanged() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = StudioStore(fileURL: file)
        let portfolio = try XCTUnwrap(store.scenes.first { $0.kind == .portfolio })
        let wallet = try XCTUnwrap(store.scenes.first { $0.kind == .wallet })
        let prediction = try XCTUnwrap(store.scenes.first { $0.kind == .prediction })
        for scene in [portfolio, wallet, prediction] { XCTAssertTrue(store.preparePlayback(for: scene.id)) }
        let asset = store.portfolioProfile(for: portfolio.id).positions[0]
        let token = store.walletProfile(for: wallet.id).holdings[0]
        let market = store.predictionProfile(for: prediction.id).markets[0]
        let address = store.walletProfile(for: wallet.id).address
        let memory = try XCTUnwrap(store.exportData())
        let disk = try Data(contentsOf: file)
        for quantity in [0, -1, Double.nan, Double.infinity, 1_000_000_001] {
            XCTAssertNil(store.executeMarketTrade(sceneID: portfolio.id, assetID: asset.id, side: .buy, units: quantity))
            XCTAssertNil(store.walletTransfer(sceneID: wallet.id, assetID: token.id, kind: .receive, quantity: quantity, address: address))
            XCTAssertNil(store.tradePrediction(sceneID: prediction.id, marketID: market.id, outcome: .yes, side: .buy, shares: quantity))
        }
        XCTAssertNil(store.executeMarketTrade(sceneID: portfolio.id, assetID: asset.id, side: .buy, units: 1_000_000))
        XCTAssertNil(store.executeMarketTrade(sceneID: portfolio.id, assetID: asset.id, side: .sell, units: asset.units + 1))
        XCTAssertNil(store.executeMarketTrade(sceneID: wallet.id, assetID: asset.id, side: .buy, units: 1))
        XCTAssertNil(store.executeMarketTrade(sceneID: portfolio.id, assetID: UUID(), side: .buy, units: 1))
        XCTAssertNil(store.walletTransfer(sceneID: wallet.id, assetID: token.id, kind: .send, quantity: token.quantity + 1, address: address))
        XCTAssertNil(store.walletTransfer(sceneID: wallet.id, assetID: token.id, kind: .receive, quantity: 1_000_000_000, address: address))
        XCTAssertNil(store.walletTransfer(sceneID: wallet.id, assetID: token.id, kind: .send, quantity: 1, address: "bad address"))
        XCTAssertFalse(store.swapWallet(sceneID: wallet.id, fromAssetID: token.id, toAssetID: token.id, quantity: 1))
        XCTAssertFalse(store.swapWallet(sceneID: wallet.id, fromAssetID: token.id, toAssetID: UUID(), quantity: 1))
        XCTAssertNil(store.tradePrediction(sceneID: prediction.id, marketID: market.id, outcome: .no, side: .sell, shares: 1))
        XCTAssertNil(store.tradePrediction(sceneID: prediction.id, marketID: market.id, outcome: .yes, side: .buy, shares: 1_000_000))
        XCTAssertNil(store.tradePrediction(sceneID: prediction.id, marketID: UUID(), outcome: .yes, side: .buy, shares: 1))
        XCTAssertEqual(store.exportData(), memory)
        XCTAssertEqual(try Data(contentsOf: file), disk)
        var closed = store.predictionProfile(for: prediction.id)
        closed.markets[0].closeDate = .distantPast
        XCTAssertTrue(store.updatePredictionProfile(closed))
        let closedMemory = store.exportData()
        let closedDisk = try Data(contentsOf: file)
        XCTAssertNil(store.tradePrediction(sceneID: prediction.id, marketID: market.id, outcome: .yes, side: .buy, shares: 1))
        XCTAssertNil(store.tradePrediction(sceneID: prediction.id, marketID: market.id, outcome: .yes, side: .sell, shares: 1))
        XCTAssertEqual(store.exportData(), closedMemory)
        XCTAssertEqual(try Data(contentsOf: file), closedDisk)
    }

    func testFailedMarketSaveDoesNotPublishCashHoldingsOrHistory() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = StudioStore(fileURL: file)
        let portfolio = try XCTUnwrap(store.scenes.first { $0.kind == .portfolio })
        let wallet = try XCTUnwrap(store.scenes.first { $0.kind == .wallet })
        let prediction = try XCTUnwrap(store.scenes.first { $0.kind == .prediction })
        for scene in [portfolio, wallet, prediction] { XCTAssertTrue(store.preparePlayback(for: scene.id)) }
        let asset = store.portfolioProfile(for: portfolio.id).positions[0]
        let tokens = store.walletProfile(for: wallet.id).holdings
        let market = store.predictionProfile(for: prediction.id).markets[0]
        let before = store.exportData()
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
        XCTAssertNil(store.executeMarketTrade(sceneID: portfolio.id, assetID: asset.id, side: .buy, units: 1))
        XCTAssertNil(store.walletTransfer(sceneID: wallet.id, assetID: tokens[0].id, kind: .send, quantity: 0.1,
            address: store.walletProfile(for: wallet.id).address))
        XCTAssertFalse(store.swapWallet(sceneID: wallet.id, fromAssetID: tokens[0].id, toAssetID: tokens[1].id, quantity: 0.1))
        XCTAssertNil(store.tradePrediction(sceneID: prediction.id, marketID: market.id, outcome: .yes, side: .buy, shares: 1))
        var edited = store.portfolioProfile(for: portfolio.id)
        edited.dailyChange = 5
        XCTAssertFalse(store.updatePortfolioProfile(edited, cashBalance: 500))
        XCTAssertEqual(store.exportData(), before)
        XCTAssertNotNil(store.error)
    }

    func testNewProfilesSurviveUnrelatedSavesAndArePrunedOnKindChangeDeleteAndReset() async throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = StudioStore(fileURL: file)
        let portfolio = try XCTUnwrap(store.scenes.first { $0.kind == .portfolio })
        let wallet = try XCTUnwrap(store.scenes.first { $0.kind == .wallet })
        let prediction = try XCTUnwrap(store.scenes.first { $0.kind == .prediction })
        for scene in [portfolio, wallet, prediction] { XCTAssertTrue(store.preparePlayback(for: scene.id)) }
        let originalProfiles = (store.portfolioProfiles, store.walletProfiles, store.predictionProfiles)
        let cue = NotificationPreset(name: "Market cue", kind: .deposit, amount: 25, detail: "Milestone", delay: 5, count: 1)
        XCTAssertTrue(store.savePreset(cue))
        store.select(store.scenes[1])
        XCTAssertNotNil(store.emit(kind: .deposit, amount: 10, detail: "Unrelated income"))
        store.deletePreset(cue)
        store.save()
        let restored = StudioStore(fileURL: file)
        XCTAssertEqual(restored.portfolioProfiles, originalProfiles.0)
        XCTAssertEqual(restored.walletProfiles, originalProfiles.1)
        XCTAssertEqual(restored.predictionProfiles, originalProfiles.2)
        var changed = portfolio
        changed.kind = .creator
        XCTAssertTrue(store.update(changed))
        XCTAssertTrue(store.portfolioProfiles.isEmpty)
        store.delete(wallet)
        XCTAssertTrue(store.walletProfiles.isEmpty)
        XCTAssertEqual(StudioStore(fileURL: file).predictionProfiles, originalProfiles.2)
        await store.reset()
        XCTAssertTrue(store.portfolioProfiles.isEmpty)
        XCTAssertTrue(store.walletProfiles.isEmpty)
        XCTAssertTrue(store.predictionProfiles.isEmpty)
        let afterReset = StudioStore(fileURL: file)
        XCTAssertTrue(afterReset.predictionProfiles.isEmpty)
        XCTAssertEqual(afterReset.scenes, StudioScene.examples)
    }

    func testImportedMarketActivityAndAtomicCashEditorSurviveReload() async throws {
        let sourceFile = temporaryFile()
        let targetFile = temporaryFile()
        defer { try? FileManager.default.removeItem(at: sourceFile); try? FileManager.default.removeItem(at: targetFile) }
        let source = StudioStore(fileURL: sourceFile)
        let scene = try XCTUnwrap(source.scenes.first { $0.kind == .portfolio })
        var profile = source.portfolioProfile(for: scene.id)
        profile.theme = .wealthsimple
        profile.positions[0].price = 100
        XCTAssertTrue(source.updatePortfolioProfile(profile, cashBalance: 1500))
        XCTAssertNotNil(source.executeMarketTrade(sceneID: scene.id, assetID: profile.positions[0].id, side: .buy, units: 2))
        let data = try XCTUnwrap(source.exportData())
        let target = StudioStore(fileURL: targetFile)
        let imported = await target.importSession(data)
        XCTAssertTrue(imported)
        let restored = StudioStore(fileURL: targetFile)
        XCTAssertEqual(restored.portfolioProfiles, source.portfolioProfiles)
        XCTAssertEqual(restored.scenes, source.scenes)
        let before = restored.exportData()
        profile = restored.portfolioProfile(for: scene.id)
        profile.dailyChange = 3
        XCTAssertFalse(restored.updatePortfolioProfile(profile, cashBalance: .nan))
        XCTAssertFalse(restored.updatePortfolioProfile(profile, cashBalance: 1_000_000_000))
        XCTAssertEqual(restored.exportData(), before)
    }
}
