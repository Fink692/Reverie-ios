import Foundation

// All seed prices and charts are editable fictional scene data, not live market quotes.
enum PortfolioTheme: String, Codable, CaseIterable, Identifiable {
    case robinhood, wealthsimple, coinbase
    var id: String { rawValue }
    var name: String {
        switch self { case .robinhood: return "Robinhood"; case .wealthsimple: return "Wealthsimple"; case .coinbase: return "Coinbase" }
    }
    var title: String { name }
}

enum WalletTheme: String, Codable, CaseIterable, Identifiable {
    case metamask, phantom, trustWallet
    var id: String { rawValue }
    var name: String {
        switch self { case .metamask: return "MetaMask"; case .phantom: return "Phantom"; case .trustWallet: return "Trust Wallet" }
    }
    var title: String { name }
}

enum PredictionTheme: String, Codable, CaseIterable, Identifiable {
    case polymarket
    var id: String { rawValue }
    var name: String { "Polymarket" }
    var title: String { name }
}

enum MarketAssetKind: String, Codable, CaseIterable, Identifiable {
    case stock, crypto
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum MarketTradeSide: String, Codable, CaseIterable, Identifiable {
    case buy, sell
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum WalletTransferKind: String, Codable, CaseIterable, Identifiable {
    case send, receive
    var id: String { rawValue }
    var title: String { self == .send ? "Sent" : "Received" }
}

enum PredictionOutcome: String, Codable, CaseIterable, Identifiable {
    case yes, no
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var label: String { title }
}

enum MarketValidation {
    static let maximumValue = 1_000_000_000.0
    static func name(_ value: String, maximum: Int = 80) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.count <= maximum
    }
    static func symbol(_ value: String) -> Bool {
        value.range(of: "^[A-Za-z0-9][A-Za-z0-9.-]{0,14}$", options: .regularExpression) != nil
    }
    static func nonnegative(_ value: Double) -> Bool { value.isFinite && (0...maximumValue).contains(value) }
    static func quantity(_ value: Double, allowZero: Bool = true) -> Bool {
        value.isFinite && value <= maximumValue && (allowZero ? value >= 0 : value > 0)
    }
    static func price(_ value: Double) -> Bool { value.isFinite && value > 0 && value <= maximumValue }
    static func percentage(_ value: Double) -> Bool { value.isFinite && (-100...10_000).contains(value) }
    static func chart(_ values: [Double]) -> Bool {
        (2...120).contains(values.count) && values.allSatisfy { $0.isFinite && (0...1).contains($0) }
    }
    /// Public-address-shaped metadata; it does not validate control of an account or submit a transaction.
    static func address(_ value: String) -> Bool {
        guard value.range(of: "^(?:0[xX])?[A-Fa-f0-9]{64}$", options: .regularExpression) == nil else { return false }
        return value.range(of: "^[A-Za-z0-9]{16,120}$", options: .regularExpression) != nil
    }
    static func date(_ value: Date) -> Bool { value.timeIntervalSince1970.isFinite }
}

struct MarketPosition: Codable, Identifiable, Equatable {
    var id = UUID()
    var symbol: String
    var name: String
    var kind: MarketAssetKind
    var units: Double
    var price: Double
    var averageCost: Double
    var changePercent: Double
    var chart: [Double]
    var value: Double { units * price }
    var costBasis: Double { units * averageCost }
    var unrealizedGain: Double { value - costBasis }
    var transferNetwork: String {
        switch symbol.uppercased() {
        case "BTC": return "Bitcoin"
        case "ETH", "USDC", "USDT", "DAI": return "Ethereum"
        case "SOL": return "Solana"
        default: return symbol.uppercased()
        }
    }
    var isValid: Bool {
        MarketValidation.symbol(symbol) && MarketValidation.name(name) &&
        MarketValidation.quantity(units) && MarketValidation.price(price) && MarketValidation.nonnegative(averageCost) &&
        MarketValidation.percentage(changePercent) && MarketValidation.chart(chart) &&
        MarketValidation.nonnegative(value) && MarketValidation.nonnegative(costBasis)
    }
}

struct MarketTransaction: Codable, Identifiable, Equatable {
    var id = UUID()
    var assetID: UUID
    var symbol: String
    var side: MarketTradeSide
    var units: Double
    var price: Double
    var date = Date()
    var total: Double { units * price }
    var isValid: Bool {
        MarketValidation.symbol(symbol) && MarketValidation.quantity(units, allowZero: false) &&
        MarketValidation.price(price) && MarketValidation.nonnegative(total) && total > 0 && MarketValidation.date(date)
    }
}

struct PortfolioProfile: Codable, Identifiable, Equatable {
    var sceneID: UUID
    var id: UUID { sceneID }
    var theme: PortfolioTheme
    var dailyChange: Double
    var chart: [Double]
    /// Includes zero-unit assets so a scene can retain its watchlist and trade them again.
    var positions: [MarketPosition]
    var transactions: [MarketTransaction]
    var transfers: [WalletTransaction] = []
    private enum CodingKeys: String, CodingKey { case sceneID, theme, dailyChange, chart, positions, transactions, transfers }
    var holdingsValue: Double { positions.reduce(0) { $0 + $1.value } }
    func total(cash: Double) -> Double { cash + holdingsValue }
    func portfolioTotal(cash: Double) -> Double { total(cash: cash) }
    var isValid: Bool {
        let assetIDs = Set(positions.map(\.id))
        guard assetIDs.count == positions.count else { return false }
        let assetsByID = Dictionary(uniqueKeysWithValues: positions.map { ($0.id, $0) })
        let cryptoAssets = Dictionary(uniqueKeysWithValues: positions.filter { $0.kind == .crypto }.map { ($0.id, $0) })
        return MarketValidation.percentage(dailyChange) && MarketValidation.chart(chart) &&
        positions.count <= 100 && positions.allSatisfy(\.isValid) && assetIDs.count == positions.count &&
        Set(positions.map { $0.symbol.uppercased() }).count == positions.count && MarketValidation.nonnegative(holdingsValue) &&
        transactions.count <= 1000 && transactions.allSatisfy { transaction in
            guard transaction.isValid, let asset = assetsByID[transaction.assetID] else { return false }
            return transaction.symbol.caseInsensitiveCompare(asset.symbol) == .orderedSame
        } &&
        Set(transactions.map(\.id)).count == transactions.count && transfers.count <= 1000 &&
        Set(transfers.map(\.id)).count == transfers.count && transfers.allSatisfy { transfer in
            guard transfer.isValid, let asset = cryptoAssets[transfer.assetID] else { return false }
            return transfer.symbol.caseInsensitiveCompare(asset.symbol) == .orderedSame &&
                transfer.network.caseInsensitiveCompare(asset.transferNetwork) == .orderedSame
        }
    }
    static func starter(for sceneID: UUID, theme: PortfolioTheme = .robinhood) -> PortfolioProfile {
        var positions = MarketSamples.positions
        switch theme {
        case .robinhood: positions = positions.filter { $0.kind == .stock }
        case .wealthsimple: positions = MarketSamples.wealthsimpleHoldings
        case .coinbase: positions = positions.filter { $0.kind == .crypto }
        }
        return PortfolioProfile(sceneID: sceneID, theme: theme, dailyChange: 1.84,
            chart: MarketSamples.risingChart, positions: positions, transactions: [])
    }
}

extension PortfolioProfile {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sceneID = try container.decode(UUID.self, forKey: .sceneID)
        theme = try container.decode(PortfolioTheme.self, forKey: .theme)
        dailyChange = try container.decode(Double.self, forKey: .dailyChange)
        chart = try container.decode([Double].self, forKey: .chart)
        positions = try container.decode([MarketPosition].self, forKey: .positions)
        transactions = try container.decode([MarketTransaction].self, forKey: .transactions)
        transfers = try container.decodeIfPresent([WalletTransaction].self, forKey: .transfers) ?? []
    }
}

