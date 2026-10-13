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
/// Saved item descriptions and prices remain stable after catalog edits or deletion.
struct CommerceOrderLineItem: Codable, Equatable {
    var productID: UUID? = nil
    var title: String
    var variant: String? = nil
    var unitPrice: Double
    var quantity: Int
    var symbol: String
    var total: Double { unitPrice * Double(quantity) }
    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.count <= 80 &&
        (variant.map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 80 } ?? true) &&
        unitPrice.isFinite && (0...1_000_000_000).contains(unitPrice) &&
        (1...1000).contains(quantity) && total.isFinite && total <= 1_000_000_000 &&
        !symbol.isEmpty && symbol.count <= 80
    }
    static func valid(_ items: [CommerceOrderLineItem], itemCount: Int, total: Double) -> Bool {
        (1...100).contains(items.count) && items.allSatisfy(\.isValid) &&
        items.reduce(0) { $0 + $1.quantity } == itemCount &&
        abs(items.reduce(0) { $0 + $1.total } - total) <= max(0.000001, abs(total) * 0.000000001)
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
    var lineItems: [CommerceOrderLineItem]? = nil
    var isValid: Bool {
        (1...2_000_000).contains(number) && !customer.isEmpty && customer.count <= 80 &&
        (1...1000).contains(itemCount) && Simulation.validAmount(total) && date.timeIntervalSince1970.isFinite &&
        (lineItems.map { CommerceOrderLineItem.valid($0, itemCount: itemCount, total: total) } ?? true)
    }
}
struct CommerceOrderState: Codable, Identifiable, Equatable {
    var id: UUID
    var fulfillment: CommerceFulfillment
    var isPaid: Bool?
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
enum BankProductKind: String, Codable, CaseIterable { case creditCard, investment }
struct BankProduct: Codable, Identifiable, Equatable {
    var id = UUID()
    var kind: BankProductKind
    var name: String
    var suffix: String
    var balance: Double
    var balanceLabel = "Current balance"
    var minimumPayment: Double? = nil
    var paymentDue: String? = nil
    var rewards: Double? = nil
    var rewardsUnit: String? = nil
    var cardFrozen = false
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 80 &&
        suffix.range(of: "^[0-9]{4}$", options: .regularExpression) != nil &&
        balance.isFinite && (0...1_000_000_000).contains(balance) &&
        !balanceLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && balanceLabel.count <= 40 &&
        [minimumPayment, rewards].allSatisfy { $0.map { $0.isFinite && (0...1_000_000_000).contains($0) } ?? true } &&
        (paymentDue.map { !$0.isEmpty && $0.count <= 40 } ?? true) &&
        (rewardsUnit.map { !$0.isEmpty && $0.count <= 20 } ?? true)
    }
    static func starters(for theme: BankTheme) -> [BankProduct] {
        func id(_ suffix: String) -> UUID { UUID(uuidString: "BA110000-0000-4000-8000-0000000000" + suffix)! }
        switch theme {
        case .citi:
            return [BankProduct(id: id("01"), kind: .creditCard, name: "Citi® Custom Cash Mastercard®", suffix: "4321",
                    balance: 7634.98, minimumPayment: 25, rewards: 21750, rewardsUnit: "points"),
                BankProduct(id: id("02"), kind: .creditCard, name: "Citi Diamond Preferred", suffix: "6713", balance: 205.24)]
        case .capitalOne:
            return [BankProduct(id: id("03"), kind: .creditCard, name: "QUICKSILVER", suffix: "5688",
                    balance: 524.63, balanceLabel: "Available balance"),
                BankProduct(id: id("04"), kind: .creditCard, name: "SAVOR", suffix: "7108",
                    balance: 368.89, balanceLabel: "Available balance")]
        case .bankOfAmerica:
            return [BankProduct(id: id("05"), kind: .creditCard, name: "Custom Cash Rewards", suffix: "3204", balance: 2543.21),
                BankProduct(id: id("06"), kind: .investment, name: "Jane's Investment Account", suffix: "4567", balance: 123456.78)]
        default: return []
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
    var holderName: String?
    var products: [BankProduct]? = nil
    var referenceProducts: [BankProduct] { products ?? BankProduct.starters(for: theme) }
    var isValid: Bool {
        !accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && accountName.count <= 80 &&
        accountSuffix.range(of: "^[0-9]{4}$", options: .regularExpression) != nil &&
        savings.isFinite && (0...1_000_000_000).contains(savings) &&
        (holderName.map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 80 } ?? true) &&
        (products.map { $0.count <= 20 && $0.allSatisfy(\.isValid) && Set($0.map(\.id)).count == $0.count } ?? true)
    }
    static func starter(for sceneID: UUID) -> BankProfile {
        BankProfile(sceneID: sceneID, theme: .chase, accountName: "Everyday account", accountSuffix: "2048", cardFrozen: false, savings: 12500, holderName: "Jamie")
    }
}
