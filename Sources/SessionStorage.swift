import Foundation

/// Shared on-disk storage, independent of the UI and notification framework.
final class SessionStorage {
    let file: URL
    private var needsRecoveryBackup = false
    init(file: URL) { self.file = file }
    func load() throws -> Archive? {
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        do {
            let archive = try Archive.decode(Data(contentsOf: file))
            guard archive.isValid else { throw SessionStorageError.invalidSession }
            return archive
        } catch {
            needsRecoveryBackup = true
            throw error
        }
    }
    func save(_ archive: Archive) throws {
        guard archive.isValid else { throw SessionStorageError.invalidSession }
        let data = try archive.encoded()
        if needsRecoveryBackup {
            let backup = file.deletingPathExtension().appendingPathExtension("recovery-\(UUID().uuidString).json")
            try FileManager.default.copyItem(at: file, to: backup)
            needsRecoveryBackup = false
        }
        try data.write(to: file, options: .atomic)
    }
}
enum SessionStorageError: LocalizedError {
    case invalidSession
    var errorDescription: String? { "The saved session contains invalid scenes or events." }
}