struct WalletHolding: Codable, Identifiable, Equatable {
    var id = UUID()
    var symbol: String
    var name: String
    var network: String
    var quantity: Double
    var price: Double
    var changePercent: Double
    var chart: [Double]
    var address: String?
    var value: Double { quantity * price }
    var isValid: Bool {
        MarketValidation.symbol(symbol) && MarketValidation.name(name) && MarketValidation.name(network, maximum: 40) &&
        MarketValidation.quantity(quantity) && MarketValidation.price(price) && MarketValidation.percentage(changePercent) &&
        MarketValidation.chart(chart) && MarketValidation.nonnegative(value) &&
        (address.map(MarketValidation.address) ?? true)
    }
}

struct WalletTransaction: Codable, Identifiable, Equatable {
    var id = UUID()
    var assetID: UUID
    var symbol: String
    var network: String
    var address: String
    var kind: WalletTransferKind
    var quantity: Double
    var price: Double
    var date = Date()
    var value: Double { quantity * price }
    var total: Double { value }
    var isValid: Bool {
        MarketValidation.symbol(symbol) && MarketValidation.name(network, maximum: 40) && MarketValidation.address(address) &&
        MarketValidation.quantity(quantity, allowZero: false) && MarketValidation.price(price) &&
        MarketValidation.nonnegative(value) && value > 0 && MarketValidation.date(date)
    }
}

