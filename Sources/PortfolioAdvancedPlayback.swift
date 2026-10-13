import SwiftUI

/// A local advanced-trade presentation. All orders use the saved scene's market-trade flow.
struct CoinbaseAdvancedTradePage: View {
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    let sceneID: UUID
    @State private var chartMode: AdvancedChartMode = .candle
    @State private var interval: AdvancedChartInterval = .fifteenMinutes
    @State private var showMovingAverage = false
    @State private var showVolume = true
    @State private var watching = false
    @State private var showingInformation = false
    @State private var trade: MarketTradeSide?

    private var profile: PortfolioProfile { store.portfolioProfile(for: sceneID) }
    private var scene: StudioScene? { store.scenes.first { $0.id == sceneID } }
    private var bitcoin: MarketPosition? {
        profile.positions.first { $0.kind == .crypto && $0.symbol.caseInsensitiveCompare("BTC") == .orderedSame }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let scene, let bitcoin {
                    tradingPage(bitcoin, scene: scene)
                } else {
                    VStack(spacing: 20) {
                        ContentUnavailableView("Bitcoin", systemImage: "bitcoinsign.circle", description: Text("Add Bitcoin to this account to view the market."))
                        Button("Add Bitcoin") { _ = store.addPortfolioMarketAsset(sceneID: sceneID, symbol: "BTC") }
                            .font(.system(size: 16, weight: .semibold)).padding(.horizontal, 26).frame(height: 48)
                            .background(AdvancedTradeColors.blue, in: Capsule()).foregroundStyle(.white)
                            .accessibilityIdentifier("coinbase-advanced-add-bitcoin")
                        if let error = store.error { Text(error).font(.footnote).foregroundStyle(AdvancedTradeColors.loss) }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .topLeading) { closeButton.padding(.leading, 12) }
                }
            }
            .background(AdvancedTradeColors.background.ignoresSafeArea())
            .foregroundStyle(.white)
            .toolbar(.hidden, for: .navigationBar)
            .preferredColorScheme(.dark)
            .tint(AdvancedTradeColors.blue)
            .sheet(item: $trade) { side in
                if let bitcoin {
                    PortfolioTradePage(sceneID: sceneID, assetID: bitcoin.id, side: side)
                }
            }
            .sheet(isPresented: $showingInformation) { informationSheet }
        }
        
    }

    private func tradingPage(_ bitcoin: MarketPosition, scene: StudioScene) -> some View {
        let candles = AdvancedCandle.make(from: bitcoin, interval: interval)
        let trades = profile.transactions.filter { $0.assetID == bitcoin.id }
        let tradedUnits = trades.reduce(0) { $0 + $1.units }
        let tradedValue = trades.reduce(0) { $0 + $1.total }
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                pairHeader(bitcoin, scene: scene)
                priceHeader(bitcoin, scene: scene)
                marketStatistics(candles: candles, bitcoin: bitcoin, scene: scene, tradedUnits: tradedUnits, tradedValue: tradedValue)
                chartControls
                chartPanel(candles: candles, bitcoin: bitcoin, scene: scene)

            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 20)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { tradeButtons(bitcoin, scene: scene) }
    }

    private func pairHeader(_ bitcoin: MarketPosition, scene: StudioScene) -> some View {
        HStack(spacing: 8) {
            closeButton
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                ZStack {
                    Circle().stroke(AdvancedTradeColors.blue, lineWidth: 2).frame(width: 25, height: 25)
                        .overlay { Text(currencySymbol(scene.currency)).font(.system(size: 20, weight: .medium)).foregroundStyle(AdvancedTradeColors.blue) }
                        .offset(x: 11)
                    Circle().fill(AdvancedTradeColors.bitcoin).frame(width: 27, height: 27)
                        .overlay { Text("₿").font(.system(size: 25, weight: .medium)).foregroundStyle(.white).rotationEffect(.degrees(12)) }
                        .offset(x: -7)
                }.frame(width: 46, height: 32).accessibilityHidden(true)
                Text("\(bitcoin.symbol)-\(scene.currency)").font(.system(size: 18, weight: .semibold))
            }
            Spacer(minLength: 0)
            Color.clear.frame(width: 40, height: 40).accessibilityHidden(true)
        }
        .padding(.horizontal, -4)
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "arrow.left").font(.system(size: 24, weight: .medium)).frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .accessibilityLabel("Close advanced trade")
        .accessibilityIdentifier("coinbase-advanced-close")
    }

    private func priceHeader(_ bitcoin: MarketPosition, scene: StudioScene) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text(scene.money(bitcoin.price))
                    .font(.system(size: 29, weight: .semibold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .accessibilityIdentifier("coinbase-advanced-price")
                HStack(spacing: 3) {
                    Image(systemName: bitcoin.changePercent >= 0 ? "arrow.up.right" : "arrow.down.right").font(.system(size: 12, weight: .semibold))
                    Text(PortfolioFormatting.percent(abs(bitcoin.changePercent)))
                        .font(.system(size: 14, weight: .semibold)).monospacedDigit()
                }
                .foregroundStyle(bitcoin.changePercent >= 0 ? AdvancedTradeColors.gain : AdvancedTradeColors.loss)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Scene change \(PortfolioFormatting.percent(bitcoin.changePercent))")
            }
            Spacer(minLength: 4)
            Button { showingInformation = true } label: {
                Image(systemName: "info.circle.fill").font(.system(size: 20)).frame(width: 44, height: 44)
                    .background(AdvancedTradeColors.surface, in: Circle())
            }
            .accessibilityLabel("About this market")
            .accessibilityIdentifier("coinbase-advanced-info")
            Button { watching.toggle() } label: {
                Image(systemName: watching ? "star.fill" : "star").font(.system(size: 19, weight: .medium)).frame(width: 44, height: 44)
                    .background(AdvancedTradeColors.surface, in: Circle())
                    .foregroundStyle(watching ? AdvancedTradeColors.blue : .white)
            }
            .accessibilityLabel(watching ? "Remove BTC from watchlist" : "Add BTC to watchlist")
            .accessibilityValue(watching ? "Watching" : "Not watching")
            .accessibilityAddTraits(watching ? .isSelected : [])
            .accessibilityIdentifier("coinbase-advanced-watchlist")
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
    }

    private func marketStatistics(candles: [AdvancedCandle], bitcoin: MarketPosition, scene: StudioScene, tradedUnits: Double, tradedValue: Double) -> some View {
        HStack(alignment: .top, spacing: 12) {
            statisticColumn([
                ("High", scene.money(candles.map(\.high).max() ?? bitcoin.price), .white),
                ("Low", scene.money(candles.map(\.low).min() ?? bitcoin.price), .white)
            ])
            statisticColumn([
                ("Bid", scene.money(bitcoin.price), AdvancedTradeColors.gain),
                ("Ask", scene.money(bitcoin.price), AdvancedTradeColors.loss)
            ])
            statisticColumn([
                ("Vol (\(scene.currency))", compactNumber(tradedValue), .white),
                ("Vol (BTC)", compactNumber(tradedUnits), .white)
            ])
        }
        .accessibilityIdentifier("coinbase-advanced-statistics")
    }

    private func statisticColumn(_ rows: [(String, String, Color)]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(rows.indices, id: \.self) { index in
                HStack(spacing: 5) {
                    Text(rows[index].0).foregroundStyle(AdvancedTradeColors.secondary)
                    Text(rows[index].1).foregroundStyle(rows[index].2).fontWeight(.semibold).monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.65)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .font(.system(size: 11))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chartControls: some View {
        HStack(spacing: 7) {
            Menu {
                ForEach(AdvancedChartMode.allCases) { mode in
                    Button { chartMode = mode } label: {
                        Label(mode.rawValue, systemImage: chartMode == mode ? "checkmark" : mode.symbol)
                    }.accessibilityIdentifier("coinbase-chart-mode-\(mode.rawValue.lowercased())")
                }
            } label: { controlLabel(chartMode.rawValue) }
            .accessibilityLabel("Chart type")
            .accessibilityValue(chartMode.rawValue)
            .accessibilityIdentifier("coinbase-advanced-chart-mode")
            Menu {
                ForEach(AdvancedChartInterval.allCases) { option in
                    Button { interval = option } label: {
                        if interval == option { Label(option.rawValue + " Interval", systemImage: "checkmark") }
                        else { Text(option.rawValue + " Interval") }
                    }.accessibilityIdentifier("coinbase-chart-interval-\(option.rawValue.lowercased())")
                }
            } label: { controlLabel(interval.rawValue + " Interval") }
            .accessibilityLabel("Chart interval")
            .accessibilityValue(interval.rawValue)
            .accessibilityIdentifier("coinbase-advanced-interval")
            Menu {
                Toggle("Moving average (5)", isOn: $showMovingAverage)
                    .accessibilityIdentifier("coinbase-indicator-moving-average")
                Toggle("Volume", isOn: $showVolume)
                    .accessibilityIdentifier("coinbase-indicator-volume")
            } label: { controlLabel("Indicators", active: showMovingAverage || !showVolume) }
            .accessibilityLabel("Chart indicators")
            .accessibilityValue("Moving average \(showMovingAverage ? "on" : "off"), volume \(showVolume ? "on" : "off")")
            .accessibilityIdentifier("coinbase-advanced-indicators")
        }
        .buttonStyle(.plain)
    }

    private func controlLabel(_ title: String, active: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.75)
            Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
        }
        .frame(maxWidth: .infinity, minHeight: 40)
        .padding(.horizontal, 9)
        .background(AdvancedTradeColors.surface, in: Capsule())
        .overlay(Capsule().stroke(active ? AdvancedTradeColors.blue : .clear, lineWidth: 1))
        .foregroundStyle(.white)
    }

    private func chartPanel(candles: [AdvancedCandle], bitcoin: MarketPosition, scene: StudioScene) -> some View {
        let latest = candles.last
        let change = (latest?.close ?? bitcoin.price) - (latest?.open ?? bitcoin.price)
        let percent = (latest?.open ?? 0) > 0 ? change / (latest?.open ?? bitcoin.price) * 100 : 0
        return VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(AdvancedTradeColors.separator).frame(height: 1)
            HStack(spacing: 5) {
                Text(plainPrice(bitcoin.price))
                Text("\(change >= 0 ? "+" : "−")\(plainPrice(abs(change))) (\(percent >= 0 ? "+" : "−")\(PortfolioFormatting.percent(abs(percent))))")
            }
            .font(.system(size: 12, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(change >= 0 ? AdvancedTradeColors.gain : AdvancedTradeColors.loss)
            .lineLimit(1).minimumScaleFactor(0.65)
            .padding(.vertical, 10).padding(.horizontal, 6)
            AdvancedMarketChart(candles: candles, mode: chartMode, currentPrice: bitcoin.price,
                                showMovingAverage: showMovingAverage, showVolume: showVolume)
                .frame(height: 355)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("BTC \(chartMode.rawValue.lowercased()) chart, \(interval.rawValue) interval, illustrating the saved scene chart")
                .accessibilityValue("\(candles.count) candles. Current price \(scene.money(bitcoin.price)). Moving average \(showMovingAverage ? "on" : "off"). Volume \(showVolume ? "on" : "off").")
                .accessibilityIdentifier("coinbase-advanced-chart")
            HStack {
                Text("6h ago")
                Spacer()
                Text("3h ago")
                Spacer()
                Text("Now")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(AdvancedTradeColors.secondary)
            .padding(.top, 9).padding(.trailing, 76).padding(.leading, 4)
        }
        .padding(.top, -9)
    }

    private func tradeButtons(_ bitcoin: MarketPosition, scene: StudioScene) -> some View {
        VStack(spacing: 10) {
            Rectangle().fill(AdvancedTradeColors.separator).frame(height: 1)
            HStack(spacing: 12) {
                advancedTradeButton("Buy", side: .buy, color: AdvancedTradeColors.gain, disabled: scene.balance <= 0)
                advancedTradeButton("Sell", side: .sell, color: AdvancedTradeColors.loss, disabled: bitcoin.units <= 0)
            }.padding(.horizontal, 16)
        }
        .padding(.bottom, 10)
        .background(AdvancedTradeColors.background)
    }

    private func advancedTradeButton(_ title: String, side: MarketTradeSide, color: Color, disabled: Bool) -> some View {
        Button { trade = side } label: {
            Text(title).font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(color, in: Capsule()).foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(disabled).opacity(disabled ? 0.45 : 1)
        .accessibilityIdentifier("coinbase-advanced-\(side.rawValue)")
    }

    private var informationSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("BTC in your scene").font(.system(size: 25, weight: .semibold))
                    Text("The price, available cash, holdings, and orders come from your saved portfolio. Buy and sell use that scene price and update your portfolio and activity.")
                    Text("Candles, high, low, and chart volume illustrate your saved chart across a six-hour window. Changing the interval groups the same chart into larger or smaller candles. The moving average follows the last five displayed closes.")
                    Text("Bid and ask both show the saved execution price. Volume statistics total your saved BTC trades. The star keeps BTC on this view's watchlist while advanced trade is open.")
                }
                .font(.system(size: 15))
                .foregroundStyle(AdvancedTradeColors.secondary)
                .padding(24)
            }
            .background(AdvancedTradeColors.background.ignoresSafeArea())
            .foregroundStyle(.white)
            .navigationTitle("Market information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingInformation = false } } }
            .preferredColorScheme(.dark)
            .tint(AdvancedTradeColors.blue)
        }
        .presentationDetents([.medium, .large])
    }

    private func compactNumber(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).notation(.compactName))
    }
    private func plainPrice(_ value: Double) -> String {
        value.formatted(.number.grouping(.never).precision(.fractionLength(2)))
    }
    private func currencySymbol(_ currency: String) -> String {
        switch currency { case "GBP": return "£"; case "EUR": return "€"; case "JPY": return "¥"; default: return "$" }
    }
}

