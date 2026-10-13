import SwiftUI
import UserNotifications

@main struct ReverieApp: App {
    @StateObject private var store: StudioStore
    @StateObject private var router = NotificationRouter.shared
    @AppStorage("welcomed") private var welcomed = false
    private let preferences: UserDefaults
    private let delegate = NotificationDelegate()
    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-ui-test-session"), arguments.indices.contains(index + 1),
           let session = UUID(uuidString: arguments[index + 1]) {
            let defaults = UserDefaults(suiteName: "reverie.ui-tests.\(session.uuidString)") ?? .standard
            preferences = defaults
            _welcomed = AppStorage(wrappedValue: false, "welcomed", store: defaults)
            _store = StateObject(wrappedValue: StudioStore(fileURL: FileManager.default.temporaryDirectory.appending(path: "reverie-ui-\(session.uuidString).json")))
        } else {
            preferences = .standard
            _welcomed = AppStorage(wrappedValue: false, "welcomed", store: .standard)
            _store = StateObject(wrappedValue: StudioStore())
        }
        UNUserNotificationCenter.current().delegate = delegate
    }
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store)
                .defaultAppStorage(preferences)
                .sheet(isPresented: Binding(get: { !welcomed }, set: { welcomed = !$0 })) {
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