struct WalletProfile: Codable, Identifiable, Equatable {
    var sceneID: UUID
    var id: UUID { sceneID }
    var theme: WalletTheme
    var address: String
    var holdings: [WalletHolding]
    var transactions: [WalletTransaction]
    var fiatValue: Double { holdings.reduce(0) { $0 + $1.value } }
    var publicAddress: String { get { address } set { address = newValue } }
    var isValid: Bool {
        let assetIDs = Set(holdings.map(\.id))
        guard assetIDs.count == holdings.count else { return false }
        let assetsByID = Dictionary(uniqueKeysWithValues: holdings.map { ($0.id, $0) })
        let identities = holdings.map { $0.symbol.uppercased() + "|" + $0.network.lowercased() }
        return MarketValidation.address(address) && holdings.count <= 100 && holdings.allSatisfy(\.isValid) &&
        assetIDs.count == holdings.count && Set(identities).count == holdings.count && MarketValidation.nonnegative(fiatValue) &&
        transactions.count <= 1000 && transactions.allSatisfy { transaction in
            guard transaction.isValid, let asset = assetsByID[transaction.assetID] else { return false }
            return transaction.symbol.caseInsensitiveCompare(asset.symbol) == .orderedSame &&
                transaction.network.caseInsensitiveCompare(asset.network) == .orderedSame
        } &&
        Set(transactions.map(\.id)).count == transactions.count
    }
    static func starter(for sceneID: UUID, theme: WalletTheme = .metamask) -> WalletProfile {
        let ethereum = "0x0000000000000000000000000000000000000000"
        let solana = "11111111111111111111111111111111"
        let bitcoin = "1111111111111111111114oLvT2"
        var holdings = [
            WalletHolding(id: MarketSamples.id("11"), symbol: "ETH", name: "Ethereum", network: "Ethereum", quantity: 4.25, price: 3520.45, changePercent: 2.31, chart: MarketSamples.risingChart, address: ethereum),
            WalletHolding(id: MarketSamples.id("12"), symbol: "USDC", name: "USD Coin", network: "Ethereum", quantity: 1480, price: 1, changePercent: 0, chart: MarketSamples.flatChart, address: ethereum),
            WalletHolding(id: MarketSamples.id("13"), symbol: "SOL", name: "Solana", network: "Solana", quantity: 52.2, price: 142.80, changePercent: 3.24, chart: MarketSamples.risingChart, address: solana),
            WalletHolding(id: MarketSamples.id("14"), symbol: "BTC", name: "Bitcoin", network: "Bitcoin", quantity: 0.08, price: 67420, changePercent: 1.42, chart: MarketSamples.risingChart, address: bitcoin)
        ]
        if theme == .metamask { holdings = holdings.filter { $0.network == "Ethereum" } }
        return WalletProfile(sceneID: sceneID, theme: theme, address: theme == .phantom ? solana : ethereum, holdings: holdings, transactions: [])
    }
}

struct PredictionMarket: Codable, Identifiable, Equatable {
    var id = UUID()
    var question: String
    var category: String
    var yesPrice: Double
    var volume: Double
    var closeDate: Date
    var chart: [Double]
    var noPrice: Double { 1 - yesPrice }
    var isOpen: Bool { closeDate > Date() && yesPrice > 0 && yesPrice < 1 }
    func price(for outcome: PredictionOutcome) -> Double { outcome == .yes ? yesPrice : noPrice }
    var isValid: Bool {
        MarketValidation.name(question, maximum: 180) && MarketValidation.name(category, maximum: 40) &&
        yesPrice.isFinite && (0...1).contains(yesPrice) && MarketValidation.nonnegative(volume) &&
        MarketValidation.date(closeDate) && MarketValidation.chart(chart)
    }
}

struct PredictionPosition: Codable, Identifiable, Equatable {
    var id = UUID()
    var marketID: UUID
    var outcome: PredictionOutcome
    var shares: Double
    var averagePrice: Double
    var costBasis: Double { shares * averagePrice }
    var isValid: Bool {
        MarketValidation.quantity(shares) && averagePrice.isFinite && (0...1).contains(averagePrice) && MarketValidation.nonnegative(costBasis)
    }
}

