import XCTest
@testable import Reverie

final class PlaybackModelTests: XCTestCase {
    func testProfilesAndOrderMetadataSurviveExport() throws {
        let scenes = StudioScene.examples
        let commerce = CommerceProfile.starter(for: scenes[0].id)
        var bank = BankProfile.starter(for: scenes[1].id)
        bank.theme = .monzo; bank.cardFrozen = true
        var order = SceneEvent(sceneID: scenes[0].id, kind: .order, amount: 149, detail: "Jamie · 3 items")
        order.orderNumber = 1084; order.customerName = "Jamie"; order.itemCount = 3
        let archive = Archive(scenes: scenes, events: [order], activeID: scenes[0].id,
            commerceProfiles: [commerce], bankProfiles: [bank])
        let restored = try Archive.decode(archive.encoded())
        XCTAssertEqual(restored.commerceProfiles, [commerce])
        XCTAssertEqual(restored.bankProfiles, [bank])
        XCTAssertEqual(restored.events[0].orderNumber, 1084)
        XCTAssertEqual(restored.events[0].itemCount, 3)
    }
    func testLegacyArchiveDefaultsPlaybackProfiles() throws {
        let scenes = StudioScene.examples
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Archive(scenes: scenes, events: [], activeID: scenes[0].id).encoded()) as? [String: Any])
        json.removeValue(forKey: "commerceProfiles"); json.removeValue(forKey: "bankProfiles")
        let restored = try Archive.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(restored.commerceProfiles.isEmpty)
        XCTAssertTrue(restored.bankProfiles.isEmpty)
    }
    func testProfilesCannotReferenceMissingScene() {
        let scenes = StudioScene.examples
        let profile = BankProfile.starter(for: UUID())
        XCTAssertFalse(Archive(scenes: scenes, events: [], activeID: scenes[0].id, bankProfiles: [profile]).isValid)
    }
    func testInvalidChartsAndCardSuffixesAreRejected() {
        var profile = CommerceProfile.starter(for: StudioScene.examples[0].id)
        profile.previousChart = [0, .nan]
        XCTAssertFalse(profile.isValid)
        var bank = BankProfile.starter(for: StudioScene.examples[1].id)
        bank.accountSuffix = "12345"
        XCTAssertFalse(bank.isValid)
        bank.accountSuffix = "ABCD"
        XCTAssertFalse(bank.isValid)
    }
    func testImpossibleOrderMetadataCannotChangeTotals() {
        let scene = StudioScene.examples[0]
        var event = SceneEvent(sceneID: scene.id, kind: .order, amount: 10, detail: "")
        event.itemCount = 0
        XCTAssertFalse(event.isValid)
        XCTAssertEqual(Simulation.applying(event, to: scene), scene)
    }
    func testCommerceNotificationUsesOrderQuantityAndStoreName() {
        let scene = StudioScene.examples[0]
        var event = SceneEvent(sceneID: scene.id, kind: .order, amount: 149, detail: "")
        event.itemCount = 1
        XCTAssertEqual(event.body(scene: scene), "[\(scene.name)] You have a new order for 1 item totaling \(scene.money(149)).")
    }

}
