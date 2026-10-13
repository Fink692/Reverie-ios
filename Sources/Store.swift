import SwiftUI
import UserNotifications

@MainActor final class StudioStore: ObservableObject {
    @Published private(set) var scenes: [StudioScene] = StudioScene.examples
    @Published private(set) var events: [SceneEvent] = []
    @Published private(set) var presets: [NotificationPreset] = []
    @Published private(set) var queuedAlerts: [QueuedAlert] = []
    @Published private(set) var commerceProfiles: [CommerceProfile] = []
    @Published private(set) var bankProfiles: [BankProfile] = []
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
                scenes = saved.scenes; events = saved.events; activeID = saved.activeID; presets = saved.presets; commerceProfiles = saved.commerceProfiles; bankProfiles = saved.bankProfiles
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
        _ = persist(Archive(scenes: scenes, events: events, activeID: activeID, presets: presets, commerceProfiles: commerceProfiles, bankProfiles: bankProfiles))
    }
    func select(_ scene: StudioScene) {
        guard scenes.contains(where: { $0.id == scene.id }),
              persist(Archive(scenes: scenes, events: events, activeID: scene.id, presets: presets, commerceProfiles: commerceProfiles, bankProfiles: bankProfiles)) else { return }
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
        guard persist(Archive(scenes: updated, events: events, activeID: scene.id, presets: presets, commerceProfiles: commerceProfiles, bankProfiles: bankProfiles)) else { return false }
        scenes = updated; activeID = scene.id
        return true
    }
    func delete(_ scene: StudioScene) {
        guard scenes.count > 1, scenes.contains(where: { $0.id == scene.id }) else { return }
        let remaining = scenes.filter { $0.id != scene.id }
        let remainingEvents = events.filter { $0.sceneID != scene.id }
        let selection = activeID == scene.id ? remaining[0].id : activeID
        guard persist(Archive(scenes: remaining, events: remainingEvents, activeID: selection, presets: presets, commerceProfiles: commerceProfiles.filter { $0.sceneID != scene.id }, bankProfiles: bankProfiles.filter { $0.sceneID != scene.id })) else { return }
        notificationGeneration += 1
        scenes = remaining; events = remainingEvents; activeID = selection
        commerceProfiles.removeAll { $0.sceneID == scene.id }; bankProfiles.removeAll { $0.sceneID == scene.id }
        Task {
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.content.userInfo["sceneID"] as? String == scene.id.uuidString }.map(\.identifier))
            let delivered = await center.deliveredNotifications()
            center.removeDeliveredNotifications(withIdentifiers: delivered.filter { $0.request.content.userInfo["sceneID"] as? String == scene.id.uuidString }.map { $0.request.identifier })
            await refreshNotifications()
        }
    }
    @discardableResult func emit(kind: EventKind, amount: Double, detail: String, sceneID: UUID? = nil, customerName: String? = nil, itemCount: Int? = nil) -> SceneEvent? {
        let value = kind == .subscriber ? 0.01 : amount
        guard Simulation.validAmount(value), detail.count <= 240 else {
            error = "Enter an amount between 0.01 and 1 billion and details up to 240 characters."; return nil
        }
        let targetID = sceneID ?? activeID
        guard let index = scenes.firstIndex(where: { $0.id == targetID }) else { return nil }
        var event = SceneEvent(sceneID: targetID, kind: kind, amount: value, detail: detail.trimmingCharacters(in: .whitespacesAndNewlines))
        if kind == .order {
            event.orderNumber = 1001 + scenes[index].orders
            event.customerName = customerName ?? "Online customer"
            event.itemCount = itemCount ?? 2
        }
        let updated = Simulation.applying(event, to: scenes[index])
        guard updated != scenes[index] else { error = "This event would exceed the dashboard limits or available balance. Adjust the amount or totals in Edit scene."; return nil }
        var updatedScenes = scenes
        updatedScenes[index] = updated
        let updatedEvents = Array(([event] + events).prefix(1000))
        guard persist(Archive(scenes: updatedScenes, events: updatedEvents, activeID: activeID, presets: presets, commerceProfiles: commerceProfiles, bankProfiles: bankProfiles)) else { return nil }
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
                content.sound = scheduledScene.kind == .commerce && kind == .order
                    ? UNNotificationSound(named: UNNotificationSoundName("Order.caf")) : .default
                content.threadIdentifier = scheduledScene.id.uuidString
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
            scenes = starter.scenes; activeID = starter.activeID; events = []; presets = []; commerceProfiles = []; bankProfiles = []
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
            try storage.save(Archive(scenes: scenes, events: events, activeID: activeID, presets: updated, commerceProfiles: commerceProfiles, bankProfiles: bankProfiles))
            presets = updated; return true
        } catch { self.error = "Could not save your cue: \(error.localizedDescription)"; return false }
    }
    func deletePreset(_ preset: NotificationPreset) {
        let updated = presets.filter { $0.id != preset.id }
        do {
            try storage.save(Archive(scenes: scenes, events: events, activeID: activeID, presets: updated, commerceProfiles: commerceProfiles, bankProfiles: bankProfiles))
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
            scenes = archive.scenes; events = archive.events; activeID = archive.activeID; presets = archive.presets; commerceProfiles = archive.commerceProfiles; bankProfiles = archive.bankProfiles
            let center = UNUserNotificationCenter.current()
            center.removeAllPendingNotificationRequests(); center.removeAllDeliveredNotifications()
            NotificationRouter.shared.request = nil
            await refreshNotifications()
            return true
        } catch { self.error = "Could not import this session: \(error.localizedDescription)"; return false }
    }
    func commerceProfile(for sceneID: UUID) -> CommerceProfile {
        commerceProfiles.first { $0.sceneID == sceneID } ?? .starter(for: sceneID)
    }
    func bankProfile(for sceneID: UUID) -> BankProfile {
        bankProfiles.first { $0.sceneID == sceneID } ?? .starter(for: sceneID)
    }
    @discardableResult func preparePlayback(for sceneID: UUID) -> Bool {
        guard let scene = scenes.first(where: { $0.id == sceneID }) else { return false }
        if scene.kind == .commerce && !commerceProfiles.contains(where: { $0.sceneID == sceneID }) {
            return updateCommerceProfile(.starter(for: sceneID))
        }
        if scene.kind == .banking && !bankProfiles.contains(where: { $0.sceneID == sceneID }) {
            return updateBankProfile(.starter(for: sceneID))
        }
        return true
    }
    @discardableResult func updateCommerceProfile(_ profile: CommerceProfile) -> Bool {
        guard profile.isValid, scenes.contains(where: { $0.id == profile.sceneID }) else { error = "Check the store metrics, products, and orders."; return false }
        var updated = commerceProfiles
        if let index = updated.firstIndex(where: { $0.sceneID == profile.sceneID }) { updated[index] = profile }
        else { updated.append(profile) }
        guard persist(Archive(scenes: scenes, events: events, activeID: activeID, presets: presets, commerceProfiles: updated, bankProfiles: bankProfiles)) else { return false }
        commerceProfiles = updated; return true
    }
    @discardableResult func updateBankProfile(_ profile: BankProfile) -> Bool {
        guard profile.isValid, scenes.contains(where: { $0.id == profile.sceneID }) else { error = "Check the account name, four-digit suffix, and savings amount."; return false }
        var updated = bankProfiles
        if let index = updated.firstIndex(where: { $0.sceneID == profile.sceneID }) { updated[index] = profile }
        else { updated.append(profile) }
        guard persist(Archive(scenes: scenes, events: events, activeID: activeID, presets: presets, commerceProfiles: commerceProfiles, bankProfiles: updated)) else { return false }
        bankProfiles = updated; return true
    }
    @discardableResult func transferSavings(sceneID: UUID, amount: Double, toSavings: Bool) -> Bool {
        guard Simulation.validAmount(amount),
              let sceneIndex = scenes.firstIndex(where: { $0.id == sceneID && $0.kind == .banking }) else {
            error = "Choose a banking account and a valid transfer amount."; return false
        }
        let originalScene = scenes[sceneIndex]
        var updatedScene = originalScene
        var profile = bankProfile(for: sceneID)
        guard profile.isValid else { error = "Check the savings account details."; return false }
        if toSavings {
            guard amount <= originalScene.balance, profile.savings + amount <= 1_000_000_000 else {
                error = "The transfer exceeds the available checking balance or savings limit."; return false
            }
            updatedScene.balance -= amount
            profile.savings += amount
        } else {
            guard amount <= profile.savings, originalScene.balance + amount <= 1_000_000_000 else {
                error = "The transfer exceeds the available savings balance or checking limit."; return false
            }
            updatedScene.balance += amount
            profile.savings -= amount
        }
        guard updatedScene.isValid, profile.isValid else { error = "The transfer would exceed this account's limits."; return false }
        var event = SceneEvent(sceneID: sceneID, kind: toSavings ? .payment : .deposit, amount: amount,
            detail: toSavings ? "Transfer to savings" : "Transfer from savings")
        event.savingsTransfer = true
        var updatedScenes = scenes
        updatedScenes[sceneIndex] = updatedScene
        var updatedProfiles = bankProfiles
        if let profileIndex = updatedProfiles.firstIndex(where: { $0.sceneID == sceneID }) { updatedProfiles[profileIndex] = profile }
        else { updatedProfiles.append(profile) }
        let updatedEvents = Array(([event] + events).prefix(1000))
        guard persist(Archive(scenes: updatedScenes, events: updatedEvents, activeID: activeID,
            presets: presets, commerceProfiles: commerceProfiles, bankProfiles: updatedProfiles)) else { return false }
        scenes = updatedScenes
        bankProfiles = updatedProfiles
        events = updatedEvents
        return true
    }
    func commerceOrders(for sceneID: UUID) -> [CommerceOrder] {
        let profile = commerceProfile(for: sceneID)
        var orders = profile.initialOrders
        let sceneEvents = events.filter { $0.sceneID == sceneID && $0.kind == .order }.sorted { $0.date < $1.date }
        for (index, event) in sceneEvents.enumerated() {
            orders.append(CommerceOrder(id: event.id, number: event.orderNumber ?? 1001 + index,
                customer: event.customerName ?? "Online customer", itemCount: event.itemCount ?? 2,
                total: event.amount, date: event.date, fulfillment: .unfulfilled, isPaid: true))
        }
        return orders.map { order in
            var value = order
            if let state = profile.orderStates.first(where: { $0.id == order.id }) {
                value.fulfillment = state.fulfillment
                value.isPaid = state.isPaid ?? value.isPaid
            }
            return value
        }.sorted { $0.date > $1.date }
    }
    @discardableResult func setOrderStatus(orderID: UUID, sceneID: UUID, status: CommerceFulfillment) -> Bool {
        guard commerceOrders(for: sceneID).contains(where: { $0.id == orderID }) else { return false }
        var profile = commerceProfile(for: sceneID)
        if let index = profile.orderStates.firstIndex(where: { $0.id == orderID }) { profile.orderStates[index].fulfillment = status }
        else { profile.orderStates.append(CommerceOrderState(id: orderID, fulfillment: status)) }
        return updateCommerceProfile(profile)
    }
    @discardableResult func setOrderPaid(orderID: UUID, sceneID: UUID, isPaid: Bool) -> Bool {
        guard scenes.contains(where: { $0.id == sceneID && $0.kind == .commerce }),
              let order = commerceOrders(for: sceneID).first(where: { $0.id == orderID }) else { return false }
        var profile = commerceProfile(for: sceneID)
        if let index = profile.orderStates.firstIndex(where: { $0.id == orderID }) { profile.orderStates[index].isPaid = isPaid }
        else { profile.orderStates.append(CommerceOrderState(id: orderID, fulfillment: order.fulfillment, isPaid: isPaid)) }
        return updateCommerceProfile(profile)
    }
    @discardableResult func addCommerceOrder(sceneID: UUID, customer: String, itemCount: Int, total: Double) -> SceneEvent? {
        guard let scene = scenes.first(where: { $0.id == sceneID }), scene.kind == .commerce,
              !customer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, customer.count <= 80,
              (1...1000).contains(itemCount) else { error = "Check the customer name and item count."; return nil }
        return emit(kind: .order, amount: total, detail: "\(customer) · \(itemCount) items", sceneID: sceneID,
            customerName: customer.trimmingCharacters(in: .whitespacesAndNewlines), itemCount: itemCount)
    }
    func exportData() -> Data? {
        do { return try Archive(scenes: scenes, events: events, activeID: activeID, presets: presets, commerceProfiles: commerceProfiles, bankProfiles: bankProfiles).encoded(prettyPrinted: true) }
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
    static let welcomeCompleted = Notification.Name("reverie.welcomeCompleted")
}
