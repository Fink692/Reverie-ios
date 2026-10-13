import XCTest
@testable import Reverie

final class NotificationModelTests: XCTestCase {
    func testReferencedDuplicateChargeAlertIsEditableAndCannotChangeBalances() throws {
        let scene = StudioScene.examples[1]
        let style = NotificationStyle.bankDuplicateCharge
        XCTAssertFalse(style.canEmit)
        XCTAssertTrue(style.isAvailable(for: .banking))
        XCTAssertFalse(style.isAvailable(for: .commerce))
        let plan = try XCTUnwrap(NotificationPlan.make(scene: scene, kind: style.eventKind,
            amount: 10.50, detail: "Camera Supply Store", delay: 10, count: 1, pendingCount: 0, style: style))
        XCTAssertEqual(plan[0].event.title, "Were you double charged?")
        XCTAssertEqual(plan[0].event.body(scene: scene), "You were charged \(scene.money(10.50)) twice today by Camera Supply Store. Tap for details.")
        XCTAssertEqual(style.title(customTitle: "Check this purchase"), "Check this purchase")
        XCTAssertTrue(style.body(scene: scene, amount: 29, detail: "Coffee House").contains("Coffee House"))
    }
    func testEverySceneKindHasValidBuiltInNotificationTemplates() throws {
        let templates = NotificationTemplate.builtins
        XCTAssertGreaterThanOrEqual(templates.count, 25)
        XCTAssertEqual(Set(templates.map(\.id)).count, templates.count)
        XCTAssertGreaterThanOrEqual(NotificationStyle.allCases.count, 25)
        for scene in StudioScene.examples {
            let available = NotificationTemplate.templates(for: scene.kind)
            XCTAssertFalse(available.isEmpty, scene.kind.title)
            for template in available {
                XCTAssertTrue(template.style.isAvailable(for: scene.kind))
                let plan = try XCTUnwrap(NotificationPlan.make(scene: scene, kind: template.kind,
                    amount: template.amount, detail: template.detail, delay: template.delay, count: template.count,
                    pendingCount: 0, style: template.style, interval: template.interval,
                    customerName: template.customerName, itemCount: template.itemCount,
                    orderNumber: template.orderNumber, customTitle: template.customTitle), template.name)
                XCTAssertEqual(plan.count, template.count)
                XCTAssertTrue(plan.allSatisfy { $0.event.isValid && $0.event.sceneID == scene.id })
                XCTAssertFalse(plan[0].event.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                XCTAssertFalse(plan[0].event.body(scene: scene).isEmpty)
            }
        }
    }

    func testCustomCueRendersEditableTitleBodyAndAllSupportedTokens() throws {
        let scene = StudioScene.examples[0]
        let plan = try XCTUnwrap(NotificationPlan.make(scene: scene, kind: NotificationStyle.custom.eventKind,
            amount: 321.5, detail: "{customer} placed order #{order} for {items} items at {scene}: {amount}.",
            delay: 300, count: 1, pendingCount: 0, style: .custom, interval: 30,
            customerName: "Morgan Hale", itemCount: 3, orderNumber: 2088, customTitle: "Weekend checkout"))
        let event = plan[0].event
        XCTAssertEqual(event.title, "Weekend checkout")
        XCTAssertEqual(event.body(scene: scene), "Morgan Hale placed order #2088 for 3 items at \(scene.name): \(scene.money(321.5)).")
        XCTAssertEqual(event.style, .custom)
        XCTAssertFalse(NotificationStyle.custom.supportsAccounting)
        var tokenScene = scene
        tokenScene.name = "Studio {amount}"
        let literalTokens = try XCTUnwrap(NotificationPlan.make(scene: tokenScene, kind: NotificationStyle.custom.eventKind,
            amount: 25, detail: "🎬 {scene} / {customer} / {amount} / {unknown}", delay: 300, count: 1, pendingCount: 0,
            style: .custom, customerName: "Morgan {order}", orderNumber: 2088))
        XCTAssertEqual(literalTokens[0].event.body(scene: tokenScene),
            "🎬 Studio {amount} / Morgan {order} / \(tokenScene.money(25)) / {unknown}")
    }

    func testShopifySequenceRetainsMetadataAndUsesTheChosenSpacing() throws {
        let scene = StudioScene.examples[0]
        let plan = try XCTUnwrap(NotificationPlan.make(scene: scene, kind: .order, amount: 179.25,
            detail: "Weekend collection", delay: 300, count: 3, pendingCount: 57, style: .shopifyOrder,
            interval: 45, customerName: "Morgan Hale", itemCount: 3, orderNumber: 2088))
        XCTAssertEqual(plan.map(\.delay), [300, 345, 390])
        XCTAssertEqual(Set(plan.map { $0.event.id }).count, 3)
        XCTAssertEqual(plan.map { $0.event.orderNumber }, [2088, 2088, 2088])
        XCTAssertTrue(plan.allSatisfy { $0.event.customerName == "Morgan Hale" && $0.event.itemCount == 3 && $0.event.style == .shopifyOrder })
        XCTAssertTrue(plan[0].event.body(scene: scene).contains(scene.money(179.25)))
        XCTAssertTrue(NotificationStyle.shopifyOrder.supportsAccounting)
    }

    func testPlanRejectsInvalidSpacingMetadataCapacityAndStyleScope() {
        let scene = StudioScene.examples[0]
        for interval in [0, 4, 3601, Double.nan, Double.infinity] {
            XCTAssertNil(NotificationPlan.make(scene: scene, kind: .order, amount: 25, detail: "Order",
                delay: 300, count: 1, pendingCount: 0, style: .shopifyOrder, interval: interval))
        }
        XCTAssertNil(NotificationPlan.make(scene: scene, kind: .order, amount: 25, detail: "Order",
            delay: 300, count: 2, pendingCount: 59, style: .shopifyOrder))
        XCTAssertNil(NotificationPlan.make(scene: scene, kind: .order, amount: 25, detail: "Order",
            delay: 300, count: 1, pendingCount: 0, style: .shopifyOrder, itemCount: 0))
        XCTAssertNil(NotificationPlan.make(scene: scene, kind: .order, amount: 25, detail: "Order",
            delay: 300, count: 1, pendingCount: 0, style: .shopifyOrder, customerName: String(repeating: "x", count: 81)))
        XCTAssertNil(NotificationPlan.make(scene: scene, kind: .order, amount: 25, detail: "Order",
            delay: 300, count: 1, pendingCount: 0, style: .shopifyOrder, orderNumber: 2_000_001))
        XCTAssertNil(NotificationPlan.make(scene: StudioScene.examples[1], kind: .order, amount: 25, detail: "Order",
            delay: 300, count: 1, pendingCount: 0, style: .shopifyOrder))
        XCTAssertNil(NotificationPlan.make(scene: scene, kind: .payment, amount: 25, detail: "Order",
            delay: 300, count: 1, pendingCount: 0, style: .shopifyOrder))
        XCTAssertNil(NotificationPlan.make(scene: scene, kind: NotificationStyle.custom.eventKind, amount: 25, detail: "Body",
            delay: 300, count: 1, pendingCount: 0, style: .custom, customTitle: String(repeating: "x", count: 81)))
    }

    func testStyledCueAndEventPreserveAllEditableFieldsInAnArchive() throws {
        let scene = StudioScene.examples[0]
        var cue = NotificationPreset(name: "Weekend collection", kind: .order, amount: 179.25,
            detail: "Morgan's collection", delay: 300, count: 3)
        cue.style = .shopifyOrder
        cue.interval = 30
        cue.customerName = "Morgan Hale"
        cue.itemCount = 3
        cue.orderNumber = 2088
        cue.customTitle = "Checkout completed"
        let plan = try XCTUnwrap(NotificationPlan.make(scene: scene, kind: cue.kind, amount: cue.amount,
            detail: cue.detail, delay: cue.delay, count: cue.count, pendingCount: 0, style: cue.style,
            interval: cue.interval, customerName: cue.customerName, itemCount: cue.itemCount,
            orderNumber: cue.orderNumber, customTitle: cue.customTitle))
        let source = Archive(scenes: StudioScene.examples, events: [plan[0].event], activeID: scene.id, presets: [cue])
        let decoded = try Archive.decode(source.encoded())
        XCTAssertEqual(decoded.presets, [cue])
        XCTAssertEqual(decoded.events, [plan[0].event])
        XCTAssertEqual(decoded.events[0].title, "Checkout completed")
        var changedScenes = StudioScene.examples
        changedScenes[0].kind = .banking
        let changed = changedScenes[0]
        let history = Archive(scenes: changedScenes, events: [plan[0].event], activeID: changed.id, presets: [cue])
        XCTAssertTrue(history.isValid, "Changing a scene's kind must preserve its previously recorded styled history")
        let reloadedHistory = try Archive.decode(history.encoded())
        XCTAssertEqual(reloadedHistory.events, [plan[0].event])
        XCTAssertNil(NotificationPlan.make(scene: changed, kind: .order, amount: cue.amount, detail: cue.detail,
            delay: cue.delay, count: 1, pendingCount: 0, style: .shopifyOrder))
        XCTAssertEqual(Simulation.applying(plan[0].event, to: changed), changed)
    }

    func testLegacyCueAndEventDecodeWithUnstyledTenSecondDefaults() throws {
        let scene = StudioScene.examples[0]
        let cue = NotificationPreset(name: "Morning order", kind: .order, amount: 49, detail: "Arrival", delay: 30, count: 2)
        let event = SceneEvent(sceneID: scene.id, kind: .order, amount: 49, detail: "Arrival")
        var cueJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(cue)) as? [String: Any])
        for key in ["style", "interval", "customerName", "itemCount", "orderNumber", "customTitle"] { cueJSON.removeValue(forKey: key) }
        var eventJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(event)) as? [String: Any])
        eventJSON.removeValue(forKey: "style")
        eventJSON.removeValue(forKey: "customTitle")
        let decodedCue = try JSONDecoder().decode(NotificationPreset.self, from: JSONSerialization.data(withJSONObject: cueJSON))
        let decodedEvent = try JSONDecoder().decode(SceneEvent.self, from: JSONSerialization.data(withJSONObject: eventJSON))
        XCTAssertEqual(decodedCue, cue)
        XCTAssertNil(decodedCue.style)
        XCTAssertEqual(decodedCue.interval, 10)
        XCTAssertEqual(decodedEvent, event)
        XCTAssertNil(decodedEvent.style)
        XCTAssertEqual(decodedEvent.title, "New order")
    }
}
