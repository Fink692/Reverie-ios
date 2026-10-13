import Foundation

enum SceneKind: String, Codable, CaseIterable, Identifiable {
    case commerce, banking, creator
    var id: String { rawValue }
    var title: String {
        switch self { case .commerce: return "Store"; case .banking: return "Banking"; case .creator: return "Creator" }
    }
    var symbol: String {
        switch self { case .commerce: return "bag.fill"; case .banking: return "building.columns.fill"; case .creator: return "sparkles" }
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
        StudioScene(name: "The daily edit", kind: .creator, balance: 18240, sales: 1250, orders: 42, audience: 128400)
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
    var title: String { kind.title }
    var isValid: Bool { Simulation.validAmount(amount) && detail.count <= 240 && date.timeIntervalSince1970.isFinite }
    func body(scene: StudioScene) -> String {
        let parts = kind == .subscriber ? [scene.name, detail] : [scene.name, scene.money(kind.isOutflow ? -amount : amount), detail]
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

struct Archive: Codable {
    var scenes: [StudioScene]
    var events: [SceneEvent]
    var activeID: UUID
    var isValid: Bool {
        let sceneIDs = Set(scenes.map(\.id))
        return !scenes.isEmpty && scenes.allSatisfy(\.isValid) && sceneIDs.count == scenes.count &&
        sceneIDs.contains(activeID) && events.count <= 1000 && Set(events.map(\.id)).count == events.count &&
        events.allSatisfy { $0.isValid && sceneIDs.contains($0.sceneID) }
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
