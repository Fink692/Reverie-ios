import SwiftUI
import UserNotifications

struct AppPlaybackConfiguration {
    let kind: SceneKind
    let bank: BankTheme?
    let portfolio: PortfolioTheme?
    let wallet: WalletTheme?
    let prediction: PredictionTheme?

    init(kind: SceneKind, bank: BankTheme? = nil, portfolio: PortfolioTheme? = nil, wallet: WalletTheme? = nil, prediction: PredictionTheme? = nil) {
        self.kind = kind; self.bank = bank; self.portfolio = portfolio; self.wallet = wallet; self.prediction = prediction
    }

    static var current: AppPlaybackConfiguration? {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ui-test-session"), let index = arguments.firstIndex(of: "-ui-test-brand"), arguments.indices.contains(index + 1) {
            let value = arguments[index + 1]
            if value == "commerce" { return AppPlaybackConfiguration(kind: .commerce, bank: nil) }
            if let bank = BankTheme(rawValue: value) { return AppPlaybackConfiguration(kind: .banking, bank: bank) }
            if let theme = PortfolioTheme(rawValue: value) { return AppPlaybackConfiguration(kind: .portfolio, portfolio: theme) }
            if let theme = WalletTheme(rawValue: value) { return AppPlaybackConfiguration(kind: .wallet, wallet: theme) }
            if let theme = PredictionTheme(rawValue: value) { return AppPlaybackConfiguration(kind: .prediction, prediction: theme) }
            return nil
        }
        guard let rawKind = Bundle.main.object(forInfoDictionaryKey: "ReveriePlaybackKind") as? String,
              let kind = SceneKind(rawValue: rawKind), kind != .creator else { return nil }
        let bank = (Bundle.main.object(forInfoDictionaryKey: "ReverieBankTheme") as? String).flatMap(BankTheme.init(rawValue:))
        let portfolio = (Bundle.main.object(forInfoDictionaryKey: "ReveriePortfolioTheme") as? String).flatMap(PortfolioTheme.init(rawValue:))
        let wallet = (Bundle.main.object(forInfoDictionaryKey: "ReverieWalletTheme") as? String).flatMap(WalletTheme.init(rawValue:))
        let prediction = (Bundle.main.object(forInfoDictionaryKey: "ReveriePredictionTheme") as? String).flatMap(PredictionTheme.init(rawValue:))
        guard (kind != .banking || bank != nil), (kind != .portfolio || portfolio != nil),
              (kind != .wallet || wallet != nil), (kind != .prediction || prediction != nil) else { return nil }
        return AppPlaybackConfiguration(kind: kind, bank: bank, portfolio: portfolio, wallet: wallet, prediction: prediction)
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
        if let configuration = AppPlaybackConfiguration.current {
            var scene = startupStore.scenes.first(where: { $0.id == startupStore.activeID && $0.kind == configuration.kind })
                ?? startupStore.scenes.first(where: { $0.kind == configuration.kind })
            if scene == nil, var starter = StudioScene.examples.first(where: { $0.kind == configuration.kind }) {
                starter.id = UUID()
                if startupStore.update(starter) { scene = starter }
            }
            if var scene {
                var configured = false
                switch configuration.kind {
                case .commerce:
                    configured = startupStore.preparePlayback(for: scene.id)
                case .banking:
                    if let theme = configuration.bank {
                        let hasProfile = startupStore.bankProfiles.contains(where: { $0.sceneID == scene.id })
                        if !hasProfile { scene.currency = theme.country == "United States" ? "USD" : "GBP" }
                        if hasProfile || startupStore.update(scene) {
                            var profile = startupStore.bankProfile(for: scene.id)
                            profile.theme = theme
                            configured = startupStore.updateBankProfile(profile)
                        }
                    }
                case .portfolio:
                    if let theme = configuration.portfolio {
                        let hasProfile = startupStore.portfolioProfiles.contains(where: { $0.sceneID == scene.id })
                        if !hasProfile { scene.currency = theme == .wealthsimple ? "CAD" : "USD" }
                        if hasProfile || startupStore.update(scene) {
                            var profile = hasProfile ? startupStore.portfolioProfile(for: scene.id) : .starter(for: scene.id, theme: theme)
                            profile.theme = theme
                            configured = startupStore.updatePortfolioProfile(profile)
                        }
                    }
                case .wallet:
                    if let theme = configuration.wallet {
                        let hasProfile = startupStore.walletProfiles.contains(where: { $0.sceneID == scene.id })
                        var profile = hasProfile ? startupStore.walletProfile(for: scene.id) : .starter(for: scene.id, theme: theme)
                        profile.theme = theme
                        configured = startupStore.updateWalletProfile(profile)
                    }
                case .prediction:
                    if let theme = configuration.prediction {
                        var profile = startupStore.predictionProfile(for: scene.id)
                        profile.theme = theme
                        configured = startupStore.updatePredictionProfile(profile)
                    }
                case .creator: break
                }
                if configured {
                    startupStore.select(scene)
                    defaults.set(true, forKey: "brandConfigured")
                }
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
