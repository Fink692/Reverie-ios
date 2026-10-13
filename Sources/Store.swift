import SwiftUI
import UserNotifications

@MainActor final class StudioStore: ObservableObject {
    @Published private(set) var scenes: [StudioScene] = StudioScene.examples
    @Published private(set) var events: [SceneEvent] = []
    @Published private(set) var presets: [NotificationPreset] = []
    @Published private(set) var queuedAlerts: [QueuedAlert] = []
    @Published private(set) var commerceProfiles: [CommerceProfile] = []
    @Published private(set) var bankProfiles: [BankProfile] = []
    @Published private(set) var portfolioProfiles: [PortfolioProfile] = []
    @Published private(set) var walletProfiles: [WalletProfile] = []
    @Published private(set) var predictionProfiles: [PredictionProfile] = []
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
                portfolioProfiles = saved.portfolioProfiles; walletProfiles = saved.walletProfiles; predictionProfiles = saved.predictionProfiles
            }
        } catch {
            self.error = "Your saved session could not be loaded. Starter scenes are available. The original file will be preserved in a recovery backup before new changes are saved."
        }
    }
    private func snapshot(scenes: [StudioScene]? = nil, events: [SceneEvent]? = nil, activeID: UUID? = nil,
                          presets: [NotificationPreset]? = nil, commerceProfiles: [CommerceProfile]? = nil,
                          bankProfiles: [BankProfile]? = nil, portfolioProfiles: [PortfolioProfile]? = nil,
                          walletProfiles: [WalletProfile]? = nil, predictionProfiles: [PredictionProfile]? = nil) -> Archive {
        Archive(scenes: scenes ?? self.scenes, events: events ?? self.events, activeID: activeID ?? self.activeID,
                presets: presets ?? self.presets, commerceProfiles: commerceProfiles ?? self.commerceProfiles,
                bankProfiles: bankProfiles ?? self.bankProfiles, portfolioProfiles: portfolioProfiles ?? self.portfolioProfiles,
                walletProfiles: walletProfiles ?? self.walletProfiles, predictionProfiles: predictionProfiles ?? self.predictionProfiles)
    }
    private func persist(_ archive: Archive) -> Bool {
        do { try storage.save(archive); return true }
        catch { self.error = "Could not save your changes: \(error.localizedDescription)"; return false }
    }
    func save() {
        _ = persist(snapshot(scenes: scenes, events: events, activeID: activeID, presets: presets, commerceProfiles: commerceProfiles, bankProfiles: bankProfiles))
    }
    func select(_ scene: StudioScene) {
        guard scenes.contains(where: { $0.id == scene.id }),
              persist(snapshot(scenes: scenes, events: events, activeID: scene.id, presets: presets, commerceProfiles: commerceProfiles, bankProfiles: bankProfiles)) else { return }
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
        let portfolios = portfolioProfiles.filter { $0.sceneID != scene.id || scene.kind == .portfolio }
        let wallets = walletProfiles.filter { $0.sceneID != scene.id || scene.kind == .wallet }
        let predictions = predictionProfiles.filter { $0.sceneID != scene.id || scene.kind == .prediction }
        guard persist(snapshot(scenes: updated, events: events, activeID: scene.id, presets: presets,
            portfolioProfiles: portfolios, walletProfiles: wallets, predictionProfiles: predictions)) else { return false }
        scenes = updated; activeID = scene.id
        portfolioProfiles = portfolios; walletProfiles = wallets; predictionProfiles = predictions
        return true
    }
    func delete(_ scene: StudioScene) {
        guard scenes.count > 1, scenes.contains(where: { $0.id == scene.id }) else { return }
        let remaining = scenes.filter { $0.id != scene.id }
        let remainingEvents = events.filter { $0.sceneID != scene.id }
        let selection = activeID == scene.id ? remaining[0].id : activeID
        guard persist(snapshot(scenes: remaining, events: remainingEvents, activeID: selection, presets: presets,
            commerceProfiles: commerceProfiles.filter { $0.sceneID != scene.id }, bankProfiles: bankProfiles.filter { $0.sceneID != scene.id },
            portfolioProfiles: portfolioProfiles.filter { $0.sceneID != scene.id }, walletProfiles: walletProfiles.filter { $0.sceneID != scene.id },
            predictionProfiles: predictionProfiles.filter { $0.sceneID != scene.id })) else { return }
        notificationGeneration += 1
        scenes = remaining; events = remainingEvents; activeID = selection
        commerceProfiles.removeAll { $0.sceneID == scene.id }; bankProfiles.removeAll { $0.sceneID == scene.id }
        portfolioProfiles.removeAll { $0.sceneID == scene.id }; walletProfiles.removeAll { $0.sceneID == scene.id }
        predictionProfiles.removeAll { $0.sceneID == scene.id }
        Task {
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.content.userInfo["sceneID"] as? String == scene.id.uuidString }.map(\.identifier))
            let delivered = await center.deliveredNotifications()
            center.removeDeliveredNotifications(withIdentifiers: delivered.filter { $0.request.content.userInfo["sceneID"] as? String == scene.id.uuidString }.map { $0.request.identifier })
            await refreshNotifications()
        }
    }
    @discardableResult func emit(kind: EventKind, amount: Double, detail: String, sceneID: UUID? = nil,
                                customerName: String? = nil, itemCount: Int? = nil, orderNumber: Int? = nil,
                                style: NotificationStyle? = nil, customTitle: String? = nil) -> SceneEvent? {
        let value = kind == .subscriber ? 0.01 : amount
        guard Simulation.validAmount(value), detail.count <= 240 else {
            error = "Enter an amount between 0.01 and 1 billion and details up to 240 characters."; return nil
        }
        let targetID = sceneID ?? activeID
        guard let index = scenes.firstIndex(where: { $0.id == targetID }) else { return nil }
        if let style, !style.canEmit || style.eventKind != kind || !style.isAvailable(for: scenes[index].kind) {
            error = "This notification style can be queued but cannot change this dashboard's totals."; return nil
        }
        var event = SceneEvent(sceneID: targetID, kind: kind, amount: value, detail: detail.trimmingCharacters(in: .whitespacesAndNewlines))
        event.style = style
        event.customTitle = customTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        event.customerName = customerName?.trimmingCharacters(in: .whitespacesAndNewlines)
        event.itemCount = itemCount
        event.orderNumber = orderNumber
        if kind == .order {
            event.orderNumber = orderNumber ?? 1001 + scenes[index].orders
            event.customerName = event.customerName ?? "Online customer"
            event.itemCount = itemCount ?? 2
        }
        guard event.isValid else { error = "Check the title, customer name, item count, and order number."; return nil }
        let updated = Simulation.applying(event, to: scenes[index])
        guard updated != scenes[index] else { error = "This event would exceed the dashboard limits or available balance. Adjust the amount or totals in Edit scene."; return nil }
        var updatedScenes = scenes
        updatedScenes[index] = updated
        let updatedEvents = Array(([event] + events).prefix(1000))
        guard persist(snapshot(scenes: updatedScenes, events: updatedEvents, activeID: activeID, presets: presets, commerceProfiles: commerceProfiles, bankProfiles: bankProfiles)) else { return nil }
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
    func schedule(kind: EventKind, amount: Double, detail: String, delay: Double, count: Int,
                  style: NotificationStyle? = nil, interval: Double = 10, customerName: String? = nil,
                  itemCount: Int? = nil, orderNumber: Int? = nil, customTitle: String? = nil) async -> Bool {
        guard !isScheduling, !isResetting else { error = "Wait for the current session operation to finish."; return false }
        let scheduledScene = active
        guard NotificationPlan.make(scene: scheduledScene, kind: kind, amount: amount, detail: detail, delay: delay,
            count: count, pendingCount: 0, style: style, interval: interval, customerName: customerName,
            itemCount: itemCount, orderNumber: orderNumber, customTitle: customTitle) != nil else {
            error = "Check the notification style, amount, details, order fields, delay, count, and interval."; return false
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
                let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Reverie"
                error = "Notifications are disabled. Enable \(appName) notifications in iOS Settings."; await refreshNotifications(); return false
            }
            let pending = await center.pendingNotificationRequests()
            guard stillValid() else { return false }
            guard let plan = NotificationPlan.make(scene: scheduledScene, kind: kind, amount: amount, detail: detail,
                delay: delay, count: count, pendingCount: pending.count, style: style, interval: interval,
                customerName: customerName, itemCount: itemCount, orderNumber: orderNumber, customTitle: customTitle) else {
                error = "Cancel queued notifications before adding this session."; return false
            }
            for cue in plan {
                guard stillValid() else {
                    center.removePendingNotificationRequests(withIdentifiers: added); await refreshNotifications(); return false
                }
                let content = UNMutableNotificationContent()
                content.title = cue.event.title; content.body = cue.event.body(scene: scheduledScene)
                content.sound = scheduledScene.kind == .commerce && cue.event.kind == .order && (style == nil || style == .shopifyOrder)
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
            scenes = starter.scenes; activeID = starter.activeID; events = []; presets = []; commerceProfiles = []; bankProfiles = []; portfolioProfiles = []; walletProfiles = []; predictionProfiles = []
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
            try storage.save(snapshot(scenes: scenes, events: events, activeID: activeID, presets: updated, commerceProfiles: commerceProfiles, bankProfiles: bankProfiles))
            presets = updated; return true
        } catch { self.error = "Could not save your cue: \(error.localizedDescription)"; return false }
    }
    func deletePreset(_ preset: NotificationPreset) {
        let updated = presets.filter { $0.id != preset.id }
        do {
            try storage.save(snapshot(scenes: scenes, events: events, activeID: activeID, presets: updated, commerceProfiles: commerceProfiles, bankProfiles: bankProfiles))
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
            portfolioProfiles = archive.portfolioProfiles; walletProfiles = archive.walletProfiles; predictionProfiles = archive.predictionProfiles
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
    func portfolioProfile(for sceneID: UUID) -> PortfolioProfile {
        portfolioProfiles.first { $0.sceneID == sceneID } ?? .starter(for: sceneID)
    }
    func walletProfile(for sceneID: UUID) -> WalletProfile {
        walletProfiles.first { $0.sceneID == sceneID } ?? .starter(for: sceneID)
    }
    func predictionProfile(for sceneID: UUID) -> PredictionProfile {
        predictionProfiles.first { $0.sceneID == sceneID } ?? .starter(for: sceneID)
    }
    @discardableResult func preparePlayback(for sceneID: UUID) -> Bool {
        guard let scene = scenes.first(where: { $0.id == sceneID }) else { return false }
        if scene.kind == .commerce && !commerceProfiles.contains(where: { $0.sceneID == sceneID }) {
            return updateCommerceProfile(.starter(for: sceneID))
        }
        if scene.kind == .banking && !bankProfiles.contains(where: { $0.sceneID == sceneID }) {
            return updateBankProfile(.starter(for: sceneID))
        }
        if scene.kind == .portfolio && !portfolioProfiles.contains(where: { $0.sceneID == sceneID }) {
            return updatePortfolioProfile(.starter(for: sceneID))
        }
        if scene.kind == .wallet && !walletProfiles.contains(where: { $0.sceneID == sceneID }) {
            return updateWalletProfile(.starter(for: sceneID))
        }
        if scene.kind == .prediction && !predictionProfiles.contains(where: { $0.sceneID == sceneID }) {
            return updatePredictionProfile(.starter(for: sceneID))
        }
        return true
    }
    @discardableResult func updatePortfolioProfile(_ profile: PortfolioProfile, cashBalance: Double? = nil) -> Bool {
        guard profile.isValid, let sceneIndex = scenes.firstIndex(where: { $0.id == profile.sceneID && $0.kind == .portfolio }) else {
            error = "Check the portfolio assets, prices, charts, and activity."; return false
        }
        var updatedScenes = scenes
        if let cashBalance { updatedScenes[sceneIndex].balance = cashBalance }
        guard updatedScenes[sceneIndex].isValid, MarketValidation.nonnegative(profile.total(cash: updatedScenes[sceneIndex].balance)) else {
            error = "Cash and total portfolio value must be between zero and 1 billion."; return false
        }
        var updatedProfiles = portfolioProfiles
        if let index = updatedProfiles.firstIndex(where: { $0.sceneID == profile.sceneID }) { updatedProfiles[index] = profile }
        else { updatedProfiles.append(profile) }
        guard persist(snapshot(scenes: updatedScenes, portfolioProfiles: updatedProfiles)) else { return false }
        scenes = updatedScenes; portfolioProfiles = updatedProfiles
        return true
    }
    @discardableResult func updateWalletProfile(_ profile: WalletProfile) -> Bool {
        guard profile.isValid, scenes.contains(where: { $0.id == profile.sceneID && $0.kind == .wallet }) else {
            error = "Check the wallet address, tokens, quantities, prices, and activity."; return false
        }
        var updated = walletProfiles
        if let index = updated.firstIndex(where: { $0.sceneID == profile.sceneID }) { updated[index] = profile }
        else { updated.append(profile) }
        guard persist(snapshot(walletProfiles: updated)) else { return false }
        walletProfiles = updated
        return true
    }
    @discardableResult func updatePredictionProfile(_ profile: PredictionProfile, cashBalance: Double? = nil) -> Bool {
        guard profile.isValid, let sceneIndex = scenes.firstIndex(where: { $0.id == profile.sceneID && $0.kind == .prediction }) else {
            error = "Check the markets, probabilities, positions, and activity."; return false
        }
        var updatedScenes = scenes
        if let cashBalance { updatedScenes[sceneIndex].balance = cashBalance }
        guard updatedScenes[sceneIndex].isValid, MarketValidation.nonnegative(profile.total(cash: updatedScenes[sceneIndex].balance)) else {
            error = "Cash and total prediction account value must be between zero and 1 billion."; return false
        }
        var updatedProfiles = predictionProfiles
        if let index = updatedProfiles.firstIndex(where: { $0.sceneID == profile.sceneID }) { updatedProfiles[index] = profile }
        else { updatedProfiles.append(profile) }
        guard persist(snapshot(scenes: updatedScenes, predictionProfiles: updatedProfiles)) else { return false }
        scenes = updatedScenes; predictionProfiles = updatedProfiles
        return true
    }
    @discardableResult func executeMarketTrade(sceneID: UUID, assetID: UUID, side: MarketTradeSide, units: Double) -> MarketTransaction? {
        guard MarketValidation.quantity(units, allowZero: false),
              let scene = scenes.first(where: { $0.id == sceneID && $0.kind == .portfolio }) else {
            error = "Choose an investing scene and a positive number of units."; return nil
        }
        var profile = portfolioProfile(for: sceneID)
        guard profile.isValid, let index = profile.positions.firstIndex(where: { $0.id == assetID }) else {
            error = "This asset is unavailable in the selected portfolio."; return nil
        }
        let asset = profile.positions[index]
        let trade = MarketTransaction(assetID: assetID, symbol: asset.symbol, side: side, units: units, price: asset.price)
        guard trade.isValid else { error = "The trade value must be positive and no greater than 1 billion."; return nil }
        var cash = scene.balance
        if side == .buy {
            guard trade.total <= cash else { error = "There is not enough available cash to buy these units."; return nil }
            let quantity = asset.units + units
            profile.positions[index].averageCost = (asset.costBasis + trade.total) / quantity
            profile.positions[index].units = quantity
            cash -= trade.total
            guard quantity > asset.units, cash < scene.balance else { error = "The trade is too small for this account's balance or quantity."; return nil }
        } else {
            guard units <= asset.units else { error = "There are not enough owned units to sell."; return nil }
            profile.positions[index].units -= units
            if profile.positions[index].units == 0 { profile.positions[index].averageCost = 0 }
            cash += trade.total
            guard profile.positions[index].units < asset.units, cash > scene.balance else { error = "The trade is too small for this account's balance or quantity."; return nil }
        }
        profile.transactions = Array(([trade] + profile.transactions).prefix(1000))
        guard updatePortfolioProfile(profile, cashBalance: cash) else { return nil }
        return trade
    }
    @discardableResult func walletTransfer(sceneID: UUID, assetID: UUID, kind: WalletTransferKind, quantity: Double, address: String) -> WalletTransaction? {
        let address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard MarketValidation.quantity(quantity, allowZero: false), MarketValidation.address(address),
              scenes.contains(where: { $0.id == sceneID && $0.kind == .wallet }) else {
            error = "Choose a wallet, a positive token quantity, and a public address with 16 to 120 letters or digits."; return nil
        }
        var profile = walletProfile(for: sceneID)
        guard profile.isValid, let index = profile.holdings.firstIndex(where: { $0.id == assetID }) else {
            error = "This token is unavailable in the selected wallet."; return nil
        }
        let holding = profile.holdings[index]
        let transfer = WalletTransaction(assetID: assetID, symbol: holding.symbol, network: holding.network,
            address: address, kind: kind, quantity: quantity, price: holding.price)
        guard transfer.isValid else { error = "The transfer value must be positive and no greater than 1 billion."; return nil }
        if kind == .send {
            guard quantity <= holding.quantity else { error = "There are not enough available tokens to send."; return nil }
            profile.holdings[index].quantity -= quantity
            guard profile.holdings[index].quantity < holding.quantity else { error = "The transfer is too small for this token quantity."; return nil }
        } else {
            profile.holdings[index].quantity += quantity
            guard profile.holdings[index].quantity > holding.quantity else { error = "The transfer is too small for this token quantity."; return nil }
        }
        profile.transactions = Array(([transfer] + profile.transactions).prefix(1000))
        guard updateWalletProfile(profile) else { return nil }
        return transfer
    }
    @discardableResult func executePortfolioTransfer(sceneID: UUID, assetID: UUID, kind: WalletTransferKind, quantity: Double, address: String) -> WalletTransaction? {
        let address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard MarketValidation.quantity(quantity, allowZero: false), MarketValidation.address(address),
              scenes.contains(where: { $0.id == sceneID && $0.kind == .portfolio }) else {
            error = "Choose a crypto asset, a positive quantity, and a public address with 16 to 120 letters or digits."; return nil
        }
        var profile = portfolioProfile(for: sceneID)
        guard profile.isValid, let index = profile.positions.firstIndex(where: { $0.id == assetID && $0.kind == .crypto }) else {
            error = "This crypto asset is unavailable in the selected portfolio."; return nil
        }
        let asset = profile.positions[index]
        let transfer = WalletTransaction(assetID: assetID, symbol: asset.symbol, network: asset.transferNetwork,
            address: address, kind: kind, quantity: quantity, price: asset.price)
        guard transfer.isValid else { error = "The transfer value must be positive and no greater than 1 billion."; return nil }
        if kind == .send {
            guard quantity <= asset.units else { error = "There are not enough available crypto units to send."; return nil }
            profile.positions[index].units -= quantity
            if profile.positions[index].units == 0 { profile.positions[index].averageCost = 0 }
            guard profile.positions[index].units < asset.units else { error = "The transfer is too small for this crypto quantity."; return nil }
        } else {
            let receivedUnits = asset.units + quantity
            profile.positions[index].averageCost = (asset.costBasis + transfer.total) / receivedUnits
            profile.positions[index].units = receivedUnits
            guard receivedUnits > asset.units else { error = "The transfer is too small for this crypto quantity."; return nil }
        }
        profile.transfers = Array(([transfer] + profile.transfers).prefix(1000))
        guard updatePortfolioProfile(profile) else { return nil }
        return transfer
    }
    @discardableResult func tradePrediction(sceneID: UUID, marketID: UUID, outcome: PredictionOutcome, side: MarketTradeSide, shares: Double) -> PredictionTrade? {
        guard MarketValidation.quantity(shares, allowZero: false),
              let scene = scenes.first(where: { $0.id == sceneID && $0.kind == .prediction }) else {
            error = "Choose a prediction scene and a positive number of shares."; return nil
        }
        var profile = predictionProfile(for: sceneID)
        guard profile.isValid, let market = profile.market(for: marketID) else {
            error = "This market is unavailable in the selected account."; return nil
        }
        guard market.isOpen else { error = "This market is closed for trading. Edit its close date or probability to reopen the fictional market."; return nil }
        let trade = PredictionTrade(marketID: marketID, question: market.question, outcome: outcome, side: side,
            shares: shares, price: market.price(for: outcome))
        guard trade.isValid, trade.total > 0 else { error = "The trade value must be positive and no greater than 1 billion."; return nil }
        let index = profile.positions.firstIndex(where: { $0.marketID == marketID && $0.outcome == outcome })
        var cash = scene.balance
        if side == .buy {
            guard trade.total <= cash else { error = "There is not enough available cash to buy these shares."; return nil }
            if let index {
                let position = profile.positions[index]
                let quantity = position.shares + shares
                profile.positions[index].averagePrice = (position.costBasis + trade.total) / quantity
                profile.positions[index].shares = quantity
                guard quantity > position.shares else { error = "The trade is too small for this position."; return nil }
            } else {
                profile.positions.append(PredictionPosition(marketID: marketID, outcome: outcome, shares: shares, averagePrice: trade.price))
            }
            cash -= trade.total
            guard cash < scene.balance else { error = "The trade is too small for this account's cash balance."; return nil }
        } else {
            guard let index, shares <= profile.positions[index].shares else { error = "There are not enough owned shares of this outcome to sell."; return nil }
            let owned = profile.positions[index].shares
            profile.positions[index].shares -= shares
            if profile.positions[index].shares == 0 { profile.positions[index].averagePrice = 0 }
            cash += trade.total
            guard profile.positions[index].shares < owned, cash > scene.balance else { error = "The trade is too small for this position or cash balance."; return nil }
        }
        profile.transactions = Array(([trade] + profile.transactions).prefix(1000))
        guard updatePredictionProfile(profile, cashBalance: cash) else { return nil }
        return trade
    }
    @discardableResult func swapWallet(sceneID: UUID, fromAssetID: UUID, toAssetID: UUID, quantity: Double) -> Bool {
        guard fromAssetID != toAssetID, MarketValidation.quantity(quantity, allowZero: false),
              scenes.contains(where: { $0.id == sceneID && $0.kind == .wallet }) else {
            error = "Choose two different tokens and a positive swap quantity."; return false
        }
        var profile = walletProfile(for: sceneID)
        guard profile.isValid,
              let fromIndex = profile.holdings.firstIndex(where: { $0.id == fromAssetID }),
              let toIndex = profile.holdings.firstIndex(where: { $0.id == toAssetID }) else {
            error = "Both tokens must be available in the selected wallet."; return false
        }
        let from = profile.holdings[fromIndex]
        let to = profile.holdings[toIndex]
        guard quantity <= from.quantity else { error = "There are not enough available tokens to swap."; return false }
        let received = quantity * from.price / to.price
        let sentRecord = WalletTransaction(assetID: from.id, symbol: from.symbol, network: from.network,
            address: from.address ?? profile.address, kind: .send, quantity: quantity, price: from.price)
        let receivedRecord = WalletTransaction(assetID: to.id, symbol: to.symbol, network: to.network,
            address: to.address ?? profile.address, kind: .receive, quantity: received, price: to.price)
        guard sentRecord.isValid, receivedRecord.isValid else { error = "The swap quantities or value exceed this wallet's limits."; return false }
        profile.holdings[fromIndex].quantity -= quantity
        profile.holdings[toIndex].quantity += received
        guard profile.holdings[fromIndex].quantity < from.quantity, profile.holdings[toIndex].quantity > to.quantity else {
            error = "The swap is too small for these token quantities."; return false
        }
        profile.transactions = Array(([receivedRecord, sentRecord] + profile.transactions).prefix(1000))
        return updateWalletProfile(profile)
    }
    @discardableResult func updateCommerceProfile(_ profile: CommerceProfile) -> Bool {
        guard profile.isValid, scenes.contains(where: { $0.id == profile.sceneID }) else { error = "Check the store metrics, products, and orders."; return false }
        var updated = commerceProfiles
        if let index = updated.firstIndex(where: { $0.sceneID == profile.sceneID }) { updated[index] = profile }
        else { updated.append(profile) }
        guard persist(snapshot(scenes: scenes, events: events, activeID: activeID, presets: presets, commerceProfiles: updated, bankProfiles: bankProfiles)) else { return false }
        commerceProfiles = updated; return true
    }
    @discardableResult func updateBankProfile(_ profile: BankProfile) -> Bool {
        guard profile.isValid, scenes.contains(where: { $0.id == profile.sceneID }) else { error = "Check the account name, four-digit suffix, and savings amount."; return false }
        var updated = bankProfiles
        if let index = updated.firstIndex(where: { $0.sceneID == profile.sceneID }) { updated[index] = profile }
        else { updated.append(profile) }
        guard persist(snapshot(scenes: scenes, events: events, activeID: activeID, presets: presets, commerceProfiles: commerceProfiles, bankProfiles: updated)) else { return false }
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
        guard persist(snapshot(scenes: updatedScenes, events: updatedEvents, activeID: activeID,
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
        do { return try snapshot(scenes: scenes, events: events, activeID: activeID, presets: presets, commerceProfiles: commerceProfiles, bankProfiles: bankProfiles).encoded(prettyPrinted: true) }
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