struct PredictionTrade: Codable, Identifiable, Equatable {
    var id = UUID()
    var marketID: UUID
    var question: String
    var outcome: PredictionOutcome
    var side: MarketTradeSide
    var shares: Double
    var price: Double
    var date = Date()
    var total: Double { shares * price }
    var isValid: Bool {
        MarketValidation.name(question, maximum: 180) && MarketValidation.quantity(shares, allowZero: false) &&
        price.isFinite && price > 0 && price <= 1 && MarketValidation.nonnegative(total) && total > 0 && MarketValidation.date(date)
    }
}

/// Editable scene presentation for a sports market; scores and clocks are saved values.
struct PredictionGame: Codable, Identifiable, Equatable {
    var id = UUID()
    var marketID: UUID
    var league: String
    var homeTeam: String
    var awayTeam: String
    var homeScore: Int
    var awayScore: Int
    var status: String
    var isLive: Bool
    var isValid: Bool {
        MarketValidation.name(league, maximum: 16) && MarketValidation.name(homeTeam, maximum: 40) &&
        MarketValidation.name(awayTeam, maximum: 40) && MarketValidation.name(status, maximum: 32) &&
        (0...999).contains(homeScore) && (0...999).contains(awayScore)
    }
}

struct PredictionProfile: Codable, Identifiable, Equatable {
    var sceneID: UUID
    var id: UUID { sceneID }
    var theme: PredictionTheme
    var markets: [PredictionMarket]
    var positions: [PredictionPosition]
    var transactions: [PredictionTrade]
    var games: [PredictionGame]? = nil
    func market(for id: UUID) -> PredictionMarket? { markets.first { $0.id == id } }
    func value(of position: PredictionPosition) -> Double { position.shares * (market(for: position.marketID)?.price(for: position.outcome) ?? 0) }
    var positionsValue: Double { positions.reduce(0) { $0 + value(of: $1) } }
    func total(cash: Double) -> Double { cash + positionsValue }
    var isValid: Bool {
        let marketIDs = Set(markets.map(\.id))
        let identities = positions.map { $0.marketID.uuidString + "|" + $0.outcome.rawValue }
        return markets.count <= 100 && markets.allSatisfy(\.isValid) && marketIDs.count == markets.count &&
        positions.count <= 200 && positions.allSatisfy { $0.isValid && marketIDs.contains($0.marketID) } &&
        Set(positions.map(\.id)).count == positions.count && Set(identities).count == positions.count &&
        MarketValidation.nonnegative(positionsValue) &&
        transactions.count <= 1000 && transactions.allSatisfy { $0.isValid && marketIDs.contains($0.marketID) } &&
        Set(transactions.map(\.id)).count == transactions.count &&
        (games ?? []).count <= 100 && Set((games ?? []).map(\.id)).count == (games ?? []).count &&
        Set((games ?? []).map(\.marketID)).count == (games ?? []).count &&
        (games ?? []).allSatisfy { $0.isValid && marketIDs.contains($0.marketID) }
    }
    static func starter(for sceneID: UUID) -> PredictionProfile {
        let close = Date().addingTimeInterval(30 * 86_400)
        let markets = [
            PredictionMarket(id: MarketSamples.id("21"), question: "Will Bitcoin reach $100,000 this year?", category: "Crypto", yesPrice: 0.64, volume: 1_240_800, closeDate: close, chart: MarketSamples.risingChart),
            PredictionMarket(id: MarketSamples.id("22"), question: "Will the next rate decision be a cut?", category: "Economy", yesPrice: 0.72, volume: 884_200, closeDate: close, chart: MarketSamples.risingChart),
            PredictionMarket(id: MarketSamples.id("23"), question: "Will Los Angeles defeat Denver?", category: "Sports", yesPrice: 0.48, volume: 326_500, closeDate: close, chart: MarketSamples.fallingChart),
            PredictionMarket(id: MarketSamples.id("24"), question: "Will the new launch sell out in 24 hours?", category: "Culture", yesPrice: 0.81, volume: 198_750, closeDate: close, chart: MarketSamples.risingChart),
            PredictionMarket(id: MarketSamples.id("25"), question: "Will the Dodgers defeat the Rangers?", category: "Sports", yesPrice: 0.71, volume: 487_200, closeDate: close, chart: MarketSamples.risingChart),
            PredictionMarket(id: MarketSamples.id("26"), question: "Will the Rangers defeat the Bruins?", category: "Sports", yesPrice: 0.56, volume: 264_500, closeDate: close, chart: MarketSamples.flatChart)
        ]
        let positions = [PredictionPosition(id: MarketSamples.id("31"), marketID: markets[0].id, outcome: .yes, shares: 250, averagePrice: 0.58)]
        let games = [
            PredictionGame(id: MarketSamples.id("41"), marketID: markets[2].id, league: "Pro", homeTeam: "Los Angeles", awayTeam: "Denver", homeScore: 24, awayScore: 21, status: "Q4 12:43", isLive: true),
            PredictionGame(id: MarketSamples.id("42"), marketID: markets[4].id, league: "MLB", homeTeam: "Dodgers", awayTeam: "Rangers", homeScore: 4, awayScore: 2, status: "Top 7th", isLive: true),
            PredictionGame(id: MarketSamples.id("43"), marketID: markets[5].id, league: "NHL", homeTeam: "Rangers", awayTeam: "Bruins", homeScore: 2, awayScore: 1, status: "P2 14:37", isLive: true)
        ]
        return PredictionProfile(sceneID: sceneID, theme: .polymarket, markets: markets, positions: positions, transactions: [], games: games)
    }
}

