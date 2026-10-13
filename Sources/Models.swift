import Foundation

enum SceneKind: String, Codable, CaseIterable, Identifiable {
    case commerce, banking, creator, portfolio, wallet, prediction
    var id: String { rawValue }
    var title: String {
        switch self {
        case .commerce: return "Store"
        case .banking: return "Banking"
        case .creator: return "Creator"
        case .portfolio: return "Investing"
        case .wallet: return "Crypto wallet"
        case .prediction: return "Prediction markets"
        }
    }
    var symbol: String {
        switch self {
        case .commerce: return "bag.fill"
        case .banking: return "building.columns.fill"
        case .creator: return "sparkles"
        case .portfolio: return "chart.line.uptrend.xyaxis"
        case .wallet: return "bitcoinsign.circle.fill"
        case .prediction: return "chart.bar.xaxis"
        }
    }
}

struct StudioScene: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var kind: SceneKind
    var balance: Double
    var sales: Double
    var orders: Int
    var audience: Int
    var currency = "USD"
    static let currencies = ["USD", "GBP", "EUR", "CAD", "AUD", "JPY"]
    static let examples: [StudioScene] = [
        StudioScene(name: "Studio Supply", kind: .commerce, balance: 24850, sales: 3842, orders: 28, audience: 1248),
        StudioScene(name: "Northstar", kind: .banking, balance: 84250.75, sales: 6420, orders: 16, audience: 0),
        StudioScene(name: "The daily edit", kind: .creator, balance: 18240, sales: 1250, orders: 42, audience: 128400),
        StudioScene(name: "My investments", kind: .portfolio, balance: 12500, sales: 0, orders: 0, audience: 0),
        StudioScene(name: "Wallet 1", kind: .wallet, balance: 0, sales: 0, orders: 0, audience: 0),
        StudioScene(name: "My predictions", kind: .prediction, balance: 2500, sales: 0, orders: 0, audience: 0)
    ]
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 80 &&
        [balance, sales].allSatisfy { $0.isFinite && (0...1_000_000_000).contains($0) } &&
        (0...1_000_000).contains(orders) && (0...100_000_000).contains(audience) && Self.currencies.contains(currency)
    }
    func money(_ value: Double) -> String { value.formatted(.currency(code: currency)) }
}

enum EventKind: String, Codable, CaseIterable, Identifiable {
    case order, deposit, payout, subscriber, payment, refund
    var id: String { rawValue }
    var title: String {
        switch self { case .order: return "New order"; case .deposit: return "Deposit received"; case .payout: return "Payout received"; case .subscriber: return "New subscriber"; case .payment: return "Payment sent"; case .refund: return "Order refunded" }
    }
    var symbol: String {
        switch self { case .order: return "bag"; case .deposit: return "arrow.down.left"; case .payout: return "banknote"; case .subscriber: return "person.badge.plus"; case .payment: return "arrow.up.right"; case .refund: return "arrow.uturn.backward" }
    }
    var isOutflow: Bool { self == .payment || self == .refund }
}

