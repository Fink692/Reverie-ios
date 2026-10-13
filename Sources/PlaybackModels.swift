import Foundation

enum CommerceFulfillment: String, Codable, CaseIterable, Identifiable {
    case unfulfilled, fulfilled, archived
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}
struct CommerceProduct: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var price: Double
    var inventory: Int
    var symbol: String
    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.count <= 80 &&
        price.isFinite && (0...1_000_000_000).contains(price) && (0...1_000_000).contains(inventory) &&
        !symbol.isEmpty && symbol.count <= 80
    }
}
struct CommerceOrder: Codable, Identifiable, Equatable {
    var id: UUID
    var number: Int
    var customer: String
    var itemCount: Int
    var total: Double
    var date: Date
    var fulfillment: CommerceFulfillment
    var isPaid: Bool
    var isValid: Bool {
        (1...2_000_000).contains(number) && !customer.isEmpty && customer.count <= 80 &&
        (1...1000).contains(itemCount) && Simulation.validAmount(total) && date.timeIntervalSince1970.isFinite
    }
}
struct CommerceOrderState: Codable, Identifiable, Equatable {
    var id: UUID
    var fulfillment: CommerceFulfillment
}
struct CommerceProfile: Codable, Identifiable, Equatable {
    var sceneID: UUID
    var id: UUID { sceneID }
    var liveVisitors: Int
    var conversionRate: Double
    var salesChange: Double
    var ordersChange: Double
    var chart: [Double]
    var previousChart: [Double] = [0.12,0.08,0.11,0.1,0.2,0.16,0.2,0.38,0.3,0.15,0.28,0.05]
    var payoutAmount: Double
    var payoutDays: Int
    var products: [CommerceProduct]
    var orderStates: [CommerceOrderState]
    var initialOrders: [CommerceOrder]
    var isValid: Bool {
        (0...1_000_000).contains(liveVisitors) && conversionRate.isFinite && (0...100).contains(conversionRate) &&
        [salesChange, ordersChange].allSatisfy { $0.isFinite && (-100...10000).contains($0) } &&
        (2...60).contains(chart.count) && chart.allSatisfy { $0.isFinite && (0...1).contains($0) } &&
        (2...60).contains(previousChart.count) && previousChart.allSatisfy { $0.isFinite && (0...1).contains($0) } &&
        payoutAmount.isFinite && (0...1_000_000_000).contains(payoutAmount) && (0...365).contains(payoutDays) &&
        products.count <= 100 && products.allSatisfy(\.isValid) && Set(products.map(\.id)).count == products.count &&
        orderStates.count <= 1000 && Set(orderStates.map(\.id)).count == orderStates.count &&
        initialOrders.count <= 100 && initialOrders.allSatisfy(\.isValid) && Set(initialOrders.map(\.id)).count == initialOrders.count
    }
    static func starter(for sceneID: UUID) -> CommerceProfile {
        let now = Date()
        return CommerceProfile(sceneID: sceneID, liveVisitors: 8, conversionRate: 2.9, salesChange: 16.4,
            ordersChange: 12.0, chart: [0.22,0.11,0.18,0.15,0.24,0.31,0.19,0.8,0.31,0.07,1,0.03],
            payoutAmount: 1404.22, payoutDays: 3,
            products: [
                CommerceProduct(id: UUID(uuidString: "AD9A767D-602E-4F05-B146-419308632901")!, title: "Everyday tote", price: 39, inventory: 84, symbol: "bag.fill"),
                CommerceProduct(id: UUID(uuidString: "AD9A767D-602E-4F05-B146-419308632902")!, title: "Essential hoodie", price: 89, inventory: 52, symbol: "tshirt.fill"),
                CommerceProduct(id: UUID(uuidString: "AD9A767D-602E-4F05-B146-419308632903")!, title: "Studio cap", price: 29, inventory: 24, symbol: "sun.max.fill")
            ], orderStates: [], initialOrders: [
                CommerceOrder(id: UUID(uuidString: "F04389D5-9CF9-4DC5-A9B6-C94BD2122001")!, number: 1028, customer: "Jamie Parker", itemCount: 2, total: 149, date: now.addingTimeInterval(-1800), fulfillment: .unfulfilled, isPaid: true),
                CommerceOrder(id: UUID(uuidString: "F04389D5-9CF9-4DC5-A9B6-C94BD2122002")!, number: 1027, customer: "Alex Morgan", itemCount: 1, total: 89, date: now.addingTimeInterval(-7200), fulfillment: .unfulfilled, isPaid: true),
                CommerceOrder(id: UUID(uuidString: "F04389D5-9CF9-4DC5-A9B6-C94BD2122003")!, number: 1026, customer: "Jordan Lee", itemCount: 3, total: 117, date: now.addingTimeInterval(-86400), fulfillment: .fulfilled, isPaid: true)
            ])
    }
}

enum BankTheme: String, Codable, CaseIterable, Identifiable {
    case chase, bankOfAmerica, wellsFargo, citi, capitalOne, hsbc, barclays, lloyds, natWest, monzo, revolut, starling
    var id: String { rawValue }
    var name: String {
        switch self {
        case .chase: return "Chase"
        case .bankOfAmerica: return "Bank of America"
        case .wellsFargo: return "Wells Fargo"
        case .citi: return "Citi"
        case .capitalOne: return "Capital One"
        case .hsbc: return "HSBC"
        case .barclays: return "Barclays"
        case .lloyds: return "Lloyds Bank"
        case .natWest: return "NatWest"
        case .monzo: return "Monzo"
        case .revolut: return "Revolut"
        case .starling: return "Starling Bank"
        }
    }
    var title: String { name }
    var country: String {
        switch self {
        case .chase, .bankOfAmerica, .wellsFargo, .citi, .capitalOne: return "United States"
        case .revolut: return "United Kingdom / international"
        default: return "United Kingdom"
        }
    }
}
struct BankProfile: Codable, Identifiable, Equatable {
    var sceneID: UUID
    var id: UUID { sceneID }
    var theme: BankTheme
    var accountName: String
    var accountSuffix: String
    var cardFrozen: Bool
    var savings: Double
    var isValid: Bool {
        !accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && accountName.count <= 80 &&
        accountSuffix.range(of: "^[0-9]{4}$", options: .regularExpression) != nil &&
        savings.isFinite && (0...1_000_000_000).contains(savings)
    }
    static func starter(for sceneID: UUID) -> BankProfile {
        BankProfile(sceneID: sceneID, theme: .chase, accountName: "Everyday account", accountSuffix: "2048", cardFrozen: false, savings: 12500)
    }
}
