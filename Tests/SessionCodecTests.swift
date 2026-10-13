import XCTest
@testable import Reverie

final class SessionCodecTests: XCTestCase {
    private func preset() -> NotificationPreset {
        NotificationPreset(name: "Morning orders", kind: .order, amount: 49, detail: "Order #1049", delay: 30, count: 4)
    }
    func testLegacyExportWithoutPresetsStillLoads() throws {
        let scenes = StudioScene.examples
        let encoded = try Archive(scenes: scenes, events: [], activeID: scenes[0].id).encoded()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json.removeValue(forKey: "presets")
        let restored = try Archive.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(restored.scenes, scenes)
        XCTAssertTrue(restored.presets.isEmpty)
    }
    func testExportImportPreservesCuesAndSceneSelection() throws {
        let scenes = StudioScene.examples
        let cue = preset()
        let source = Archive(scenes: scenes, events: [], activeID: scenes[2].id, presets: [cue])
        let restored = try Archive.decode(source.encoded(prettyPrinted: true))
        XCTAssertEqual(restored.presets, [cue])
        XCTAssertEqual(restored.activeID, scenes[2].id)
        XCTAssertEqual(restored.scenes, scenes)
    }
    func testOversizedFileIsRejectedBeforeJSONDecode() {
        XCTAssertThrowsError(try Archive.decode(Data(repeating: 0x20, count: Archive.maximumBytes + 1))) { error in
            guard case ArchiveError.tooLarge = error else { return XCTFail("Unexpected error: \(error)") }
        }
    }
    func testDuplicateOrInvalidPresetsAreRejected() throws {
        let scenes = StudioScene.examples
        let cue = preset()
        let duplicate = Archive(scenes: scenes, events: [], activeID: scenes[0].id, presets: [cue, cue])
        XCTAssertFalse(duplicate.isValid)
        var invalid = cue
        invalid.count = 21
        XCTAssertFalse(Archive(scenes: scenes, events: [], activeID: scenes[0].id, presets: [invalid]).isValid)
    }
    func testPresetCapacityIsBounded() {
        let scenes = StudioScene.examples
        let cues = (0..<51).map { _ in preset() }
        XCTAssertFalse(Archive(scenes: scenes, events: [], activeID: scenes[0].id, presets: cues).isValid)
    }
    func testCorruptedReferencesCannotBeImported() throws {
        let scenes = StudioScene.examples
        let source = Archive(scenes: scenes, events: [], activeID: UUID())
        let encoded = try JSONEncoder().encode(source)
        XCTAssertThrowsError(try Archive.decode(encoded))
    }
}