private enum AdvancedChartMode: String, CaseIterable, Identifiable {
    case candle = "Candle", line = "Line", area = "Area"
    var id: String { rawValue }
    var symbol: String {
        switch self { case .candle: return "chart.bar.xaxis"; case .line: return "chart.line.uptrend.xyaxis"; case .area: return "chart.xyaxis.line" }
    }
}

private enum AdvancedChartInterval: String, CaseIterable, Identifiable {
    case fiveMinutes = "5M", fifteenMinutes = "15M", oneHour = "1H"
    var id: String { rawValue }
    var minutes: Int {
        switch self { case .fiveMinutes: return 5; case .fifteenMinutes: return 15; case .oneHour: return 60 }
    }
}

private struct AdvancedCandle {
    let open: Double
    let close: Double
    let high: Double
    let low: Double
    /// Illustrative activity from the saved chart; it is not exchange volume.
    let volume: Double
    var rising: Bool { close >= open }

    static func make(from position: MarketPosition, interval: AdvancedChartInterval) -> [AdvancedCandle] {
        let source = position.chart.isEmpty ? [0.5, 0.5] : position.chart
        let finalAnchor = source.last ?? 0.5
        let priceScale = position.price * 0.075
        func price(at fraction: Double) -> Double {
            let location = min(1, max(0, fraction)) * Double(source.count - 1)
            let lower = Int(location)
            let upper = min(source.count - 1, lower + 1)
            let progress = location - Double(lower)
            let anchor = source[lower] + (source[upper] - source[lower]) * progress
            return max(position.price * 0.001, position.price + (anchor - finalAnchor) * priceScale)
        }
        // Every interval groups the same 72 base samples, preserving both saved endpoints.
        let baseCount = 72
        let groupSize = interval.minutes / 5
        return stride(from: 0, to: baseCount, by: groupSize).map { start in
            let end = min(baseCount, start + groupSize)
            let samples = (start...end).map { price(at: Double($0) / Double(baseCount)) }
            let open = samples.first ?? position.price
            let close = samples.last ?? position.price
            let wick = position.price * 0.0006
            let high = (samples.max() ?? position.price) + wick
            let low = max(position.price * 0.001, (samples.min() ?? position.price) - wick)
            let movement = zip(samples, samples.dropFirst()).reduce(0.0) { $0 + abs($1.1 - $1.0) }
            return AdvancedCandle(open: open, close: close, high: high, low: low,
                                  volume: movement / position.price + Double(groupSize) * 0.0008)
        }
    }
}