private enum MarketSamples {
    static let risingChart = [0.15, 0.22, 0.18, 0.31, 0.29, 0.43, 0.38, 0.52, 0.56, 0.50, 0.66, 0.64, 0.75, 0.84, 0.80, 0.95]
    static let fallingChart = [0.88, 0.76, 0.82, 0.73, 0.68, 0.75, 0.57, 0.54, 0.65, 0.46, 0.42, 0.49, 0.34, 0.38, 0.28, 0.30]
    static let flatChart = [0.5, 0.501, 0.499, 0.5, 0.501, 0.5, 0.499, 0.5]
    static func id(_ suffix: String) -> UUID { UUID(uuidString: "5A110000-0000-4000-8000-0000000000" + suffix)! }
    static let positions = [
        MarketPosition(id: id("01"), symbol: "AAPL", name: "Apple", kind: .stock, units: 12, price: 218.35, averageCost: 192.40, changePercent: 1.36, chart: risingChart),
        MarketPosition(id: id("02"), symbol: "NVDA", name: "NVIDIA", kind: .stock, units: 18, price: 126.80, averageCost: 104.10, changePercent: 2.14, chart: risingChart),
        MarketPosition(id: id("03"), symbol: "TSLA", name: "Tesla", kind: .stock, units: 4, price: 242.20, averageCost: 256.60, changePercent: -1.82, chart: fallingChart),
        MarketPosition(id: id("04"), symbol: "SPY", name: "SPDR S&P 500 ETF", kind: .stock, units: 8, price: 568.40, averageCost: 522.50, changePercent: 0.68, chart: risingChart),
        MarketPosition(id: id("05"), symbol: "BTC", name: "Bitcoin", kind: .crypto, units: 0.28, price: 67420, averageCost: 58240, changePercent: 1.42, chart: risingChart),
        MarketPosition(id: id("06"), symbol: "ETH", name: "Ethereum", kind: .crypto, units: 4.2, price: 3520.45, averageCost: 2980, changePercent: 2.31, chart: risingChart),
        MarketPosition(id: id("07"), symbol: "SOL", name: "Solana", kind: .crypto, units: 52.2, price: 142.80, averageCost: 116.40, changePercent: 3.24, chart: risingChart)
    ]
    /// Fictional starter holdings following the visible public Holdings composition.
    /// Derived prices and cost bases keep row values and local trading consistent.
    /// Existing saved portfolios are preserved; these rows only seed a new profile.
    static let wealthsimpleHoldings: [MarketPosition] = [
        holding("51", symbol: "AC", name: "Air Canada", units: 12.527, value: 231.13, gain: 111.08),
        holding("52", symbol: "ZM", name: "Zoom", units: 0.157, value: 10.65, gain: -24.55),
        holding("53", symbol: "IVV", name: "iShares Core S&P 500 ETF", units: 14.611, value: 7485.43, gain: 4394.87),
        holding("54", symbol: "AXP", name: "American Express", units: 1.845, value: 415.96, gain: -21.89),
        holding("55", symbol: "GME", name: "GameStop", units: 23.796, value: 355.03, gain: -4674.83),
        holding("56", symbol: "JNJ", name: "Johnson & Johnson", units: 19.252, value: 2935.87, gain: 1064.82),
        holding("57", symbol: "AAPL", name: "Apple", units: 4.399, value: 824.51, gain: 376.79)
    ]
    private static func holding(_ suffix: String, symbol: String, name: String,
                                units: Double, value: Double, gain: Double) -> MarketPosition {
        MarketPosition(id: id(suffix), symbol: symbol, name: name, kind: .stock,
            units: units, price: value / units, averageCost: (value - gain) / units,
            changePercent: gain >= 0 ? 1.36 : -1.82,
            chart: gain >= 0 ? risingChart : fallingChart)
    }
}
