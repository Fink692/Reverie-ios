import XCTest
@testable import Reverie

final class ValidationTests: XCTestCase {
    func testArchiveRejectsDuplicateScenesAndOrphanEvents() {
        let scene = StudioScene.examples[0]
        XCTAssertFalse(Archive(scenes: [scene, scene], events: [], activeID: scene.id).isValid)
        let orphan = SceneEvent(sceneID: UUID(), kind: .order, amount: 10, detail: "")
        XCTAssertFalse(Archive(scenes: [scene], events: [orphan], activeID: scene.id).isValid)
    }
    func testArchiveRejectsInvalidTotalsAndCounts() {
        var scene = StudioScene.examples[0]
        scene.orders = Int.max
        XCTAssertFalse(scene.isValid)
        let event = SceneEvent(sceneID: scene.id, kind: .order, amount: 50, detail: "")
        XCTAssertEqual(Simulation.applying(event, to: scene), scene)
        scene.orders = 0; scene.balance = -1
        XCTAssertFalse(scene.isValid)
    }
    func testOverflowingDashboardTotalsStayUnchanged() {
        var scene = StudioScene.examples[0]
        scene.balance = 1_000_000_000
        let event = SceneEvent(sceneID: scene.id, kind: .deposit, amount: 1, detail: "")
        XCTAssertEqual(Simulation.applying(event, to: scene), scene)
    }
    func testEventCannotUpdateAnotherScene() {
        let scenes = StudioScene.examples
        let event = SceneEvent(sceneID: scenes[1].id, kind: .order, amount: 10, detail: "")
        XCTAssertEqual(Simulation.applying(event, to: scenes[0]), scenes[0])
    }
    func testLocalizedDecimalInputAndZero() {
        XCTAssertEqual(Simulation.parseAmount(" 123,45 ", locale: Locale(identifier: "de_DE")), 123.45)
        XCTAssertEqual(Simulation.parseAmount("123.45", locale: Locale(identifier: "en_US")), 123.45)
        XCTAssertEqual(Simulation.parseAmount("0", locale: Locale(identifier: "en_US")), 0)
        for value in ["1e9", "NaN", "-1", "1.2.3", "1,234.56", "", "."] {
            XCTAssertNil(Simulation.parseAmount(value, locale: Locale(identifier: "en_US")))
        }
    }
    func testLocalizedDecimalDigitsRoundTrip() {
        for localeName in ["ar_EG", "fa_IR", "fr_FR", "en_US"] {
            let locale = Locale(identifier: localeName)
            let formatter = NumberFormatter()
            formatter.locale = locale
            formatter.numberStyle = .decimal
            formatter.usesGroupingSeparator = false
            formatter.maximumFractionDigits = 2
            let input = formatter.string(from: 123.45)!
            XCTAssertEqual(Simulation.parseAmount(input, locale: locale), 123.45, localeName)
        }
    }
    func testNotificationPlanKeepsSceneAndSpacing() throws {
        let scene = StudioScene.examples[0]
        let plan = try XCTUnwrap(NotificationPlan.make(scene: scene, kind: .order, amount: 12, detail: "Item", delay: 5, count: 3, pendingCount: 2))
        XCTAssertEqual(plan.map(\.delay), [5, 15, 25])
        XCTAssertTrue(plan.allSatisfy { $0.event.sceneID == scene.id })
        XCTAssertEqual(Set(plan.map { $0.event.id }).count, 3)
    }
    func testNotificationCapacityAndTimingAreBounded() {
        let scene = StudioScene.examples[0]
        XCTAssertNil(NotificationPlan.make(scene: scene, kind: .order, amount: 10, detail: "", delay: 5, count: 20, pendingCount: 41))
        XCTAssertNil(NotificationPlan.make(scene: scene, kind: .order, amount: 10, detail: "", delay: .nan, count: 1, pendingCount: 0))
        XCTAssertNil(NotificationPlan.make(scene: scene, kind: .order, amount: 10, detail: "", delay: 5, count: 21, pendingCount: 0))
    }
    func testSubscriberNotificationHasNoMoneyOrEmptySeparator() throws {
        let scene = StudioScene.examples[2]
        let cue = try XCTUnwrap(NotificationPlan.make(scene: scene, kind: .subscriber, amount: 0, detail: "", delay: 5, count: 1, pendingCount: 0)?.first)
        XCTAssertEqual(cue.event.body(scene: scene), scene.name)
        XCTAssertEqual(cue.event.title, "New subscriber")
    }
}
