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
}
