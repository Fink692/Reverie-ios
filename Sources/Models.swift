import Foundation

enum SceneKind: String, Codable, CaseIterable, Identifiable {
    case commerce, banking, creator
    var id: String { rawValue }
    var title: String { switch self { case .commerce: return "Store"; case .banking: return "Banking"; case .creator: return "Creator" } }
    var symbol: String { switch self { case .commerce: return "bag.fill"; case .banking: return "building.columns.fill"; case .creator: return "sparkles" } }
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
    static let examples: [StudioScene] = [
        StudioScene(name: "Studio Supply", kind: .commerce, balance: 24850, sales: 3842, orders: 28, audience: 1248),
        StudioScene(name: "Northstar", kind: .banking, balance: 84250.75, sales: 6420, orders: 16, audience: 0),
        StudioScene(name: "The daily edit", kind: .creator, balance: 18240, sales: 1250, orders: 42, audience: 128400)
    ]
    func money(_ value: Double) -> String { value.formatted(.currency(code: currency)) }
}
enum EventKind: String, Codable, CaseIterable, Identifiable {
    case order, deposit, payout, subscriber
    var id: String { rawValue }
    var title: String { switch self { case .order: return "New order"; case .deposit: return "Deposit received"; case .payout: return "Payout received"; case .subscriber: return "New subscriber" } }
    var symbol: String { switch self { case .order: return "bag"; case .deposit: return "arrow.down.left"; case .payout: return "banknote"; case .subscriber: return "person.badge.plus" } }
}
struct SceneEvent: Codable, Identifiable, Equatable {
    var id = UUID()
    var sceneID: UUID
    var kind: EventKind
    var amount: Double
    var detail: String
    var date = Date()
    var title: String { kind.title }
    func body(scene: StudioScene) -> String { "\(scene.name) · \(scene.money(amount)) · \(detail)" }
}
struct Archive: Codable {
    var scenes: [StudioScene]
    var events: [SceneEvent]
    var activeID: UUID
}
enum Simulation {
    static func applying(_ event: SceneEvent, to scene: StudioScene) -> StudioScene {
        var result = scene
        switch event.kind {
        case .order: result.orders += 1; result.sales += event.amount; result.balance += event.amount
        case .deposit, .payout: result.balance += event.amount
        case .subscriber: result.audience += 1
        }
        return result
    }
    static func validAmount(_ amount: Double) -> Bool { amount.isFinite && amount > 0 && amount <= 1_000_000_000 }
}
