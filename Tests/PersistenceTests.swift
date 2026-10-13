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
