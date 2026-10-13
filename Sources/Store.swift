import SwiftUI
import UserNotifications

@MainActor final class StudioStore: ObservableObject {
    @Published private(set) var scenes: [StudioScene] = StudioScene.examples
    @Published private(set) var events: [SceneEvent] = []
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
                scenes = saved.scenes; events = saved.events; activeID = saved.activeID
            }
        } catch {
            self.error = "Your saved session could not be loaded. Starter scenes are available. The original file will be preserved in a recovery backup before new changes are saved."
        }
    }
    func save() {
        do { try storage.save(Archive(scenes: scenes, events: events, activeID: activeID)) }
        catch { self.error = "Could not save your changes: \(error.localizedDescription)" }
    }
    func select(_ scene: StudioScene) {
        guard scenes.contains(where: { $0.id == scene.id }) else { return }
        activeID = scene.id; save()
    }
    func update(_ scene: StudioScene) {
        guard scene.isValid else { error = "Check the scene name, currency, and dashboard totals."; return }
        if let index = scenes.firstIndex(where: { $0.id == scene.id }) { scenes[index] = scene }
        else { scenes.append(scene) }
        activeID = scene.id; save()
    }
    func delete(_ scene: StudioScene) {
        guard scenes.count > 1, scenes.contains(where: { $0.id == scene.id }) else { return }
        notificationGeneration += 1
        scenes.removeAll { $0.id == scene.id }; events.removeAll { $0.sceneID == scene.id }
        if activeID == scene.id { activeID = scenes[0].id }
        save()
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
        scenes[index] = updated
        events.insert(event, at: 0); events = Array(events.prefix(1000)); save()
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
        pendingCount = await center.pendingNotificationRequests().count
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
                content.userInfo = ["sceneID": scheduledScene.id.uuidString]
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
        scenes = StudioScene.examples; activeID = scenes[0].id; events = []; save()
        await refreshNotifications()
    }
    func export() -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? String(data: encoder.encode(Archive(scenes: scenes, events: events, activeID: activeID)), encoding: .utf8)) ?? ""
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
