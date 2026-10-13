import XCTest
@testable import Reverie
final class SimulationTests: XCTestCase {
    func testOrderUpdatesTotalsAndPreservesIdentity() {
        let scene = StudioScene.examples[0]
        let event = SceneEvent(sceneID: scene.id, kind: .order, amount: 150, detail: "Test order")
        let changed = Simulation.applying(event, to: scene)
        XCTAssertEqual(changed.id, scene.id)
        XCTAssertEqual(changed.sales, scene.sales + 150)
        XCTAssertEqual(changed.balance, scene.balance + 150)
        XCTAssertEqual(changed.orders, scene.orders + 1)
        XCTAssertEqual(changed.audience, scene.audience)
    }
    func testDepositOnlyChangesBalance() {
        let scene = StudioScene.examples[1]
        let changed = Simulation.applying(SceneEvent(sceneID: scene.id, kind: .deposit, amount: 200, detail: ""), to: scene)
        XCTAssertEqual(changed.balance, scene.balance + 200)
        XCTAssertEqual(changed.sales, scene.sales)
        XCTAssertEqual(changed.orders, scene.orders)
    }
    func testSubscriberOnlyChangesAudience() {
        let scene = StudioScene.examples[2]
        let changed = Simulation.applying(SceneEvent(sceneID: scene.id, kind: .subscriber, amount: 1, detail: ""), to: scene)
        XCTAssertEqual(changed.audience, scene.audience + 1)
        XCTAssertEqual(changed.balance, scene.balance)
    }
    func testInvalidAmountsAreRejected() {
        for amount in [0.0, -1, Double.nan, Double.infinity, 1_000_000_001] { XCTAssertFalse(Simulation.validAmount(amount)) }
        XCTAssertTrue(Simulation.validAmount(0.01))
    }
    func testArchiveRoundTripPreservesSceneReferences() throws {
        let scenes = StudioScene.examples
        let events = [SceneEvent(sceneID: scenes[0].id, kind: .order, amount: 12, detail: "Sample")]
        let source = Archive(scenes: scenes, events: events, activeID: scenes[0].id)
        let restored = try JSONDecoder().decode(Archive.self, from: JSONEncoder().encode(source))
        XCTAssertEqual(restored.scenes, source.scenes)
        XCTAssertEqual(restored.events, source.events)
        XCTAssertEqual(restored.activeID, restored.events[0].sceneID)
        XCTAssertEqual(restored.events[0].title, "New order")
    }
}
