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

}