struct SceneEvent: Codable, Identifiable, Equatable {
    var id = UUID()
    var sceneID: UUID
    var kind: EventKind
    var amount: Double
    var detail: String
    var date = Date()
    var orderNumber: Int?
    var customerName: String?
    var itemCount: Int?
    /// True for an atomic transfer between this scene's checking and savings accounts.
    var savingsTransfer: Bool?
    var title: String { kind.title }
    var isValid: Bool {
        Simulation.validAmount(amount) && detail.count <= 240 && date.timeIntervalSince1970.isFinite &&
        (orderNumber.map { (1...2_000_000).contains($0) } ?? true) &&
        (customerName.map { !$0.isEmpty && $0.count <= 80 } ?? true) &&
        (itemCount.map { (1...1000).contains($0) } ?? true) &&
        (savingsTransfer != true || kind == .payment || kind == .deposit)
    }
    func body(scene: StudioScene) -> String {
        if scene.kind == .commerce && kind == .order {
            let quantity = itemCount ?? 2
            return "[\(scene.name)] You have a new order for \(quantity) \(quantity == 1 ? "item" : "items") totaling \(scene.money(amount))."
        }
        let parts = kind == .subscriber ? [scene.name, detail] : [scene.name, scene.money(kind.isOutflow ? -amount : amount), detail]
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

struct NotificationPreset: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var kind: EventKind
    var amount: Double
    var detail: String
    var delay: Double
    var count: Int
    var isValid: Bool {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !cleanName.isEmpty && name.count <= 60 && detail.count <= 240 &&
        delay.isFinite && (2...86400).contains(delay) && (1...20).contains(count) &&
        Simulation.validAmount(amount)
    }
}
struct QueuedAlert: Identifiable, Equatable {
    let id: String
    let sceneID: UUID?
    let title: String
    let body: String
    let date: Date?
}
struct Archive: Codable {
    static let maximumBytes = 2_000_000
    var scenes: [StudioScene]
    var events: [SceneEvent]
    var activeID: UUID
    var presets: [NotificationPreset]
    var commerceProfiles: [CommerceProfile]
    var bankProfiles: [BankProfile]
    var portfolioProfiles: [PortfolioProfile]
    var walletProfiles: [WalletProfile]
    var predictionProfiles: [PredictionProfile]
    init(scenes: [StudioScene], events: [SceneEvent], activeID: UUID, presets: [NotificationPreset] = [], commerceProfiles: [CommerceProfile] = [], bankProfiles: [BankProfile] = [], portfolioProfiles: [PortfolioProfile] = [], walletProfiles: [WalletProfile] = [], predictionProfiles: [PredictionProfile] = []) {
        self.commerceProfiles = commerceProfiles; self.bankProfiles = bankProfiles
        self.portfolioProfiles = portfolioProfiles; self.walletProfiles = walletProfiles; self.predictionProfiles = predictionProfiles
        self.scenes = scenes; self.events = events; self.activeID = activeID; self.presets = presets
    }
    private enum CodingKeys: String, CodingKey { case scenes, events, activeID, presets, commerceProfiles, bankProfiles, portfolioProfiles, walletProfiles, predictionProfiles }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scenes = try container.decode([StudioScene].self, forKey: .scenes)
        events = try container.decode([SceneEvent].self, forKey: .events)
        activeID = try container.decode(UUID.self, forKey: .activeID)
        presets = try container.decodeIfPresent([NotificationPreset].self, forKey: .presets) ?? []
        commerceProfiles = try container.decodeIfPresent([CommerceProfile].self, forKey: .commerceProfiles) ?? []
        bankProfiles = try container.decodeIfPresent([BankProfile].self, forKey: .bankProfiles) ?? []
        portfolioProfiles = try container.decodeIfPresent([PortfolioProfile].self, forKey: .portfolioProfiles) ?? []
        walletProfiles = try container.decodeIfPresent([WalletProfile].self, forKey: .walletProfiles) ?? []
        predictionProfiles = try container.decodeIfPresent([PredictionProfile].self, forKey: .predictionProfiles) ?? []
    }
    var isValid: Bool {
        let sceneIDs = Set(scenes.map(\.id))
        return (1...100).contains(scenes.count) && scenes.allSatisfy(\.isValid) && sceneIDs.count == scenes.count &&
        sceneIDs.contains(activeID) && events.count <= 1000 && Set(events.map(\.id)).count == events.count &&
        events.allSatisfy { $0.isValid && sceneIDs.contains($0.sceneID) } &&
        presets.count <= 50 && Set(presets.map(\.id)).count == presets.count && presets.allSatisfy(\.isValid) &&
        commerceProfiles.count <= 100 && Set(commerceProfiles.map(\.sceneID)).count == commerceProfiles.count &&
        commerceProfiles.allSatisfy { $0.isValid && sceneIDs.contains($0.sceneID) } &&
        bankProfiles.count <= 100 && Set(bankProfiles.map(\.sceneID)).count == bankProfiles.count &&
        bankProfiles.allSatisfy { $0.isValid && sceneIDs.contains($0.sceneID) } &&
        portfolioProfiles.count <= 100 && Set(portfolioProfiles.map(\.sceneID)).count == portfolioProfiles.count &&
        portfolioProfiles.allSatisfy { profile in profile.isValid && scenes.contains(where: { $0.id == profile.sceneID && $0.kind == .portfolio && MarketValidation.nonnegative(profile.total(cash: $0.balance)) }) } &&
        walletProfiles.count <= 100 && Set(walletProfiles.map(\.sceneID)).count == walletProfiles.count &&
        walletProfiles.allSatisfy { profile in profile.isValid && scenes.contains(where: { $0.id == profile.sceneID && $0.kind == .wallet }) } &&
        predictionProfiles.count <= 100 && Set(predictionProfiles.map(\.sceneID)).count == predictionProfiles.count &&
        predictionProfiles.allSatisfy { profile in profile.isValid && scenes.contains(where: { $0.id == profile.sceneID && $0.kind == .prediction && MarketValidation.nonnegative(profile.total(cash: $0.balance)) }) }
    }
    func encoded(prettyPrinted: Bool = false) throws -> Data {
        guard isValid else { throw ArchiveError.invalidSession }
        let encoder = JSONEncoder()
        if prettyPrinted { encoder.outputFormatting = [.prettyPrinted, .sortedKeys] }
        let data = try encoder.encode(self)
        guard data.count <= Self.maximumBytes else { throw ArchiveError.tooLarge }
        return data
    }
    static func decode(_ data: Data) throws -> Archive {
        guard data.count <= maximumBytes else { throw ArchiveError.tooLarge }
        let archive = try JSONDecoder().decode(Archive.self, from: data)
        guard archive.isValid else { throw ArchiveError.invalidSession }
        return archive
    }
}
enum ArchiveError: LocalizedError {
    case tooLarge, invalidSession
    var errorDescription: String? {
        switch self {
        case .tooLarge: return "Session files must be smaller than 2 MB."
        case .invalidSession: return "The session contains invalid scenes, events, or saved cues."
        }
    }
}

