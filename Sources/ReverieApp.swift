import SwiftUI
import UserNotifications

struct AppPlaybackConfiguration {
    let kind: SceneKind
    let bank: BankTheme?

    static var current: AppPlaybackConfiguration? {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ui-test-session"), let index = arguments.firstIndex(of: "-ui-test-brand"), arguments.indices.contains(index + 1) {
            let value = arguments[index + 1]
            if value == "commerce" { return AppPlaybackConfiguration(kind: .commerce, bank: nil) }
            if let bank = BankTheme(rawValue: value) { return AppPlaybackConfiguration(kind: .banking, bank: bank) }
            return nil
        }
        guard let rawKind = Bundle.main.object(forInfoDictionaryKey: "ReveriePlaybackKind") as? String,
              let kind = SceneKind(rawValue: rawKind), kind != .creator else { return nil }
        let bank = (Bundle.main.object(forInfoDictionaryKey: "ReverieBankTheme") as? String).flatMap(BankTheme.init(rawValue:))
        guard kind != .banking || bank != nil else { return nil }
        return AppPlaybackConfiguration(kind: kind, bank: bank)
    }
}

@main struct ReverieApp: App {
    @StateObject private var store: StudioStore
    @StateObject private var router = NotificationRouter.shared
    @AppStorage("welcomed") private var welcomed = false
    private let preferences: UserDefaults
    private let delegate = NotificationDelegate()
    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let defaults: UserDefaults
        let startupStore: StudioStore
        if let index = arguments.firstIndex(of: "-ui-test-session"), arguments.indices.contains(index + 1),
           let session = UUID(uuidString: arguments[index + 1]) {
            defaults = UserDefaults(suiteName: "reverie.ui-tests.\(session.uuidString)") ?? .standard
            startupStore = StudioStore(fileURL: FileManager.default.temporaryDirectory.appending(path: "reverie-ui-\(session.uuidString).json"))
        } else {
            defaults = .standard
            startupStore = StudioStore()
        }
        if AppPlaybackConfiguration.current != nil, defaults.object(forKey: "cleanPlayback") == nil {
            defaults.set(true, forKey: "cleanPlayback")
        }
        if let configuration = AppPlaybackConfiguration.current, !defaults.bool(forKey: "brandConfigured"),
           var scene = startupStore.scenes.first(where: { $0.kind == configuration.kind }) {
            if let bank = configuration.bank {
                scene.currency = bank.country == "United States" ? "USD" : "GBP"
                if startupStore.update(scene) {
                    var profile = BankProfile.starter(for: scene.id)
                    profile.theme = bank
                    if startupStore.updateBankProfile(profile) { defaults.set(true, forKey: "brandConfigured") }
                }
            } else {
                startupStore.select(scene)
                if startupStore.activeID == scene.id, startupStore.preparePlayback(for: scene.id) { defaults.set(true, forKey: "brandConfigured") }
            }
        }
        if let bank = AppPlaybackConfiguration.current?.bank,
           var scene = startupStore.scenes.first(where: { $0.id == startupStore.activeID && $0.kind == .banking }) ?? startupStore.scenes.first(where: { $0.kind == .banking }) {
            let hasProfile = startupStore.bankProfiles.contains(where: { $0.sceneID == scene.id })
            if !hasProfile {
                scene.currency = bank.country == "United States" ? "USD" : "GBP"
                _ = startupStore.update(scene)
            }
            var profile = startupStore.bankProfile(for: scene.id)
            if !hasProfile || profile.theme != bank {
                profile.theme = bank
                _ = startupStore.updateBankProfile(profile)
            }
        }
        preferences = defaults
        _welcomed = AppStorage(wrappedValue: false, "welcomed", store: defaults)
        _store = StateObject(wrappedValue: startupStore)
        UNUserNotificationCenter.current().delegate = delegate
    }
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store)
                .defaultAppStorage(preferences)
                .sheet(isPresented: Binding(get: { !welcomed }, set: { welcomed = !$0 }), onDismiss: {
                    if welcomed { NotificationCenter.default.post(name: .welcomeCompleted, object: nil) }
                }) {
                    WelcomeView { welcomed = true }.interactiveDismissDisabled()
                }
                .alert("Something needs attention", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                    Button("OK") { store.error = nil }
                } message: { Text(store.error ?? "") }
                .onReceive(router.$request) { route in
                    if let route, let scene = store.scenes.first(where: { $0.id == route.sceneID }) { store.select(scene) }
                }
        }
    }
}
