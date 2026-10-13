import Foundation

/// Notification wording for local roleplay cues. A style's EventKind is a compatibility
/// mapping; canEmit controls whether the generic event action may also change totals.
enum NotificationStyle: String, Codable, CaseIterable, Identifiable {
    case shopifyOrder, shopifyRefund, shopifyPayout, shopifyFulfilled, shopifyLowStock, shopifyAbandonedCheckout, shopifyOrderPaid
    case bankDeposit, bankTransferReceived, bankTransferSent, bankCardPayment, bankDirectDebit, bankLowBalance, bankSalaryReceived, bankCardRefund, bankScheduledPayment
    case stockBuyFilled, stockSellFilled, stockDividend, stockPriceUp, stockPriceDown
    case cryptoReceived, cryptoSent, cryptoSwap, cryptoPriceAlert
    case predictionBuyFilled, predictionSellFilled, predictionPayout, predictionResolved
    case creatorSubscriber, creatorPayout, creatorMilestone
    case custom

    var id: String { rawValue }
    var name: String {
        switch self {
        case .shopifyOrder: return "Shopify · New order"
        case .shopifyRefund: return "Shopify · Order refunded"
        case .shopifyPayout: return "Shopify · Payout sent"
        case .shopifyFulfilled: return "Shopify · Order fulfilled"
        case .shopifyLowStock: return "Shopify · Low inventory"
        case .shopifyAbandonedCheckout: return "Shopify · Abandoned checkout"
        case .shopifyOrderPaid: return "Shopify · Payment received"
        case .bankDeposit: return "Bank · Deposit received"
        case .bankTransferReceived: return "Bank · Transfer received"
        case .bankTransferSent: return "Bank · Transfer sent"
        case .bankCardPayment: return "Bank · Card purchase"
        case .bankDirectDebit: return "Bank · Direct Debit"
        case .bankLowBalance: return "Bank · Low balance"
        case .bankSalaryReceived: return "Bank · Salary received"
        case .bankCardRefund: return "Bank · Card refund"
        case .bankScheduledPayment: return "Bank · Upcoming payment"
        case .stockBuyFilled: return "Investing · Buy order filled"
        case .stockSellFilled: return "Investing · Sell order filled"
        case .stockDividend: return "Investing · Dividend paid"
        case .stockPriceUp: return "Investing · Price increase"
        case .stockPriceDown: return "Investing · Price decrease"
        case .cryptoReceived: return "Crypto · Assets received"
        case .cryptoSent: return "Crypto · Assets sent"
        case .cryptoSwap: return "Crypto · Swap complete"
        case .cryptoPriceAlert: return "Crypto · Price alert"
        case .predictionBuyFilled: return "Prediction · Buy filled"
        case .predictionSellFilled: return "Prediction · Sell filled"
        case .predictionPayout: return "Prediction · Winnings paid"
        case .predictionResolved: return "Prediction · Market resolved"
        case .creatorSubscriber: return "Creator · New subscriber"
        case .creatorPayout: return "Creator · Earnings paid"
        case .creatorMilestone: return "Creator · Audience milestone"
        case .custom: return "Custom notification"
        }
    }
    var applicableKinds: [SceneKind] {
        switch self {
        case .shopifyOrder, .shopifyRefund, .shopifyPayout, .shopifyFulfilled, .shopifyLowStock, .shopifyAbandonedCheckout, .shopifyOrderPaid: return [.commerce]
        case .bankDeposit, .bankTransferReceived, .bankTransferSent, .bankCardPayment, .bankDirectDebit, .bankLowBalance, .bankSalaryReceived, .bankCardRefund, .bankScheduledPayment: return [.banking]
        case .stockBuyFilled, .stockSellFilled, .stockDividend, .stockPriceUp, .stockPriceDown: return [.portfolio]
        case .cryptoReceived, .cryptoSent, .cryptoSwap, .cryptoPriceAlert: return [.wallet, .portfolio]
        case .predictionBuyFilled, .predictionSellFilled, .predictionPayout, .predictionResolved: return [.prediction]
        case .creatorSubscriber, .creatorPayout, .creatorMilestone: return [.creator]
        case .custom: return SceneKind.allCases
        }
    }
    func isAvailable(for kind: SceneKind) -> Bool { applicableKinds.contains(kind) }
    var isCustom: Bool { self == .custom }
    var eventKind: EventKind {
        switch self {
        case .shopifyOrder, .shopifyFulfilled, .shopifyLowStock, .shopifyAbandonedCheckout, .shopifyOrderPaid: return .order
        case .shopifyRefund: return .refund
        case .shopifyPayout, .predictionPayout, .creatorPayout: return .payout
        case .bankTransferSent, .bankCardPayment, .bankDirectDebit, .bankScheduledPayment, .stockBuyFilled, .cryptoSent, .cryptoSwap, .predictionBuyFilled: return .payment
        case .creatorSubscriber, .creatorMilestone: return .subscriber
        default: return .deposit
        }
    }
    var canEmit: Bool {
        switch self {
        case .shopifyOrder, .shopifyRefund, .shopifyPayout,
             .bankDeposit, .bankTransferReceived, .bankTransferSent, .bankCardPayment, .bankDirectDebit, .bankSalaryReceived, .bankCardRefund,
             .stockDividend, .creatorSubscriber, .creatorPayout: return true
        default: return false
        }
    }
    var supportsAccounting: Bool { canEmit }
    var amountLabel: String {
        switch self {
        case .shopifyLowStock: return "Items remaining"
        case .bankLowBalance: return "Balance"
        case .stockPriceUp, .stockPriceDown, .cryptoPriceAlert: return "Price"
        case .cryptoReceived, .cryptoSent, .cryptoSwap: return "Fiat value"
        default: return "Amount"
        }
    }
    var usesAmount: Bool {
        switch self {
        case .shopifyFulfilled, .predictionResolved, .creatorSubscriber, .creatorMilestone: return false
        default: return true
        }
    }
    func title(orderNumber: Int? = nil, customTitle: String? = nil) -> String {
        if let override = customTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !override.isEmpty { return override }
        switch self {
        case .shopifyOrder: return "New order"
        case .shopifyRefund: return "Order refunded"
        case .shopifyPayout: return "Payout sent"
        case .shopifyFulfilled: return "Order fulfilled"
        case .shopifyLowStock: return "Low inventory"
        case .shopifyAbandonedCheckout: return "Abandoned checkout"
        case .shopifyOrderPaid: return "Payment received"
        case .bankDeposit: return "Deposit received"
        case .bankTransferReceived: return "Transfer received"
        case .bankTransferSent: return "Transfer sent"
        case .bankCardPayment: return "Card payment"
        case .bankDirectDebit: return "Direct Debit paid"
        case .bankLowBalance: return "Low balance"
        case .bankSalaryReceived: return "Salary received"
        case .bankCardRefund: return "Refund received"
        case .bankScheduledPayment: return "Upcoming payment"
        case .stockBuyFilled: return "Buy order filled"
        case .stockSellFilled: return "Sell order filled"
        case .stockDividend: return "Dividend paid"
        case .stockPriceUp, .stockPriceDown, .cryptoPriceAlert: return "Price alert"
        case .cryptoReceived: return "Crypto received"
        case .cryptoSent: return "Crypto sent"
        case .cryptoSwap: return "Swap complete"
        case .predictionBuyFilled, .predictionSellFilled: return "Order filled"
        case .predictionPayout: return "Winnings paid"
        case .predictionResolved: return "Market resolved"
        case .creatorSubscriber: return "New subscriber"
        case .creatorPayout: return "Earnings paid"
        case .creatorMilestone: return "Milestone reached"
        case .custom: return "Notification"
        }
    }
    func body(scene: StudioScene, amount: Double, detail: String, customerName: String? = nil, itemCount: Int? = nil, orderNumber: Int? = nil) -> String {
        let money = scene.money(amount)
        let detail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let customer = customerName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let quantity = itemCount ?? 1
        let items = "\(quantity) \(quantity == 1 ? "item" : "items")"
        let order = orderNumber.map { "Order #\($0)" } ?? "Your order"
        let subject = detail.isEmpty ? scene.name : detail
        switch self {
        case .shopifyOrder:
            let original = "[\(scene.name)] You have a new order for \(items) totaling \(money)."
            return customer.flatMap { $0.isEmpty ? nil : $0 }.map { original + " From \($0)." } ?? original
        case .shopifyRefund: return "[\(scene.name)] \(order) was refunded for \(money)." + (detail.isEmpty ? "" : " \(detail)")
        case .shopifyPayout: return "[\(scene.name)] A payout of \(money) has been sent to your bank account."
        case .shopifyFulfilled: return "[\(scene.name)] \(order) has been fulfilled." + (detail.isEmpty ? "" : " \(detail)")
        case .shopifyLowStock:
            let remaining = amount.isFinite ? max(0, amount).formatted(.number.precision(.fractionLength(0))) : "0"
            return "[\(scene.name)] \(subject) has \(remaining) left in stock."
        case .shopifyAbandonedCheckout: return "[\(scene.name)] A checkout for \(money) was abandoned." + (customer.flatMap { $0.isEmpty ? nil : $0 }.map { " Customer: \($0)." } ?? "")
        case .shopifyOrderPaid: return "[\(scene.name)] Payment of \(money) was received for \(order.lowercased())."
        case .bankDeposit: return "A deposit of \(money) is now available in \(scene.name)." + (detail.isEmpty ? "" : " \(detail)")
        case .bankTransferReceived: return "You received \(money) from \(subject)."
        case .bankTransferSent: return "Your transfer of \(money) to \(subject) was sent."
        case .bankCardPayment: return "You spent \(money) at \(subject)."
        case .bankDirectDebit: return "A Direct Debit of \(money) was paid to \(subject)."
        case .bankLowBalance: return "Your available balance is \(money). Check \(scene.name) for details."
        case .bankSalaryReceived: return "Your salary payment of \(money) from \(subject) has arrived."
        case .bankCardRefund: return "A refund of \(money) from \(subject) has been credited to your account."
        case .bankScheduledPayment: return "A payment of \(money) to \(subject) is coming up."
        case .stockBuyFilled: return "Your buy order for \(subject) has filled. Total cost: \(money)."
        case .stockSellFilled: return "Your sell order for \(subject) has filled. Proceeds: \(money)."
        case .stockDividend: return "A dividend of \(money) from \(subject) has been added to your cash balance."
        case .stockPriceUp: return "\(subject) is moving up. Current price: \(money)."
        case .stockPriceDown: return "\(subject) is moving down. Current price: \(money)."
        case .cryptoReceived: return "You received \(subject). Value: \(money)."
        case .cryptoSent: return "\(subject) was sent successfully. Value: \(money)."
        case .cryptoSwap: return "Your swap is complete: \(subject). Value: \(money)."
        case .cryptoPriceAlert: return "\(subject) reached \(money)."
        case .predictionBuyFilled: return "Your buy order for \(subject) has filled. Total cost: \(money)."
        case .predictionSellFilled: return "Your sell order for \(subject) has filled. You received \(money)."
        case .predictionPayout: return "Winnings of \(money) have been credited to your balance." + (detail.isEmpty ? "" : " \(detail)")
        case .predictionResolved: return "\(subject) has resolved." + (customer.flatMap { $0.isEmpty ? nil : $0 }.map { " Outcome: \($0)." } ?? "")
        case .creatorSubscriber: return "\(customer.flatMap { $0.isEmpty ? nil : $0 } ?? subject) subscribed to \(scene.name)."
        case .creatorPayout: return "Your earnings payout of \(money) is on its way." + (detail.isEmpty ? "" : " \(detail)")
        case .creatorMilestone: return "\(scene.name) reached \(detail.isEmpty ? "a new audience milestone" : detail)."
        case .custom:
            let template = detail.isEmpty ? "{scene} · {amount}" : detail
            return Self.render(template, values: ["scene": scene.name, "amount": money,
                "customer": customer ?? "", "items": String(quantity), "order": orderNumber.map(String.init) ?? ""])
        }
    }
    private static func render(_ template: String, values: [String: String]) -> String {
        guard let expression = try? NSRegularExpression(pattern: "\\{(scene|amount|customer|items|order)\\}") else { return template }
        let matches = expression.matches(in: template, range: NSRange(location: 0, length: template.utf16.count))
        let result = NSMutableString(string: template)
        let original = template as NSString
        for match in matches.reversed() {
            let token = original.substring(with: match.range(at: 1))
            result.replaceCharacters(in: match.range, with: values[token] ?? "")
        }
        return result as String
    }
}