enum Simulation {
    static func applying(_ event: SceneEvent, to scene: StudioScene) -> StudioScene {
        guard scene.isValid, event.isValid, event.sceneID == scene.id else { return scene }
        var result = scene
        switch event.kind {
        case .order:
            guard scene.orders < 1_000_000 else { return scene }
            result.orders += 1; result.sales += event.amount; result.balance += event.amount
        case .deposit:
            result.balance += event.amount
            if scene.kind == .banking { result.sales += event.amount }
        case .payout:
            result.balance += event.amount
            if scene.kind == .creator { result.sales += event.amount }
        case .payment:
            guard scene.balance >= event.amount else { return scene }
            result.balance -= event.amount
        case .refund:
            guard scene.balance >= event.amount, scene.sales >= event.amount else { return scene }
            result.balance -= event.amount; result.sales -= event.amount
        case .subscriber:
            guard scene.audience < 100_000_000 else { return scene }
            result.audience += 1
        }
        return result.isValid ? result : scene
    }
    static func validAmount(_ amount: Double) -> Bool { amount.isFinite && (0.01...1_000_000_000).contains(amount) }
    /// Decimal keyboard input, using the current locale's decimal separator. Grouping and exponent syntax are deliberately rejected.
    static func parseAmount(_ text: String, locale: Locale = .current) -> Double? {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let separator = locale.decimalSeparator ?? "."
        let asciiDigits = input.map { character -> String in
            if character.unicodeScalars.count == 1,
               character.unicodeScalars.first?.properties.generalCategory == .decimalNumber,
               let digit = character.wholeNumberValue { return String(digit) }
            return String(character)
        }.joined()
        let normalized = asciiDigits.replacingOccurrences(of: separator, with: ".")
        guard normalized.range(of: "^[0-9]+(?:\\.[0-9]*)?$", options: .regularExpression) != nil,
              let value = Double(normalized), value.isFinite else { return nil }
        return value
    }
}

struct NotificationCue: Equatable {
    let event: SceneEvent
    let delay: TimeInterval
}
enum NotificationPlan {
    static func make(scene: StudioScene, kind: EventKind, amount: Double, detail: String, delay: TimeInterval, count: Int, pendingCount: Int) -> [NotificationCue]? {
        guard scene.isValid, delay.isFinite, (2...86400).contains(delay), (1...20).contains(count),
              (0...60).contains(pendingCount), pendingCount + count <= 60, detail.count <= 240 else { return nil }
        let value = kind == .subscriber ? 0.01 : amount
        guard Simulation.validAmount(value) else { return nil }
        return (0..<count).map { index in
            NotificationCue(event: SceneEvent(sceneID: scene.id, kind: kind, amount: value,
                detail: detail.trimmingCharacters(in: .whitespacesAndNewlines)), delay: delay + Double(index) * 10)
        }
    }
}
