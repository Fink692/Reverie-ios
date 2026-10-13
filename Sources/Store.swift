import SwiftUI
import UserNotifications

@MainActor final class StudioStore: ObservableObject {
    @Published var scenes: [StudioScene] = StudioScene.examples
    @Published var events: [SceneEvent] = []
    @Published var activeID = StudioScene.examples[0].id
    @Published var error: String?
    @Published var notificationStatus = "Not requested"
    @Published var pendingCount = 0
    private let file: URL
    var active: StudioScene { scenes.first(where: { $0.id == activeID }) ?? scenes[0] }
    var activity: [SceneEvent] { events.filter { $0.sceneID == activeID }.sorted { $0.date > $1.date } }
    init() {
        file = URL.documentsDirectory.appending(path: "reverie.json")
        if FileManager.default.fileExists(atPath: file.path) {
            do {
                let saved = try JSONDecoder().decode(Archive.self, from: Data(contentsOf: file))
                guard !saved.scenes.isEmpty, saved.scenes.contains(where: { $0.id == saved.activeID }), saved.scenes.allSatisfy({ $0.balance.isFinite && $0.sales.isFinite }) else { throw CocoaError(.fileReadCorruptFile) }
                scenes = saved.scenes; events = saved.events; activeID = saved.activeID
            } catch { self.error = "Your saved session could not be loaded. Starter scenes are available; the original file has not been overwritten." }
        }
    }
    func save() {
        do { try JSONEncoder().encode(Archive(scenes: scenes, events: events, activeID: activeID)).write(to: file, options: .atomic) }
        catch { self.error = "Could not save your changes: \(error.localizedDescription)" }
    }
    func select(_ scene: StudioScene) { activeID = scene.id; save() }
    func update(_ scene: StudioScene) { if let index = scenes.firstIndex(where: { $0.id == scene.id }) { scenes[index] = scene } else { scenes.append(scene) }; activeID = scene.id; save() }
    func delete(_ scene: StudioScene) {
        guard scenes.count > 1 else { return }
        scenes.removeAll { $0.id == scene.id }; events.removeAll { $0.sceneID == scene.id }
        if activeID == scene.id { activeID = scenes[0].id }; save()
    }
    func emit(kind: EventKind, amount: Double, detail: String) -> SceneEvent? {
        guard Simulation.validAmount(amount) else { error = "Enter an amount between 0.01 and 1 billion."; return nil }
        let event = SceneEvent(sceneID: activeID, kind: kind, amount: amount, detail: detail.trimmingCharacters(in: .whitespacesAndNewlines))
        if let index = scenes.firstIndex(where: { $0.id == activeID }) { scenes[index] = Simulation.applying(event, to: scenes[index]) }
        events.insert(event, at: 0); events = Array(events.prefix(1000)); save(); return event
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
        guard Simulation.validAmount(amount), (1...20).contains(count) else { error = "Check the amount and notification count."; return false }
        let center = UNUserNotificationCenter.current()
        do {
            let allowed = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard allowed else { error = "Notifications are disabled. Enable Reverie notifications in iOS Settings."; await refreshNotifications(); return false }
            let pending = await center.pendingNotificationRequests()
            guard pending.count + count <= 60 else { error = "Cancel queued notifications before adding this session."; return false }
            var added: [String] = []
            do {
                for i in 0..<count {
                    let event = SceneEvent(sceneID: activeID, kind: kind, amount: amount, detail: detail)
                    let content = UNMutableNotificationContent()
                    content.title = event.title; content.body = event.body(scene: active)
                    content.sound = .default; content.threadIdentifier = activeID.uuidString
                    content.userInfo = ["sceneID": activeID.uuidString]
                    let id = "reverie.\(event.id.uuidString)"
                    try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(2, delay) + Double(i) * 10, repeats: false)))
                    added.append(id)
                }
            } catch { center.removePendingNotificationRequests(withIdentifiers: added); throw error }
            await refreshNotifications(); return true
        } catch { self.error = "Could not schedule notifications: \(error.localizedDescription)"; return false }
    }
    func cancelNotifications() async { UNUserNotificationCenter.current().removeAllPendingNotificationRequests(); await refreshNotifications() }
    func reset() async { await cancelNotifications(); scenes = StudioScene.examples; activeID = scenes[0].id; events = []; save() }
    func export() -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? String(data: encoder.encode(Archive(scenes: scenes, events: events, activeID: activeID)), encoding: .utf8)) ?? ""
    }
}
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .sound, .list] }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if let id = response.notification.request.content.userInfo["sceneID"] as? String {
            await MainActor.run { NotificationCenter.default.post(name: .openScene, object: id) }
        }
    }
}
extension Notification.Name { static let openScene = Notification.Name("openScene") }