struct NotificationTemplate: Identifiable, Equatable {
    var id: String
    var name: String
    var style: NotificationStyle
    var amount: Double
    var detail: String
    var delay: Double
    var count: Int
    var interval: Double
    var customerName: String?
    var itemCount: Int?
    var orderNumber: Int?
    var customTitle: String?
    var kind: EventKind { style.eventKind }
    static func templates(for kind: SceneKind) -> [NotificationTemplate] { builtins.filter { $0.style.isAvailable(for: kind) } }
    static let builtins: [NotificationTemplate] = [
        cue(.shopifyOrder, name: "New Shopify order", amount: 149.00, detail: "Online Store", customer: "Jamie Parker", items: 2),
        cue(.shopifyOrder, id: "shopify-order-burst", name: "Shopify order burst", amount: 89.00, detail: "Online Store", count: 8, interval: 8, customer: "Alex Morgan", items: 1),
        cue(.shopifyOrder, id: "shopify-high-value-order", name: "High value Shopify order", amount: 1249.00, detail: "Online Store", customer: "Taylor Reed", items: 6),
        cue(.shopifyRefund, name: "Shopify refund", amount: 89.00, detail: "Refund complete.", order: 1027),
        cue(.shopifyPayout, name: "Shopify payout", amount: 1404.22, detail: ""),
        cue(.shopifyFulfilled, name: "Order shipped", amount: 0.01, detail: "Your shipment is on its way.", order: 1028),
        cue(.shopifyLowStock, name: "Low stock alert", amount: 8, detail: "Everyday tote"),
        cue(.shopifyAbandonedCheckout, name: "Abandoned checkout", amount: 178.00, detail: "Online Store", customer: "Morgan Lee"),
        cue(.shopifyOrderPaid, name: "Order payment received", amount: 149.00, detail: "", order: 1028),
        cue(.bankDeposit, name: "Bank deposit", amount: 1500.00, detail: "Deposit received."),
        cue(.bankTransferReceived, name: "Incoming bank transfer", amount: 2500.00, detail: "Jamie Parker"),
        cue(.bankTransferSent, name: "Outgoing bank transfer", amount: 125.00, detail: "Alex Morgan"),
        cue(.bankCardPayment, name: "Card purchase", amount: 28.50, detail: "Coffee House"),
        cue(.bankDirectDebit, name: "Monthly Direct Debit", amount: 65.00, detail: "Energy account"),
        cue(.bankLowBalance, name: "Low balance warning", amount: 75.00, detail: ""),
        cue(.bankSalaryReceived, name: "Salary payday", amount: 6420.00, detail: "Studio Supply"),
        cue(.bankCardRefund, name: "Card refund received", amount: 49.99, detail: "Online store"),
        cue(.bankScheduledPayment, name: "Upcoming bill", amount: 120.00, detail: "Internet provider"),
        cue(.stockBuyFilled, name: "Stock buy filled", amount: 436.70, detail: "2 shares of AAPL"),
        cue(.stockSellFilled, name: "Stock sale filled", amount: 634.00, detail: "5 shares of NVDA"),
        cue(.stockDividend, name: "Dividend received", amount: 24.80, detail: "SPY"),
        cue(.stockPriceUp, name: "Stock price rises", amount: 221.50, detail: "AAPL"),
        cue(.stockPriceDown, name: "Stock price falls", amount: 238.40, detail: "TSLA"),
        cue(.cryptoReceived, name: "Crypto received", amount: 352.05, detail: "0.1 ETH"),
        cue(.cryptoSent, name: "Crypto sent", amount: 142.80, detail: "1 SOL"),
        cue(.cryptoSwap, name: "Crypto swap completed", amount: 352.05, detail: "0.1 ETH → 352.05 USDC"),
        cue(.cryptoPriceAlert, name: "Bitcoin price alert", amount: 70000.00, detail: "BTC"),
        cue(.predictionBuyFilled, name: "Prediction buy filled", amount: 64.00, detail: "100 Yes shares"),
        cue(.predictionSellFilled, name: "Prediction sale filled", amount: 72.00, detail: "100 Yes shares"),
        cue(.predictionPayout, name: "Prediction winnings", amount: 250.00, detail: "Your market has settled."),
        cue(.predictionResolved, name: "Prediction result", amount: 0.01, detail: "Your selected market", customer: "Yes"),
        cue(.creatorSubscriber, name: "New creator subscriber", amount: 0.01, detail: "Jamie Parker", customer: "Jamie Parker"),
        cue(.creatorPayout, name: "Creator payout", amount: 1250.00, detail: "Monthly earnings."),
        cue(.creatorMilestone, name: "Audience milestone", amount: 0.01, detail: "100,000 followers"),
        cue(.custom, name: "Custom alert", amount: 99.00, detail: "{scene} · {amount}", customTitle: "Your notification")
    ]
    private static func cue(_ style: NotificationStyle, id: String? = nil, name: String, amount: Double, detail: String,
                            count: Int = 1, interval: Double = 10, customer: String? = nil, items: Int? = nil,
                            order: Int? = nil, customTitle: String? = nil) -> NotificationTemplate {
        NotificationTemplate(id: id ?? style.rawValue, name: name, style: style, amount: amount, detail: detail,
            delay: 5, count: count, interval: interval, customerName: customer, itemCount: items,
            orderNumber: order, customTitle: customTitle)
    }
}
