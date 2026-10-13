import SwiftUI
import UserNotifications

@main struct ReverieApp: App {
    @StateObject private var store = StudioStore()
    @StateObject private var router = NotificationRouter.shared
    @AppStorage("welcomed") private var welcomed = false
    private let delegate = NotificationDelegate()
    init() { UNUserNotificationCenter.current().delegate = delegate }
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store)
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
