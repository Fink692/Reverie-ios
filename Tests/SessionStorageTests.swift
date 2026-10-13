import XCTest
@testable import Reverie

final class SessionStorageTests: XCTestCase {
    private func directory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
    func testMissingSessionAndAtomicRoundTrip() throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = SessionStorage(file: directory.appending(path: "session.json"))
        XCTAssertNil(try storage.load())
        let scenes = StudioScene.examples
        let event = SceneEvent(sceneID: scenes[1].id, kind: .deposit, amount: 125, detail: "Arrival")
        let archive = Archive(scenes: scenes, events: [event], activeID: scenes[1].id)
        try storage.save(archive)
        let reloaded = try XCTUnwrap(SessionStorage(file: storage.file).load())
        XCTAssertEqual(reloaded.scenes, scenes)
        XCTAssertEqual(reloaded.events, [event])
        XCTAssertEqual(reloaded.activeID, scenes[1].id)
    }
    func testCorruptionIsPreservedBeforeRecoverySave() throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = SessionStorage(file: directory.appending(path: "session.json"))
        let original = Data("damaged JSON".utf8)
        try original.write(to: storage.file)
        XCTAssertThrowsError(try storage.load())
        XCTAssertEqual(try Data(contentsOf: storage.file), original)
        let scenes = StudioScene.examples
        try storage.save(Archive(scenes: scenes, events: [], activeID: scenes[0].id))
        let backups = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.contains("recovery-") }
        XCTAssertEqual(backups.count, 1)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(backups.first)), original)
        XCTAssertNotNil(try storage.load())
    }
    func testInvalidSaveDoesNotReplaceValidSession() throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = SessionStorage(file: directory.appending(path: "session.json"))
        let scenes = StudioScene.examples
        try storage.save(Archive(scenes: scenes, events: [], activeID: scenes[0].id))
        let original = try Data(contentsOf: storage.file)
        XCTAssertThrowsError(try storage.save(Archive(scenes: [], events: [], activeID: UUID())))
        XCTAssertEqual(try Data(contentsOf: storage.file), original)
    }
    func testWriteFailureIsReported() throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = SessionStorage(file: directory.appending(path: "missing/session.json"))
        let scenes = StudioScene.examples
        XCTAssertThrowsError(try storage.save(Archive(scenes: scenes, events: [], activeID: scenes[0].id)))
    }
}