private struct AdvancedMarketChart: View {
    let candles: [AdvancedCandle]
    let mode: AdvancedChartMode
    let currentPrice: Double
    let showMovingAverage: Bool
    let showVolume: Bool

    var body: some View {
        Canvas { context, size in
            guard !candles.isEmpty, size.width > 90, size.height > 40 else { return }
            let axisWidth: CGFloat = 75
            let plotWidth = size.width - axisWidth
            let plotHeight = size.height - 4
            let rawLow = candles.map(\.low).min() ?? currentPrice
            let rawHigh = candles.map(\.high).max() ?? currentPrice
            let padding = max((rawHigh - rawLow) * 0.12, currentPrice * 0.001)
            let lower = max(0, rawLow - padding)
            let upper = rawHigh + padding
            let span = max(upper - lower, currentPrice * 0.001)
            let step = plotWidth / CGFloat(candles.count)
            func y(_ price: Double) -> CGFloat { CGFloat(1 - (price - lower) / span) * plotHeight }
            func x(_ index: Int) -> CGFloat { (CGFloat(index) + 0.5) * step }

            for tick in 0...6 {
                let vertical = CGFloat(tick) / 6 * plotHeight
                var grid = Path()
                grid.move(to: CGPoint(x: 0, y: vertical))
                grid.addLine(to: CGPoint(x: plotWidth, y: vertical))
                context.stroke(grid, with: .color(AdvancedTradeColors.separator), lineWidth: 0.7)
                let value = upper - Double(tick) / 6 * span
                let label = Text(value.formatted(.number.grouping(.never).precision(.fractionLength(2))))
                    .font(.system(size: 10)).foregroundColor(.white)
                context.draw(label, at: CGPoint(x: plotWidth + 9, y: min(plotHeight - 7, max(7, vertical))), anchor: .leading)
            }
            var axis = Path()
            axis.move(to: CGPoint(x: plotWidth, y: 0))
            axis.addLine(to: CGPoint(x: plotWidth, y: plotHeight))
            context.stroke(axis, with: .color(AdvancedTradeColors.separator), lineWidth: 1)

            if showVolume {
                let maximumVolume = max(candles.map(\.volume).max() ?? 1, 0.00001)
                for index in candles.indices {
                    let candle = candles[index]
                    let height = CGFloat(candle.volume / maximumVolume) * plotHeight * 0.23
                    let rect = CGRect(x: x(index) - step * 0.42, y: plotHeight - height, width: step * 0.84, height: height)
                    context.fill(Path(rect), with: .color((candle.rising ? AdvancedTradeColors.gain : AdvancedTradeColors.loss).opacity(0.32)))
                }
            }

            if mode == .candle {
                for index in candles.indices {
                    let candle = candles[index]
                    let color = candle.rising ? AdvancedTradeColors.gain : AdvancedTradeColors.loss
                    var wick = Path()
                    wick.move(to: CGPoint(x: x(index), y: y(candle.high)))
                    wick.addLine(to: CGPoint(x: x(index), y: y(candle.low)))
                    context.stroke(wick, with: .color(color), lineWidth: 1)
                    let rect = CGRect(x: x(index) - step * 0.35, y: min(y(candle.open), y(candle.close)),
                                      width: max(1, step * 0.7), height: max(2, abs(y(candle.open) - y(candle.close))))
                    context.fill(Path(rect), with: .color(color))
                }
            } else {
                var trace = Path()
                for index in candles.indices {
                    let point = CGPoint(x: x(index), y: y(candles[index].close))
                    if index == 0 { trace.move(to: point) } else { trace.addLine(to: point) }
                }
                if mode == .area {
                    var area = trace
                    area.addLine(to: CGPoint(x: x(candles.count - 1), y: plotHeight))
                    area.addLine(to: CGPoint(x: x(0), y: plotHeight))
                    area.closeSubpath()
                    context.fill(area, with: .linearGradient(Gradient(colors: [AdvancedTradeColors.gain.opacity(0.25), .clear]),
                                                            startPoint: .zero, endPoint: CGPoint(x: 0, y: plotHeight)))
                }
                context.stroke(trace, with: .color(AdvancedTradeColors.gain), style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))
            }

            if showMovingAverage {
                var average = Path()
                for index in candles.indices {
                    let first = max(0, index - 4)
                    let values = candles[first...index].map(\.close)
                    let value = values.reduce(0, +) / Double(values.count)
                    let point = CGPoint(x: x(index), y: y(value))
                    if index == 0 { average.move(to: point) } else { average.addLine(to: point) }
                }
                context.stroke(average, with: .color(AdvancedTradeColors.average), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            }

            let latestColor = (candles.last?.rising ?? true) ? AdvancedTradeColors.gain : AdvancedTradeColors.loss
            let priceY = y(currentPrice)
            var currentLine = Path()
            currentLine.move(to: CGPoint(x: 0, y: priceY))
            currentLine.addLine(to: CGPoint(x: plotWidth, y: priceY))
            context.stroke(currentLine, with: .color(latestColor), style: StrokeStyle(lineWidth: 1, dash: [1.5, 2.5]))
            let labelY = min(plotHeight - 14, max(14, priceY))
            let priceTag = CGRect(x: plotWidth, y: labelY - 14, width: axisWidth - 2, height: 28)
            context.fill(Path(roundedRect: priceTag, cornerSize: CGSize(width: 2, height: 2)), with: .color(latestColor))
            context.draw(Text(currentPrice.formatted(.number.grouping(.never).precision(.fractionLength(2))))
                .font(.system(size: 10, weight: .medium)).foregroundColor(.white),
                         at: CGPoint(x: plotWidth + axisWidth / 2 - 1, y: labelY), anchor: .center)
        }
    }
}

private enum AdvancedTradeColors {
    static let background = Color(red: 0.035, green: 0.039, blue: 0.047)
    static let surface = Color(red: 0.18, green: 0.19, blue: 0.22)
    static let separator = Color(red: 0.15, green: 0.16, blue: 0.18)
    static let secondary = Color(red: 0.55, green: 0.57, blue: 0.61)
    static let gain = Color(red: 0.31, green: 0.67, blue: 0.50)
    static let loss = Color(red: 0.88, green: 0.39, blue: 0.42)
    static let blue = Color(red: 0.31, green: 0.43, blue: 0.94)
    static let bitcoin = Color(red: 0.94, green: 0.62, blue: 0.22)
    static let average = Color(red: 0.92, green: 0.75, blue: 0.30)
}
