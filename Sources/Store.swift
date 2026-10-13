import SwiftUI
import UserNotifications

@MainActor final class StudioStore: ObservableObject {
    @Published private(set) var scenes: [StudioScene] = StudioScene.examples
    @Published private(set) var events: [SceneEvent] = []
    @Published private(set) var presets: [NotificationPreset] = []
    @Published private(set) var queuedAlerts: [QueuedAlert] = []
    @Published private(set) var activeID = StudioScene.examples[0].id
    @Published var error: String?
    @Published private(set) var notificationStatus = "Not requested"
    @Published private(set) var pendingCount = 0
    private let storage: SessionStorage
    private var notificationGeneration = 0
    private var isScheduling = false
    private var isResetting = false
    var active: StudioScene { scenes.first(where: { $0.id == activeID }) ?? scenes[0] }
    var activity: [SceneEvent] { events.filter { $0.sceneID == activeID }.sorted { $0.date > $1.date } }

    init(fileURL: URL = URL.documentsDirectory.appending(path: "reverie.json")) {
        storage = SessionStorage(file: fileURL)
        do {
            if let saved = try storage.load() {
                scenes = saved.scenes; events = saved.events; activeID = saved.activeID; presets = saved.presets
            }
        } catch {
            self.error = "Your saved session could not be loaded. Starter scenes are available. The original file will be preserved in a recovery backup before new changes are saved."
        }
    }
    private func persist(_ archive: Archive) -> Bool {
        do { try storage.save(archive); return true }
        catch { self.error = "Could not save your changes: \(error.localizedDescription)"; return false }
    }
    func save() {
        _ = persist(Archive(scenes: scenes, events: events, activeID: activeID, presets: presets))
    }
    func select(_ scene: StudioScene) {
        guard scenes.contains(where: { $0.id == scene.id }),
              persist(Archive(scenes: scenes, events: events, activeID: scene.id, presets: presets)) else { return }
        activeID = scene.id
    }
    @discardableResult func update(_ scene: StudioScene) -> Bool {
        guard scene.isValid else { error = "Check the scene name, currency, and dashboard totals."; return false }
        var updated = scenes
        if let index = updated.firstIndex(where: { $0.id == scene.id }) { updated[index] = scene }
        else {
            guard updated.count < 100 else { error = "You can save up to 100 scenes."; return false }
            updated.append(scene)
        }
        guard persist(Archive(scenes: updated, events: events, activeID: scene.id, presets: presets)) else { return false }
        scenes = updated; activeID = scene.id
        return true
    }
    func delete(_ scene: StudioScene) {
        guard scenes.count > 1, scenes.contains(where: { $0.id == scene.id }) else { return }
        let remaining = scenes.filter { $0.id != scene.id }
        let remainingEvents = events.filter { $0.sceneID != scene.id }
        let selection = activeID == scene.id ? remaining[0].id : activeID
        guard persist(Archive(scenes: remaining, events: remainingEvents, activeID: selection, presets: presets)) else { return }
        notificationGeneration += 1
        scenes = remaining; events = remainingEvents; activeID = selection
        Task {
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.content.userInfo["sceneID"] as? String == scene.id.uuidString }.map(\.identifier))
            let delivered = await center.deliveredNotifications()
            center.removeDeliveredNotifications(withIdentifiers: delivered.filter { $0.request.content.userInfo["sceneID"] as? String == scene.id.uuidString }.map { $0.request.identifier })
            await refreshNotifications()
        }
    }
    @discardableResult func emit(kind: EventKind, amount: Double, detail: String) -> SceneEvent? {
        let value = kind == .subscriber ? 0.01 : amount
        guard Simulation.validAmount(value), detail.count <= 240 else {
            error = "Enter an amount between 0.01 and 1 billion and details up to 240 characters."; return nil
        }
        let event = SceneEvent(sceneID: activeID, kind: kind, amount: value, detail: detail.trimmingCharacters(in: .whitespacesAndNewlines))
        guard let index = scenes.firstIndex(where: { $0.id == activeID }) else { return nil }
        let updated = Simulation.applying(event, to: scenes[index])
        guard updated != scenes[index] else { error = "This event would exceed the dashboard limits or available balance. Adjust the amount or totals in Edit scene."; return nil }
        var updatedScenes = scenes
        updatedScenes[index] = updated
        let updatedEvents = Array(([event] + events).prefix(1000))
        guard persist(Archive(scenes: updatedScenes, events: updatedEvents, activeID: activeID, presets: presets)) else { return nil }
        scenes = updatedScenes; events = updatedEvents
        return event
    }
    func refreshNotifications() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: notificationStatus = "Enabled"
        case .denied: notificationStatus = "Disabled in Settings"
        default: notificationStatus = "Not requested"
        }
        let requests = await center.pendingNotificationRequests()
        queuedAlerts = requests.map { request in
            QueuedAlert(id: request.identifier,
                sceneID: (request.content.userInfo["sceneID"] as? String).flatMap(UUID.init(uuidString:)),
                title: request.content.title, body: request.content.body, date: (request.content.userInfo["scheduledAt"] as? Double).map { Date(timeIntervalSince1970: $0) }
                    ?? (request.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate()
                    ?? (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate())
        }.sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
        pendingCount = queuedAlerts.count
    }
    func schedule(kind: EventKind, amount: Double, detail: String, delay: Double, count: Int) async -> Bool {
        guard !isScheduling, !isResetting else { error = "Wait for the current session operation to finish."; return false }
        let scheduledScene = active
        guard NotificationPlan.make(scene: scheduledScene, kind: kind, amount: amount, detail: detail, delay: delay, count: count, pendingCount: 0) != nil else {
            error = "Check the amount, details, delay, and notification count."; return false
        }
        isScheduling = true
        defer { isScheduling = false }
        let generation = notificationGeneration
        let center = UNUserNotificationCenter.current()
        var added: [String] = []
        func stillValid() -> Bool { generation == notificationGeneration && scenes.contains(where: { $0.id == scheduledScene.id }) }
        do {
            let allowed = try await center.requestAuthorization(options: [.alert, .sound])
            guard stillValid() else { return false }
            guard allowed else {
                error = "Notifications are disabled. Enable Reverie notifications in iOS Settings."; await refreshNotifications(); return false
            }
            let pending = await center.pendingNotificationRequests()
            guard stillValid() else { return false }
            guard let plan = NotificationPlan.make(scene: scheduledScene, kind: kind, amount: amount, detail: detail, delay: delay, count: count, pendingCount: pending.count) else {
                error = "Cancel queued notifications before adding this session."; return false
            }
            for cue in plan {
                guard stillValid() else {
                    center.removePendingNotificationRequests(withIdentifiers: added); await refreshNotifications(); return false
                }
                let content = UNMutableNotificationContent()
                content.title = cue.event.title; content.body = cue.event.body(scene: scheduledScene)
                content.sound = .default; content.threadIdentifier = scheduledScene.id.uuidString
                content.userInfo = ["sceneID": scheduledScene.id.uuidString, "scheduledAt": Date().addingTimeInterval(cue.delay).timeIntervalSince1970]
                let id = "reverie.\(cue.event.id.uuidString)"
                try await center.add(UNNotificationRequest(identifier: id, content: content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: cue.delay, repeats: false)))
                added.append(id)
            }
            guard stillValid() else {
                center.removePendingNotificationRequests(withIdentifiers: added); await refreshNotifications(); return false
            }
            await refreshNotifications(); return stillValid()
        } catch {
            center.removePendingNotificationRequests(withIdentifiers: added)
            self.error = "Could not schedule notifications: \(error.localizedDescription)"
            await refreshNotifications(); return false
        }
    }
    func cancelNotifications() async {
        notificationGeneration += 1
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        await refreshNotifications()
    }
    func reset() async {
        guard !isResetting else { return }
        isResetting = true
        defer { isResetting = false }
        await cancelNotifications()
        notificationGeneration += 1
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        let starter = Archive(scenes: StudioScene.examples, events: [], activeID: StudioScene.examples[0].id)
        if persist(starter) {
            scenes = starter.scenes; activeID = starter.activeID; events = []; presets = []
            NotificationRouter.shared.request = nil
        }
        await refreshNotifications()
    }
    func cancelAlert(_ alert: QueuedAlert) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [alert.id])
        await refreshNotifications()
    }
    @discardableResult func savePreset(_ preset: NotificationPreset) -> Bool {
        var clean = preset
        clean.name = preset.name.trimmingCharacters(in: .whitespacesAndNewlines)
        clean.detail = preset.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.kind == .subscriber { clean.amount = 0.01 }
        guard clean.isValid else { error = "Check the saved cue name and notification settings."; return false }
        var updated = presets
        if let index = updated.firstIndex(where: { $0.id == clean.id }) { updated[index] = clean }
        else {
            guard updated.count < 50 else { error = "You can save up to 50 notification cues."; return false }
            updated.append(clean)
        }
        do {
            try storage.save(Archive(scenes: scenes, events: events, activeID: activeID, presets: updated))
            presets = updated; return true
        } catch { self.error = "Could not save your cue: \(error.localizedDescription)"; return false }
    }
    func deletePreset(_ preset: NotificationPreset) {
        let updated = presets.filter { $0.id != preset.id }
        do {
            try storage.save(Archive(scenes: scenes, events: events, activeID: activeID, presets: updated))
            presets = updated
        } catch { self.error = "Could not delete your cue: \(error.localizedDescription)" }
    }
    func importSession(_ data: Data) async -> Bool {
        guard !isResetting else { error = "Wait for the current session operation to finish."; return false }
        do {
            let archive = try Archive.decode(data)
            // Commit the complete replacement before changing UI state or cancelling current alerts.
            try storage.save(archive)
            isResetting = true
            defer { isResetting = false }
            notificationGeneration += 1
            scenes = archive.scenes; events = archive.events; activeID = archive.activeID; presets = archive.presets
            let center = UNUserNotificationCenter.current()
            center.removeAllPendingNotificationRequests(); center.removeAllDeliveredNotifications()
            NotificationRouter.shared.request = nil
            await refreshNotifications()
            return true
        } catch { self.error = "Could not import this session: \(error.localizedDescription)"; return false }
    }
    func exportData() -> Data? {
        do { return try Archive(scenes: scenes, events: events, activeID: activeID, presets: presets).encoded(prettyPrinted: true) }
        catch { self.error = "Could not export this session: \(error.localizedDescription)"; return nil }
    }
    func export() -> String {
        exportData().flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

}

struct SceneRoute: Identifiable {
    let id = UUID()
    let sceneID: UUID
}
@MainActor final class NotificationRouter: ObservableObject {
    static let shared = NotificationRouter()
    @Published var request: SceneRoute?
}
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        await MainActor.run { NotificationCenter.default.post(name: .notificationStateDidChange, object: nil) }
        return [.banner, .sound, .list]
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if let value = response.notification.request.content.userInfo["sceneID"] as? String, let id = UUID(uuidString: value) {
            await MainActor.run { NotificationRouter.shared.request = SceneRoute(sceneID: id) }
        }
    }
}

extension Notification.Name {
    static let notificationStateDidChange = Notification.Name("reverie.notificationStateDidChange")
}
