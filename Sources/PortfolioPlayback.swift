import SwiftUI
import Charts
import PhotosUI
import CoreImage
import UIKit

/// Local portfolio scenes. Prices and trades belong to the saved scene, not an exchange.
struct PortfolioPlayback: View {
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    let sceneID: UUID
    @State private var tab: PortfolioTab = .home
    @State private var modal: PortfolioModal?
    @State private var search = ""
    @State private var range: PortfolioRange = .day
    @State private var assetFilter: MarketAssetKind?
    @State private var holdingsFilter: String?
    @State private var discoveryCategory = "Now"
    @State private var cryptoAccount = false
    @State private var choosingAccount = false

    private var scene: StudioScene? { store.scenes.first { $0.id == sceneID } }
    private var profile: PortfolioProfile { store.portfolioProfile(for: sceneID) }
    private var theme: PortfolioTheme { profile.theme }
    private var palette: PortfolioPalette { PortfolioPalette(theme) }

    var body: some View {
        NavigationStack {
            Group {
                if let scene {
                    VStack(spacing: 0) {
                        header
                        switch tab {
                        case .home: home(scene)
                        case .assets: assetsPage(scene)
                        case .activity: PortfolioActivityPage(sceneID: sceneID, embedded: true)
                        case .profile:
                            if theme == .wealthsimple { wealthMovePage }
                            else { profilePage(scene) }
                        }
                        bottomBar
                    }
                    .background(palette.background)
                } else {
                    ContentUnavailableView("Portfolio unavailable", systemImage: "chart.line.uptrend.xyaxis", description: Text("This scene has been removed."))
                }
            }
            .foregroundStyle(palette.ink)
            .background(palette.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .tint(palette.accent)
            .preferredColorScheme(palette.isDark ? .dark : .light)
            .confirmationDialog("Account", isPresented: $choosingAccount, titleVisibility: .hidden) {
                Button("Investing") { cryptoAccount = false }.accessibilityIdentifier("portfolio-account-investing")
                Button("Crypto") { cryptoAccount = true }.accessibilityIdentifier("portfolio-account-crypto")
            }
            .sheet(item: $modal) { destination in
                switch destination {
                case .menu: menuSheet
                case .themes: themesSheet
                case .editor: PortfolioEditor(sceneID: sceneID)
                case .addCash: PortfolioCashMovementPage(sceneID: sceneID, incoming: true)
                case .sendCash: PortfolioCashMovementPage(sceneID: sceneID, incoming: false)
                case .sendCrypto: PortfolioTransferPage(sceneID: sceneID, kind: .send)
                case .receiveCrypto: PortfolioTransferPage(sceneID: sceneID, kind: .receive)
                case .scan: PortfolioScanPage(sceneID: sceneID)
                case .coinbaseCard: coinbaseUnavailableFeature(.card)
                case .coinbaseRewards: coinbaseUnavailableFeature(.rewards)
                case .coinbaseWallet: coinbaseUnavailableFeature(.wallet)
                case .coinbaseAdvanced: coinbaseUnavailableFeature(.advanced)
                }
            }
        }
        .accessibilityIdentifier("portfolio-playback")
    }

    @ViewBuilder private var header: some View {
        if theme == .wealthsimple {
            Button { modal = .menu } label: {
                Text(tab == .home ? "Holdings" : tab == .assets ? "Discover" : tab == .activity ? "Activity" : "Move")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Portfolio menu")
            .accessibilityIdentifier("portfolio-menu")
        } else {
        HStack {
            Button { modal = .menu } label: {
                Group {
                    if theme == .coinbase {
                        PortfolioDotGrid().frame(width: 20, height: 20)
                    } else { Image(systemName: theme == .wealthsimple ? "line.3.horizontal" : "person.crop.circle").font(.system(size: 23)) }
                }.frame(width: 44, height: 44)
            }
            .accessibilityLabel("Portfolio menu")
            .accessibilityIdentifier("portfolio-menu")
            if theme == .coinbase {
                Button { tab = .assets } label: { HStack(spacing: 8) { Image(systemName: "magnifyingglass").font(.system(size: 14)); Text("Search for an asset").font(.system(size: 13)); Spacer() }.padding(.horizontal, 12).frame(minHeight: 38).background(palette.surface, in: Capsule()).foregroundStyle(palette.secondary) }.buttonStyle(.plain)
            } else {
                Spacer()
                Button { choosingAccount = true } label: {
                    HStack(spacing: 5) {
                        Text(cryptoAccount ? "Crypto" : "Investing")
                        Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
                    }.font(.system(size: 18, weight: .semibold)).frame(minHeight: 44)
                }.accessibilityLabel("Choose account").accessibilityIdentifier("portfolio-account-picker")
                Spacer()
            }
            Button { tab = theme == .robinhood ? .assets : .activity } label: {
                Image(systemName: theme == .robinhood ? "magnifyingglass" : "bell")
                    .font(.system(size: 21)).frame(width: 44, height: 44)
            }
            .accessibilityLabel(theme == .robinhood ? "Search assets" : "Activity")
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14).padding(.top, 4).padding(.bottom, 2)
        }
    }

    @ViewBuilder private func home(_ scene: StudioScene) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                switch theme {
                case .robinhood: robinhoodHome(scene)
                case .wealthsimple: wealthsimpleHome(scene)
                case .coinbase: coinbaseHome(scene)
                }
            }
            .padding(.bottom, 28)
        }
        .accessibilityIdentifier("portfolio-home")
    }

    private func robinhoodHome(_ scene: StudioScene) -> some View {
        VStack(alignment: .leading, spacing: 25) {
            VStack(alignment: .leading, spacing: 8) {
                if cryptoAccount { Text("Crypto").font(.system(size: 32, weight: .regular)) }
                HStack(spacing: 10) {
                    Text(scene.money(cryptoAccount ? cryptoValue : profile.total(cash: scene.balance))).font(.system(size: 39, weight: .regular)).monospacedDigit()
                    if cryptoAccount {
                        Button { modal = .editor } label: { Image(systemName: "info.circle").font(.system(size: 21)).foregroundStyle(palette.secondary).frame(width: 44, height: 44) }
                            .accessibilityLabel("Crypto account details")
                    }
                }
                performanceLabel(scene, value: cryptoAccount ? cryptoValue : profile.total(cash: scene.balance), percent: profile.dailyChange)
            }.padding(.horizontal, 24).padding(.top, 14)
            PortfolioTrend(values: profile.chart, range: range, color: palette.accent, fill: false, highlightLastPoint: true)
                .frame(height: 180).padding(.horizontal, 4)
            rangePicker.padding(.horizontal, 24)
            Button { modal = .editor } label: {
                HStack {
                    Text("Buying power").font(.system(size: 15, weight: .medium))
                    Spacer()
                    Text(scene.money(scene.balance)).monospacedDigit()
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                }.frame(minHeight: 52).padding(.horizontal, 24)
            }.buttonStyle(.plain)
            Divider().overlay(palette.separator)
            if !cryptoAccount { VStack(alignment: .leading, spacing: 8) {
                Text("Stocks & ETFs").font(.system(size: 23, weight: .semibold))
                ForEach(profile.positions.filter { $0.kind == .stock }) { position in assetLink(position, scene: scene) }
            }.padding(.horizontal, 24) }
            VStack(alignment: .leading, spacing: 8) {
                HStack { Text("Crypto").font(.system(size: 23, weight: .semibold)); Spacer(); Button("See all") { tab = .assets }.font(.system(size: 14, weight: .medium)) }
                ForEach(profile.positions.filter { $0.kind == .crypto }) { position in assetLink(position, scene: scene) }
            }.padding(.horizontal, 24)
            VStack(alignment: .leading, spacing: 15) {
                Text("Lists").font(.system(size: 23, weight: .semibold))
                NavigationLink { PortfolioAssetsPage(sceneID: sceneID) } label: {
                    HStack { Image(systemName: "list.star").font(.title3); Text("My first list").fontWeight(.medium); Spacer(); Image(systemName: "chevron.right").font(.caption) }.frame(minHeight: 48)
                }.buttonStyle(.plain)
            }.padding(.horizontal, 24)
        }
    }

    private var cryptoValue: Double { profile.positions.filter { $0.kind == .crypto }.reduce(0) { $0 + $1.value } }

    private func wealthsimpleHome(_ scene: StudioScene) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(["Stocks", "ETFs", "Crypto", "CAD", "USD"], id: \.self) { category in
                        Button { holdingsFilter = category } label: {
                            Text(category).font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 18).frame(height: 34)
                                .background(Color(portfolioHex: holdingsFilter == category ? 0xDEDEDE : 0xE7E7E7), in: Capsule())
                                .padding(.vertical, 5)
                        }.buttonStyle(.plain).accessibilityAddTraits(holdingsFilter == category ? .isSelected : [])
                            .accessibilityIdentifier("portfolio-holdings-\(category.lowercased())")
                    }
                }.padding(.horizontal, 18)
            }
            if holdingsFilter == "CAD" || holdingsFilter == "USD" {
                if holdingsFilter == scene.currency {
                    Button { modal = .editor } label: {
                        HStack(spacing: 12) {
                            Text("$").font(.system(size: 24, weight: .medium)).frame(width: 34, height: 34).background(.white, in: RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 4) { Text(scene.currency).font(.system(size: 16, weight: .medium)); Text("Cash").font(.system(size: 14)).foregroundStyle(palette.secondary) }
                            Spacer()
                            Text(PortfolioFormatting.holdingsMoney(scene.balance, currency: scene.currency)).font(.system(size: 16, weight: .medium)).monospacedDigit()
                        }.frame(minHeight: 66).padding(.horizontal, 18)
                    }.buttonStyle(.plain)
                } else { holdingsEmptyState }
            } else {
                let positions = profile.positions.filter { position in
                    if holdingsFilter == nil { return position.units > 0 }
                    if holdingsFilter == "Crypto" { return position.kind == .crypto }
                    let isETF = Self.etfSymbols.contains(position.symbol.uppercased())
                    return position.kind == .stock && (holdingsFilter == "ETFs" ? isETF : !isETF)
                }
                if positions.isEmpty { holdingsEmptyState }
                VStack(spacing: 0) {
                    ForEach(positions) { position in
                        assetLink(position, scene: scene)
                        Divider().overlay(palette.separator).padding(.leading, 46)
                    }
                }.padding(.horizontal, 18)
            }
        }.padding(.top, 12)
    }

    private static let etfSymbols: Set<String> = ["IVV", "VOO", "VOOG", "VTI", "SPY", "QQQ", "VEQT", "XEQT", "VFV", "XIC", "ZSP"]
    private var holdingsEmptyState: some View {
        VStack(spacing: 12) {
            Text("No holdings").font(.system(size: 18, weight: .medium))
            Button("Explore assets") { tab = .assets }.font(.system(size: 14, weight: .medium)).frame(minHeight: 44)
        }.frame(maxWidth: .infinity).padding(.vertical, 45)
    }

    private func coinbaseHome(_ scene: StudioScene) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            NavigationLink { PortfolioBalancePage(sceneID: sceneID) } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("My balance").font(.system(size: 14, weight: .semibold)).foregroundStyle(palette.secondary)
                        Text(scene.money(profile.total(cash: scene.balance))).font(.system(size: 30, weight: .semibold)).monospacedDigit()
                    }
                    Spacer(minLength: 12)
                    PortfolioTrend(values: profile.chart, range: .day, color: palette.accent).frame(width: 76, height: 35).accessibilityHidden(true)
                }.frame(minHeight: 74)
            }.buttonStyle(.plain).accessibilityIdentifier("portfolio-balance").padding(.horizontal, 24)
            HStack(spacing: 0) {
                coinbaseAction("Buy", symbol: "plus") { tab = .assets }
                coinbaseAction("Send", symbol: "arrow.up") { modal = .sendCrypto }
                coinbaseAction("Receive", symbol: "arrow.down") { modal = .receiveCrypto }
                coinbaseAction("Scan", symbol: "viewfinder") { modal = .scan }
            }.padding(.horizontal, 24)
            HStack(spacing: 0) {
                coinbaseShortcut("Card", symbol: "creditcard") { modal = .coinbaseCard }
                coinbaseShortcut("Rewards", symbol: "gift") { modal = .coinbaseRewards }
                coinbaseShortcut("Coinbase\nWallet", symbol: "wallet.pass") { modal = .coinbaseWallet }
                coinbaseShortcut("Advanced\ntrade", symbol: "chart.bar.xaxis") { modal = .coinbaseAdvanced }
            }.padding(.horizontal, 24)
            Divider().overlay(palette.separator)
            VStack(alignment: .leading, spacing: 16) {
                HStack { Text("Prices").font(.system(size: 23, weight: .semibold)); Spacer(); Button { tab = .assets } label: { HStack(spacing: 5) { Text("Watchlist"); Image(systemName: "chevron.down").font(.caption) }.font(.system(size: 13, weight: .medium)).padding(.horizontal, 12).padding(.vertical, 8).background(palette.surface, in: Capsule()) } }
                ForEach(profile.positions.filter { $0.kind == .crypto }.prefix(5)) { position in
                    NavigationLink { PortfolioAssetDetail(sceneID: sceneID, assetID: position.id) } label: { PortfolioAssetRow(position: position, scene: scene, theme: theme, showsPrice: true) }.buttonStyle(.plain).accessibilityIdentifier("portfolio-asset-\(position.symbol)")
                }
                Button { modal = .editor } label: {
                    HStack(spacing: 12) { Image(systemName: "dollarsign").font(.system(size: 22, weight: .semibold)).frame(width: 42, height: 42).background(palette.surface, in: Circle()); VStack(alignment: .leading, spacing: 4) { Text("Cash").fontWeight(.medium); Text(scene.currency).font(.caption).foregroundStyle(palette.secondary) }; Spacer(); Text(scene.money(scene.balance)).monospacedDigit() }.frame(minHeight: 58)
                }.buttonStyle(.plain)
            }.padding(.horizontal, 24)
            HStack(spacing: 15) {
                Image(systemName: "c.circle.fill").font(.system(size: 36))
                VStack(alignment: .leading, spacing: 6) { Text("Coinbase One").font(.system(size: 20, weight: .semibold)); Text("Explore your benefits").font(.system(size: 14)) }
                Spacer()
                Button { modal = .menu } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.accessibilityLabel("Account options")
            }.padding(20).foregroundStyle(.white).background(palette.accent, in: RoundedRectangle(cornerRadius: 18)).padding(.horizontal, 24)
        }
    }

    private func coinbaseAction(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 9) { Image(systemName: symbol).font(.system(size: 20, weight: .medium)).frame(width: 43, height: 43).background(palette.accent, in: Circle()).foregroundStyle(.white); Text(title).font(.system(size: 12)) }.frame(maxWidth: .infinity, minHeight: 75)
        }.buttonStyle(.plain)
    }

    private func coinbaseShortcut(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { VStack(spacing: 8) { CoinbaseShortcutMark(kind: symbol).frame(width: 36, height: 36); Text(title).font(.system(size: 11)).multilineTextAlignment(.center) }.frame(maxWidth: .infinity, minHeight: 75).contentShape(Rectangle()) }.buttonStyle(.plain)
    }

    private func coinbaseUnavailableFeature(_ feature: CoinbaseUnavailableFeature) -> some View {
        NavigationStack {
            ContentUnavailableView(feature.title, systemImage: feature.symbol, description: Text(feature.message))
                .navigationTitle(feature.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { modal = nil } } }
        }
    }

    private func performanceLabel(_ scene: StudioScene, value: Double, percent: Double) -> some View {
        let change = value * percent / 100
        return HStack(spacing: 5) {
            if theme == .robinhood {
                Image(systemName: "triangle.fill").font(.system(size: 8)).rotationEffect(.degrees(percent >= 0 ? 0 : 180))
            } else { Image(systemName: percent >= 0 ? "arrow.up" : "arrow.down").font(.system(size: 11, weight: .semibold)) }
            Text("\(scene.money(abs(change))) (\(PortfolioFormatting.percent(abs(percent))))")
            Text(range.changeLabel).foregroundStyle(palette.secondary)
        }.font(.system(size: 13, weight: .medium)).foregroundStyle(percent >= 0 ? palette.gain : palette.loss)
    }

    private var rangePicker: some View {
        HStack(spacing: 0) {
            ForEach(PortfolioRange.options(for: theme)) { option in
                Button { range = option } label: {
                    HStack(spacing: 3) {
                        if option == .live { Circle().fill(palette.accent.opacity(0.6)).frame(width: 3, height: 3) }
                        Text(option.title)
                    }.font(.system(size: 12, weight: range == option ? .semibold : .medium))
                        .padding(.horizontal, 6).frame(height: 26)
                        .foregroundStyle(range == option && theme == .robinhood ? .black : range == option ? palette.accent : theme == .robinhood ? palette.accent : palette.secondary)
                        .background(range == option ? theme == .robinhood ? palette.accent : palette.accent.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 7))
                        .frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }
    }

    private func assetLink(_ position: MarketPosition, scene: StudioScene) -> some View {
        NavigationLink { PortfolioAssetDetail(sceneID: sceneID, assetID: position.id) } label: {
            PortfolioAssetRow(position: position, scene: scene, theme: theme)
        }.buttonStyle(.plain).accessibilityIdentifier("portfolio-asset-\(position.symbol)")
    }

    private func assetsPage(_ scene: StudioScene) -> some View {
        VStack(spacing: 0) {
            HStack { Image(systemName: "magnifyingglass").foregroundStyle(palette.secondary); TextField(theme == .robinhood ? "Search Robinhood..." : "Search assets", text: $search).autocorrectionDisabled(); if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44) }.accessibilityLabel("Clear search") } }
                .padding(.horizontal, 14).frame(minHeight: 44).background(palette.surface, in: Capsule()).padding(.horizontal, 24).padding(.vertical, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if theme == .robinhood && search.isEmpty { robinhoodDiscovery(scene) }
                    if theme != .robinhood || !search.isEmpty {
                    HStack { Text(theme == .coinbase ? "My assets" : theme == .wealthsimple ? "Holdings" : "Investments").font(.system(size: 27, weight: .semibold)); Spacer(); Button { modal = .editor } label: { Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44) }.accessibilityLabel("Edit portfolio") }
                    if theme == .wealthsimple {
                        HStack(spacing: 8) {
                            assetFilterButton("All", kind: nil)
                            assetFilterButton("Stocks & ETFs", kind: .stock)
                            assetFilterButton("Crypto", kind: .crypto)
                        }.padding(.bottom, 12)
                    }
                    let positions = profile.positions.filter { (assetFilter == nil || (theme != .wealthsimple && theme != .robinhood) || $0.kind == assetFilter) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.symbol.localizedCaseInsensitiveContains(search)) }
                    if positions.isEmpty { ContentUnavailableView.search(text: search) }
                    ForEach(positions) { position in assetLink(position, scene: scene) }
                    }
                }.padding(.horizontal, 24).padding(.bottom, 24)
            }
            .accessibilityIdentifier("portfolio-assets")
        }
    }

    private func robinhoodDiscovery(_ scene: StudioScene) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 18) {
                ForEach(["Now", "Macro", "Crypto", "Sports"], id: \.self) { category in
                    Button { discoveryCategory = category; assetFilter = category == "Crypto" ? .crypto : nil } label: {
                        Text(category).font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(discoveryCategory == category ? palette.ink : palette.secondary)
                            .padding(.horizontal, 8).frame(minHeight: 34)
                            .background(discoveryCategory == category ? palette.surface : .clear, in: RoundedRectangle(cornerRadius: 7))
                            .padding(.vertical, 5)
                    }.buttonStyle(.plain).accessibilityIdentifier("portfolio-discovery-\(category.lowercased())")
                }
            }
            Text("Market").font(.system(size: 21, weight: .semibold))
            let positions = profile.positions.filter { position in
                discoveryCategory != "Sports" && (discoveryCategory != "Crypto" || position.kind == .crypto)
            }
            if positions.isEmpty {
                Text("No \(discoveryCategory.lowercased()) markets in this account").font(.system(size: 14)).foregroundStyle(palette.secondary).padding(.vertical, 25)
                Button("Edit portfolio") { modal = .editor }.font(.system(size: 14, weight: .medium)).frame(minHeight: 44)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(positions.prefix(5)) { position in
                        NavigationLink { PortfolioAssetDetail(sceneID: sceneID, assetID: position.id) } label: {
                            VStack(alignment: .leading, spacing: 14) {
                                Text(position.name).font(.system(size: 17, weight: .semibold)).lineLimit(1)
                                PortfolioTrend(values: position.chart, range: .day, color: position.changePercent >= 0 ? palette.gain : palette.loss, highlightLastPoint: true).frame(height: 64).padding(.vertical, 8)
                                Text(scene.money(position.price)).font(.system(size: 17, weight: .semibold)).monospacedDigit()
                                HStack(spacing: 5) {
                                    Image(systemName: "triangle.fill").font(.system(size: 10)).rotationEffect(.degrees(position.changePercent >= 0 ? 0 : 180))
                                    Text(PortfolioFormatting.percent(abs(position.changePercent))).font(.system(size: 15))
                                }.foregroundStyle(position.changePercent >= 0 ? palette.gain : palette.loss)
                            }.padding(16).frame(width: 150, alignment: .leading).background(palette.surface, in: RoundedRectangle(cornerRadius: 9))
                                .overlay(RoundedRectangle(cornerRadius: 9).stroke(palette.separator, lineWidth: 1))
                        }.buttonStyle(.plain).accessibilityIdentifier("portfolio-asset-\(position.symbol)")
                    }
                }
            }
            if !positions.isEmpty {
                HStack(spacing: 6) { Text("Top movers").font(.system(size: 21, weight: .semibold)); Image(systemName: "info.circle").foregroundStyle(palette.secondary) }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(positions.sorted { abs($0.changePercent) > abs($1.changePercent) }.prefix(6)) { position in
                            NavigationLink { PortfolioAssetDetail(sceneID: sceneID, assetID: position.id) } label: {
                                HStack(spacing: 7) {
                                    Text(position.symbol).foregroundStyle(palette.ink)
                                    Image(systemName: "triangle.fill").font(.system(size: 9)).rotationEffect(.degrees(position.changePercent >= 0 ? 0 : 180))
                                    Text(PortfolioFormatting.percent(abs(position.changePercent))).fontWeight(.semibold)
                                }.font(.system(size: 14)).foregroundStyle(position.changePercent >= 0 ? palette.gain : palette.loss)
                                    .padding(.horizontal, 15).frame(minHeight: 42).background(palette.surface, in: Capsule())
                                    .overlay(Capsule().stroke(palette.separator, lineWidth: 1))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }.padding(.bottom, 20)
    }

    private func assetFilterButton(_ title: String, kind: MarketAssetKind?) -> some View {
        Button { assetFilter = kind } label: { Text(title).font(.system(size: 12, weight: .medium)).padding(.horizontal, 13).frame(minHeight: 44).background(assetFilter == kind ? palette.ink.opacity(0.08) : palette.surface, in: Capsule()) }.buttonStyle(.plain)
    }

    private func profilePage(_ scene: StudioScene) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(scene.name).font(.system(size: 30, weight: .semibold))
                Text(theme.name).font(.system(size: 16)).foregroundStyle(palette.secondary)
                profileButton("Portfolio settings", symbol: "slider.horizontal.3") { modal = .editor }
                profileButton("Activity", symbol: "clock.arrow.circlepath") { tab = .activity }
                profileButton("Choose platform", symbol: "square.grid.2x2") { modal = .themes }
                profileButton("Return to Studio", symbol: "arrow.uturn.backward") { dismiss() }
            }.padding(24)
        }
    }

    private var wealthMovePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Move money").font(.system(size: 27, weight: .semibold)).padding(.bottom, 12)
                profileButton("Add money", symbol: "plus") { modal = .addCash }
                profileButton("Transfer", symbol: "arrow.left.arrow.right") { modal = .sendCash }
                profileButton("Send crypto", symbol: "arrow.up.right") { modal = .sendCrypto }
                profileButton("Receive crypto", symbol: "arrow.down.left") { modal = .receiveCrypto }
            }.padding(24)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func profileButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { HStack { Image(systemName: symbol).frame(width: 28); Text(title); Spacer(); Image(systemName: "chevron.right").font(.caption) }.frame(minHeight: 52) }.buttonStyle(.plain)
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            tabButton(.home, symbol: theme == .robinhood ? "chart.line.uptrend.xyaxis" : "house", title: "Home")
            tabButton(.assets, symbol: theme == .coinbase ? "chart.pie" : "magnifyingglass", title: theme == .coinbase ? "Assets" : "Discover")
            if theme == .wealthsimple {
                tabButton(.profile, symbol: "arrow.left.arrow.right", title: "Move")
                tabButton(.activity, symbol: "clock", title: "Activity")
            } else {
                tabButton(.activity, symbol: "clock", title: "Activity")
                tabButton(.profile, symbol: "person.crop.circle", title: "Account")
            }
        }
        .padding(.top, 8).padding(.horizontal, 12).padding(.bottom, 4)
        .background(theme == .wealthsimple ? palette.surface : palette.background, in: Capsule())
        .overlay { if theme == .wealthsimple { Capsule().stroke(.white, lineWidth: 1) } }
        .padding(.horizontal, theme == .wealthsimple ? 24 : 0)
        .padding(.bottom, theme == .wealthsimple ? 8 : 0)
        .background(palette.background)
    }

    private func tabButton(_ option: PortfolioTab, symbol: String, title: String) -> some View {
        Button { tab = option } label: {
            VStack(spacing: 5) { Image(systemName: symbol).font(.system(size: 22, weight: tab == option ? .semibold : .regular)); if theme == .coinbase { Text(title).font(.system(size: 10, weight: .medium)) } }
                .frame(maxWidth: .infinity, minHeight: 46).foregroundStyle(theme == .wealthsimple ? palette.ink : tab == option ? palette.accent : palette.secondary)
                .background(theme == .wealthsimple && tab == option ? Color(portfolioHex: 0xE2E2E2) : .clear, in: Capsule())
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(title).accessibilityIdentifier("portfolio-tab-\(option.rawValue)")
    }

    private var menuSheet: some View {
        NavigationStack {
            List {
                Section {
                    Button("Edit portfolio") { modal = .editor }
                    Button("Choose platform") { modal = .themes }.accessibilityIdentifier("portfolio-theme-picker")
                    Button("Activity") { modal = nil; tab = .activity }
                }
                Section { Button("Return to Studio") { modal = nil; dismiss() }.accessibilityIdentifier("close-scene") }
                Section { Text("This is a saved roleplay scene. Prices, charts and transactions are editable and remain on this device.").font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle(theme.name).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { modal = nil } } }
        }
    }

    private var themesSheet: some View {
        NavigationStack {
            List(PortfolioTheme.allCases) { platform in
                Button {
                    var updated = profile
                    updated.theme = platform
                    // A platform switch preserves held value and adds zero-unit watchlist assets.
                    let watchlist = PortfolioProfile.starter(for: sceneID, theme: platform).positions
                    for var asset in watchlist where !updated.positions.contains(where: { $0.symbol.caseInsensitiveCompare(asset.symbol) == .orderedSame }) {
                        asset.units = 0
                        asset.averageCost = 0
                        updated.positions.append(asset)
                    }
                    if store.updatePortfolioProfile(updated) { modal = nil; tab = .home }
                } label: { HStack { Text(platform.name); Spacer(); if platform == theme { Image(systemName: "checkmark") } }.foregroundStyle(.primary) }
            }
            .navigationTitle("Choose platform").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { modal = nil } } }
            .safeAreaInset(edge: .bottom) { if let error = store.error { Text(error).font(.footnote).foregroundStyle(.red).padding(16).frame(maxWidth: .infinity).background(.background) } }
        }
    }
}

private enum PortfolioModal: String, Identifiable {
    case menu, themes, editor, addCash, sendCash, sendCrypto, receiveCrypto, scan
    case coinbaseCard, coinbaseRewards, coinbaseWallet, coinbaseAdvanced
    var id: String { rawValue }
}
private enum CoinbaseUnavailableFeature {
    case card, rewards, wallet, advanced
    var title: String {
        switch self { case .card: return "Card"; case .rewards: return "Rewards"; case .wallet: return "Coinbase Wallet"; case .advanced: return "Advanced trade" }
    }
    var symbol: String {
        switch self { case .card: return "creditcard"; case .rewards: return "gift"; case .wallet: return "wallet.pass"; case .advanced: return "chart.bar.xaxis" }
    }
    var message: String {
        switch self {
        case .card: return "Card information is unavailable."
        case .rewards: return "No rewards are available."
        case .wallet: return "A separate wallet is not set up."
        case .advanced: return "Advanced trading is unavailable."
        }
    }
}
private enum PortfolioTab: String { case home, assets, activity, profile }
private enum PortfolioRange: String, CaseIterable, Identifiable {
    case live, hour, day, week, month, quarter, yearToDate, year, all
    var id: String { rawValue }
    var title: String {
        switch self { case .live: return "LIVE"; case .hour: return "1H"; case .day: return "1D"; case .week: return "1W"; case .month: return "1M"; case .quarter: return "3M"; case .yearToDate: return "YTD"; case .year: return "1Y"; case .all: return "All" }
    }
    var changeLabel: String {
        switch self { case .live: return "live"; case .hour: return "past hour"; case .day: return "Today"; case .week: return "past week"; case .month: return "past month"; case .quarter: return "past 3 months"; case .yearToDate: return "this year"; case .year: return "past year"; case .all: return "all time" }
    }
    static func options(for theme: PortfolioTheme) -> [Self] {
        switch theme {
        case .robinhood: return [.live, .day, .week, .month, .quarter, .yearToDate, .year]
        case .coinbase: return [.hour, .day, .week, .month, .year, .all]
        case .wealthsimple: return [.day, .week, .month, .quarter, .year, .all]
        }
    }
}

private struct PortfolioPalette {
    let background: Color
    let surface: Color
    let ink: Color
    let secondary: Color
    let accent: Color
    let gain: Color
    let loss = Color(portfolioHex: 0xD24944)
    let separator: Color
    let isDark: Bool
    init(_ theme: PortfolioTheme) {
        switch theme {
        case .robinhood:
            background = Color(portfolioHex: 0x000000); surface = Color(portfolioHex: 0x191919); ink = .white; secondary = Color(portfolioHex: 0xA3A3A3); accent = Color(portfolioHex: 0xCCFF00); gain = accent; separator = Color(portfolioHex: 0x262626); isDark = true
        case .wealthsimple:
            background = Color(portfolioHex: 0xF3F3F3); surface = .white; ink = Color(portfolioHex: 0x111111); secondary = Color(portfolioHex: 0x787878); accent = ink; gain = Color(portfolioHex: 0x377342); separator = Color(portfolioHex: 0xDFDFDF); isDark = false
        case .coinbase:
            background = .white; surface = Color(portfolioHex: 0xF3F5F7); ink = Color(portfolioHex: 0x0A0B0D); secondary = Color(portfolioHex: 0x6B7077); accent = Color(portfolioHex: 0x0052FF); gain = Color(portfolioHex: 0x098551); separator = Color(portfolioHex: 0xE8EAED); isDark = false
        }
    }
}

private enum PortfolioFormatting {
    static func percent(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(2))) + "%" }
    static func quantity(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...8))) }
    // Holdings uses the compact currency symbol while CAD/USD remain explicit filters.
    // This changes presentation only; saved amounts and their currency are preserved.
    static func holdingsMoney(_ value: Double, currency: String) -> String {
        value.formatted(.currency(code: currency).presentation(.narrow))
    }
}

private struct PortfolioTrend: View {
    let values: [Double]
    let range: PortfolioRange
    let color: Color
    var fill = false
    var highlightLastPoint = false
    private var points: [PortfolioChartPoint] {
        let source = values.isEmpty ? [0.4, 0.6] : values
        let offset = PortfolioRange.allCases.firstIndex(of: range) ?? 0
        let anchors = source.enumerated().map { index, value in
            let shifted = source[(index + offset) % source.count]
            return range == .day ? value : (value * 0.8 + shifted * 0.2)
        }
        // Render the editable fictional trace with small anchored intermediate movements.
        // Each saved point and both endpoints remain unchanged.
        return anchors.indices.flatMap { index -> [PortfolioChartPoint] in
            guard index < anchors.count - 1 else { return [PortfolioChartPoint(id: index * 6, value: anchors[index])] }
            return (0..<6).map { step in
                let fraction = Double(step) / 6
                let value = anchors[index] + (anchors[index + 1] - anchors[index]) * fraction
                let amplitude = min(0.022, abs(anchors[index + 1] - anchors[index]) * 0.16 + 0.005)
                let movement = sin(fraction * .pi) * sin(Double(index * 11 + step * 7)) * amplitude
                return PortfolioChartPoint(id: index * 6 + step, value: min(1, max(0, value + movement)))
            }
        }
    }
    var body: some View {
        Chart(points) { point in
            if fill { AreaMark(x: .value("Period", point.id), y: .value("Value", point.value)).foregroundStyle(LinearGradient(colors: [color.opacity(0.15), color.opacity(0.01)], startPoint: .top, endPoint: .bottom)).interpolationMethod(.linear) }
            LineMark(x: .value("Period", point.id), y: .value("Value", point.value)).foregroundStyle(color).lineStyle(StrokeStyle(lineWidth: 2.1, lineJoin: .round)).interpolationMethod(.linear)
            if highlightLastPoint && point.id == points.last?.id {
                PointMark(x: .value("Period", point.id), y: .value("Value", point.value)).foregroundStyle(color.opacity(0.13)).symbolSize(220)
                PointMark(x: .value("Period", point.id), y: .value("Value", point.value)).foregroundStyle(color).symbolSize(35)
            }
        }
        .chartXAxis(.hidden).chartYAxis(.hidden).chartYScale(domain: 0...1)
        .chartXScale(range: .plotDimension(padding: highlightLastPoint ? 10 : 0))
        .accessibilityElement(children: .ignore).accessibilityLabel("Portfolio trend, \(range.changeLabel)")
    }
}
private struct PortfolioChartPoint: Identifiable { let id: Int; let value: Double }

private struct PortfolioAssetRow: View {
    let position: MarketPosition
    let scene: StudioScene
    let theme: PortfolioTheme
    var showsPrice = false
    private var palette: PortfolioPalette { PortfolioPalette(theme) }
    @ViewBuilder var body: some View {
        if theme == .wealthsimple {
            HStack(spacing: 12) {
                PortfolioAssetIcon(position: position, square: true).frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 5) {
                    Text(position.symbol).font(.system(size: 16, weight: .medium))
                    Text("\(PortfolioFormatting.quantity(position.units))\(position.kind == .stock ? " shares" : "")").font(.system(size: 14)).foregroundStyle(palette.secondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 5) {
                    Text(PortfolioFormatting.holdingsMoney(showsPrice ? position.price : position.value, currency: scene.currency)).font(.system(size: 16, weight: .medium)).monospacedDigit()
                    let percent = position.costBasis > 0 ? position.unrealizedGain / position.costBasis * 100 : 0
                    Text("\(position.unrealizedGain >= 0 ? "+" : "−") \(PortfolioFormatting.holdingsMoney(abs(position.unrealizedGain), currency: scene.currency)) (\(percent >= 0 ? "+" : "−")\(PortfolioFormatting.percent(abs(percent))))")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(position.unrealizedGain >= 0 ? palette.gain : palette.loss).lineLimit(1).minimumScaleFactor(0.75)
                }
            }.frame(minHeight: 74).contentShape(Rectangle())
        } else {
        HStack(spacing: 12) {
            if theme != .robinhood { PortfolioAssetIcon(position: position).frame(width: 40, height: 40) }
            VStack(alignment: .leading, spacing: 5) {
                Text(theme == .coinbase ? position.name : position.symbol).font(.system(size: 16, weight: .medium))
                Text(theme == .coinbase ? position.symbol : "\(PortfolioFormatting.quantity(position.units)) \(position.kind == .stock ? "shares" : position.symbol)").font(.system(size: 13)).foregroundStyle(palette.secondary)
            }
            Spacer(minLength: 10)
            if theme == .robinhood { PortfolioTrend(values: position.chart, range: .day, color: position.changePercent >= 0 ? palette.gain : palette.loss).frame(width: 64, height: 28).accessibilityHidden(true) }
            if theme == .coinbase && showsPrice { PortfolioTrend(values: position.chart, range: .day, color: position.symbol == "BTC" ? Color(portfolioHex: 0xE89E32) : position.symbol == "SOL" ? Color(portfolioHex: 0xAE56E5) : palette.accent).frame(width: 55, height: 25).accessibilityHidden(true) }
            VStack(alignment: .trailing, spacing: 5) {
                Text(scene.money(showsPrice ? position.price : position.value)).font(.system(size: 15, weight: .medium)).monospacedDigit()
                HStack(spacing: 3) {
                    if theme == .coinbase { Image(systemName: position.changePercent >= 0 ? "arrow.up.right" : "arrow.down.right").font(.system(size: 12)) }
                    Text("\(theme == .coinbase ? "" : position.changePercent >= 0 ? "+" : "")\(PortfolioFormatting.percent(theme == .coinbase ? abs(position.changePercent) : position.changePercent))")
                }.font(.system(size: 13)).foregroundStyle(position.changePercent >= 0 ? palette.gain : palette.loss)
            }
        }.frame(minHeight: 65).contentShape(Rectangle())
        }
    }
}

private struct PortfolioAssetIcon: View {
    let position: MarketPosition
    var square = false
    private var symbol: String { position.symbol.uppercased() }
    private var color: Color {
        switch symbol {
        case "BTC": return Color(portfolioHex: 0xF7931A)
        case "ETH": return Color(portfolioHex: 0x627EEA)
        case "SOL": return Color(portfolioHex: 0x161B22)
        case "USDC": return Color(portfolioHex: 0x2775CA)
        case "AAPL", "GME": return .black
        case "TSLA", "JNJ": return Color(portfolioHex: 0xD71920)
        case "AC", "AC.TO": return Color(portfolioHex: 0xEF1231)
        case "NVDA": return Color(portfolioHex: 0x76B900)
        case "ZM", "AXP": return Color(portfolioHex: 0x0052FF)
        case "VOOG", "VOO", "VTI": return Color(portfolioHex: 0xA71930)
        case "IVV": return .white
        default: return Color(portfolioHex: 0x4B6786)
        }
    }
    private var publicGlyph: String? {
        switch symbol {
        case "AC", "AC.TO": return "AirCanada"
        case "NVDA": return "Nvidia"
        case "TSLA": return "Tesla"
        case "IVV": return "IShares"
        case "AXP": return "AmericanExpress"
        case "GME": return "GameStop"
        case "JNJ": return "JohnsonJohnson"
        default: return nil
        }
    }
    private var templateGlyph: Bool { ["NVDA", "TSLA", "AXP", "JNJ"].contains(symbol) }
    @ViewBuilder private var glyph: some View {
        if let publicGlyph {
            Image("PortfolioFidelity-\(publicGlyph)")
                .resizable()
                .renderingMode(templateGlyph ? .template : .original)
                .scaledToFit()
                .foregroundStyle(.white)
                .padding(symbol == "AC" || symbol == "AC.TO" || symbol == "IVV" ? 0 : symbol == "AXP" ? 3 : 5)
        } else if symbol == "BTC" {
            Image(systemName: "bitcoinsign").font(.system(size: 25, weight: .semibold)).rotationEffect(.degrees(14)).foregroundStyle(.white)
        } else if symbol == "AAPL" {
            Image(systemName: "apple.logo").font(.system(size: 24)).foregroundStyle(.white)
        } else if symbol == "ETH" {
            PortfolioEthereumMark().padding(8)
        } else if symbol == "SOL" {
            PortfolioSolanaMark().padding(9)
        } else if symbol == "USDC" {
            PortfolioUSDCMark().padding(7)
        } else if symbol == "ZM" {
            Text("Z").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(.white)
        } else if ["VOOG", "VOO", "VTI"].contains(symbol) {
            Text("V").font(.system(size: 27, weight: .medium, design: .serif)).foregroundStyle(.white)
        } else {
            Text(String(symbol.prefix(1))).font(.system(size: 21, weight: .semibold)).foregroundStyle(.white)
        }
    }
    var body: some View {
        Rectangle().fill(color).overlay { glyph }
            .clipShape(RoundedRectangle(cornerRadius: square ? 8 : 100))
            .overlay {
                if square && symbol == "IVV" { RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.04), lineWidth: 1) }
            }
            .accessibilityHidden(true)
    }
}

private struct PortfolioUSDCMark: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Circle().trim(from: 0.05, to: 0.45).stroke(.white, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                Circle().trim(from: 0.55, to: 0.95).stroke(.white, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                Text("$").font(.system(size: geometry.size.height * 0.86, weight: .medium)).foregroundStyle(.white)
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

private struct PortfolioDotGrid: View {
    var body: some View {
        VStack(spacing: 3) {
            ForEach(0..<3) { _ in
                HStack(spacing: 3) { ForEach(0..<3) { _ in Circle().frame(width: 4, height: 4) } }
            }
        }.accessibilityHidden(true)
    }
}

private struct PortfolioEthereumMark: View {
    var body: some View {
        ZStack {
            PortfolioPolygon(points: [.init(x: 0.5, y: 0), .init(x: 0.1, y: 0.55), .init(x: 0.5, y: 0.73)]).fill(Color(portfolioHex: 0xEDF2FF))
            PortfolioPolygon(points: [.init(x: 0.5, y: 0), .init(x: 0.9, y: 0.55), .init(x: 0.5, y: 0.73)]).fill(Color(portfolioHex: 0xC6D2FB))
            PortfolioPolygon(points: [.init(x: 0.1, y: 0.55), .init(x: 0.5, y: 0.39), .init(x: 0.5, y: 0.73)]).fill(Color(portfolioHex: 0xA1B4EF))
            PortfolioPolygon(points: [.init(x: 0.9, y: 0.55), .init(x: 0.5, y: 0.39), .init(x: 0.5, y: 0.73)]).fill(Color(portfolioHex: 0x8098DF))
            PortfolioPolygon(points: [.init(x: 0.1, y: 0.63), .init(x: 0.5, y: 1), .init(x: 0.5, y: 0.81)]).fill(Color(portfolioHex: 0xE5EDFF))
            PortfolioPolygon(points: [.init(x: 0.9, y: 0.63), .init(x: 0.5, y: 1), .init(x: 0.5, y: 0.81)]).fill(Color(portfolioHex: 0xB4C6F8))
        }
    }
}

private struct PortfolioSolanaMark: View {
    var body: some View {
        ZStack {
            PortfolioPolygon(points: [.init(x: 0.2, y: 0.06), .init(x: 1, y: 0.06), .init(x: 0.8, y: 0.29), .init(x: 0, y: 0.29)])
            PortfolioPolygon(points: [.init(x: 0, y: 0.39), .init(x: 0.8, y: 0.39), .init(x: 1, y: 0.62), .init(x: 0.2, y: 0.62)])
            PortfolioPolygon(points: [.init(x: 0.2, y: 0.72), .init(x: 1, y: 0.72), .init(x: 0.8, y: 0.95), .init(x: 0, y: 0.95)])
        }.foregroundStyle(LinearGradient(colors: [Color(portfolioHex: 0x00FFA3), Color(portfolioHex: 0xA147F8)], startPoint: .topLeading, endPoint: .bottomTrailing))
    }
}

private struct PortfolioPolygon: Shape {
    let points: [CGPoint]
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: rect.minX + first.x * rect.width, y: rect.minY + first.y * rect.height))
        for point in points.dropFirst() { path.addLine(to: CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height)) }
        path.closeSubpath()
        return path
    }
}

private struct CoinbaseShortcutMark: View {
    let kind: String
    private let blue = Color(portfolioHex: 0x0052FF)
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                switch kind {
                case "wallet.pass":
                    PortfolioPolygon(points: [.init(x: 0.28, y: 0.1), .init(x: 0.93, y: 0.1), .init(x: 0.93, y: 0.77), .init(x: 0.28, y: 0.77)]).fill(Color(portfolioHex: 0xD0D3DA))
                    PortfolioPolygon(points: [.init(x: 0.07, y: 0.1), .init(x: 0.72, y: 0.37), .init(x: 0.72, y: 0.97), .init(x: 0.07, y: 0.7)]).fill(blue)
                    PortfolioPolygon(points: [.init(x: 0.07, y: 0.1), .init(x: 0.72, y: 0.37), .init(x: 0.72, y: 0.7), .init(x: 0.07, y: 0.7)]).fill(Color(portfolioHex: 0x0A0B0D))
                case "creditcard":
                    RoundedRectangle(cornerRadius: 1).fill(blue).frame(width: geometry.size.width * 0.57, height: geometry.size.height * 0.9).offset(x: -geometry.size.width * 0.1)
                    Circle().fill(Color(portfolioHex: 0xD0D3DA))
                        .overlay(alignment: .leading) { Rectangle().fill(Color(portfolioHex: 0x0A0B0D)).frame(width: geometry.size.width * 0.275) }
                        .clipShape(Circle()).frame(width: geometry.size.width * 0.55).offset(x: geometry.size.width * 0.19)
                case "gift":
                    RoundedRectangle(cornerRadius: geometry.size.width * 0.13).stroke(blue, lineWidth: 2).frame(width: geometry.size.width * 0.88, height: geometry.size.height * 0.38).offset(y: -geometry.size.height * 0.12)
                    PortfolioPolygon(points: [.init(x: 0.21, y: 0.24), .init(x: 0.79, y: 0.24), .init(x: 0.74, y: 0.51), .init(x: 0.67, y: 0.62), .init(x: 0.5, y: 0.7), .init(x: 0.33, y: 0.62), .init(x: 0.26, y: 0.51)]).fill(blue)
                    Rectangle().fill(Color(portfolioHex: 0xD0D3DA)).frame(width: geometry.size.width * 0.13, height: geometry.size.height * 0.25).offset(y: geometry.size.height * 0.34)
                    PortfolioPolygon(points: [.init(x: 0.4, y: 0.88), .init(x: 0.6, y: 0.88), .init(x: 0.7, y: 0.98), .init(x: 0.3, y: 0.98)]).fill(Color(portfolioHex: 0xD0D3DA))
                    Circle().fill(Color(portfolioHex: 0xFFD600)).frame(width: geometry.size.width * 0.34).offset(y: -geometry.size.height * 0.32)
                default:
                    Rectangle().fill(Color(portfolioHex: 0xD0D3DA)).frame(height: geometry.size.height * 0.38)
                    Rectangle().fill(blue).frame(width: geometry.size.width * 0.15, height: geometry.size.height * 0.93).offset(x: -geometry.size.width * 0.18)
                    Rectangle().fill(blue).frame(width: geometry.size.width * 0.15, height: geometry.size.height).offset(x: geometry.size.width * 0.2)
                    Rectangle().fill(Color(portfolioHex: 0x0A0B0D)).frame(width: geometry.size.width * 0.27, height: geometry.size.height * 0.41).offset(x: -geometry.size.width * 0.18)
                    Rectangle().fill(Color(portfolioHex: 0x0A0B0D)).frame(width: geometry.size.width * 0.27, height: geometry.size.height * 0.54).offset(x: geometry.size.width * 0.2)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }.accessibilityHidden(true)
    }
}

private struct PortfolioAssetsPage: View {
    @EnvironmentObject private var store: StudioStore
    let sceneID: UUID
    @State private var search = ""
    private var profile: PortfolioProfile { store.portfolioProfile(for: sceneID) }
    private var palette: PortfolioPalette { PortfolioPalette(profile.theme) }
    var body: some View {
        Group {
            if let scene = store.scenes.first(where: { $0.id == sceneID }) {
                List {
                    ForEach(profile.positions.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.symbol.localizedCaseInsensitiveContains(search) }) { position in
                        NavigationLink { PortfolioAssetDetail(sceneID: sceneID, assetID: position.id) } label: { PortfolioAssetRow(position: position, scene: scene, theme: profile.theme) }.listRowBackground(palette.background)
                    }
                }.listStyle(.plain).scrollContentBackground(.hidden).background(palette.background)
                    .searchable(text: $search, prompt: "Search assets")
            } else { ContentUnavailableView("Portfolio unavailable", systemImage: "chart.pie") }
        }
        .navigationTitle("Assets").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
    }
}

private struct PortfolioBalancePage: View {
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    let sceneID: UUID
    @State private var range: PortfolioRange = .week
    @State private var movement: PortfolioModal?
    @State private var balanceInfo = false
    private var profile: PortfolioProfile { store.portfolioProfile(for: sceneID) }
    private var palette: PortfolioPalette { PortfolioPalette(profile.theme) }
    var body: some View {
        Group {
            if let scene = store.scenes.first(where: { $0.id == sceneID }) {
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Button { dismiss() } label: { PortfolioDotGrid().frame(width: 44, height: 44) }.accessibilityLabel("Return to Home")
                        NavigationLink { PortfolioAssetsPage(sceneID: sceneID) } label: {
                            HStack(spacing: 8) { Image(systemName: "magnifyingglass").font(.system(size: 14)); Text("Search for an asset").font(.system(size: 13)); Spacer() }
                                .padding(.horizontal, 12).frame(minHeight: 38).background(palette.surface, in: Capsule()).foregroundStyle(palette.secondary)
                        }
                        NavigationLink { PortfolioActivityPage(sceneID: sceneID) } label: { Image(systemName: "bell").font(.system(size: 21)).frame(width: 44, height: 44) }.accessibilityLabel("Activity")
                    }.buttonStyle(.plain).padding(.horizontal, 14).padding(.top, 4).padding(.bottom, 2)
                ScrollView {
                    VStack(alignment: .leading, spacing: 25) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("My balance").font(.system(size: 15)).foregroundStyle(palette.secondary)
                            HStack {
                                Text(scene.money(profile.total(cash: scene.balance))).font(.system(size: 34, weight: .semibold)).monospacedDigit()
                                Spacer()
                                Button { balanceInfo = true } label: { Image(systemName: "info.circle.fill").font(.system(size: 19)).frame(width: 43, height: 43).background(palette.surface, in: Circle()) }.accessibilityLabel("Balance information")
                                ShareLink(item: "\(scene.name): \(scene.money(profile.total(cash: scene.balance)))") { Image(systemName: "square.and.arrow.up").font(.system(size: 19)).frame(width: 43, height: 43).background(palette.surface, in: Circle()) }.accessibilityLabel("Share balance")
                            }
                        }
                        VStack(alignment: .trailing, spacing: 10) {
                            Text(scene.money(profile.total(cash: scene.balance))).font(.system(size: 14)).foregroundStyle(palette.secondary)
                            PortfolioTrend(values: profile.chart, range: range, color: palette.accent).frame(height: 200)
                        }
                        HStack(spacing: 0) {
                            ForEach(PortfolioRange.options(for: .coinbase)) { option in
                                Button { range = option } label: {
                                    Text(option.title).font(.system(size: 14, weight: range == option ? .semibold : .medium))
                                        .frame(width: 44, height: 44).foregroundStyle(range == option ? palette.accent : palette.secondary)
                                        .background(range == option ? palette.accent.opacity(0.035) : .clear, in: Circle())
                                        .frame(maxWidth: .infinity)
                                }.buttonStyle(.plain)
                            }
                        }
                        HStack(spacing: 0) {
                            balanceAction("Add cash", symbol: "building.columns", destination: .addCash)
                            balanceAction("Cash out", symbol: "banknote", destination: .sendCash)
                            balanceAction("Send", symbol: "arrow.up", destination: .sendCrypto)
                            balanceAction("Receive", symbol: "arrow.down", destination: .receiveCrypto)
                        }
                        Divider().padding(.horizontal, -24).overlay(palette.separator)
                        Text("My balances").font(.system(size: 23, weight: .semibold))
                        ForEach(profile.positions) { position in
                            NavigationLink { PortfolioAssetDetail(sceneID: sceneID, assetID: position.id) } label: { PortfolioAssetRow(position: position, scene: scene, theme: profile.theme) }.buttonStyle(.plain)
                        }
                        HStack { Text(scene.currency); Spacer(); Text(scene.money(scene.balance)).monospacedDigit() }.font(.system(size: 16, weight: .medium)).frame(minHeight: 54)
                    }.padding(24)
                }
                }
            } else { ContentUnavailableView("Portfolio unavailable", systemImage: "chart.pie") }
        }
        .background(palette.background.ignoresSafeArea()).foregroundStyle(palette.ink)
        .navigationTitle("My balance").navigationBarTitleDisplayMode(.inline).toolbar(.hidden, for: .navigationBar)
        .sheet(item: $movement) { destination in
            switch destination {
            case .addCash: PortfolioCashMovementPage(sceneID: sceneID, incoming: true)
            case .sendCash: PortfolioCashMovementPage(sceneID: sceneID, incoming: false)
            case .sendCrypto: PortfolioTransferPage(sceneID: sceneID, kind: .send)
            default: PortfolioTransferPage(sceneID: sceneID, kind: .receive)
            }
        }
        .alert("My balance", isPresented: $balanceInfo) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Cash and the current value of the assets in this account are included in your balance.")
        }
    }
    private func balanceAction(_ title: String, symbol: String, destination: PortfolioModal) -> some View {
        Button { movement = destination } label: { VStack(spacing: 9) { Image(systemName: symbol).font(.system(size: 19, weight: .medium)).frame(width: 43, height: 43).background(palette.accent, in: Circle()).foregroundStyle(.white); Text(title).font(.system(size: 11)) }.frame(maxWidth: .infinity, minHeight: 78) }.buttonStyle(.plain)
    }
}

private struct PortfolioCashMovementPage: View {
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    let sceneID: UUID
    let incoming: Bool
    var initialRecipient = ""
    @State private var amount = "100"
    @State private var recipient = ""
    @State private var reviewing = false
    @State private var completed = false
    private var scene: StudioScene? { store.scenes.first { $0.id == sceneID } }
    private var palette: PortfolioPalette { PortfolioPalette(store.portfolioProfile(for: sceneID).theme) }
    private var parsed: Double? { Simulation.parseAmount(amount) }
    private var valid: Bool {
        guard let value = parsed, let scene else { return false }
        return Simulation.validAmount(value) && (incoming ? scene.balance + value <= 1_000_000_000 : value <= scene.balance) && recipient.count <= 240
    }
    var body: some View {
        NavigationStack {
            Group {
                if let scene {
                    if completed {
                        VStack(spacing: 22) {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 77)).foregroundStyle(palette.accent)
                            Text(incoming ? "Cash added" : "Transfer complete").font(.system(size: 29, weight: .semibold))
                            Text(scene.money(parsed ?? 0)).font(.system(size: 33, weight: .medium)).monospacedDigit()
                            Spacer()
                            Button("Done") { dismiss() }.buttonStyle(.borderedProminent).controlSize(.large).padding(.bottom, 24)
                        }.frame(maxWidth: .infinity)
                    } else if reviewing {
                        VStack(alignment: .leading, spacing: 24) {
                            Text("Review transfer").font(.system(size: 29, weight: .medium)).padding(.top, 26)
                            LabeledContent("Amount", value: scene.money(parsed ?? 0))
                            LabeledContent(incoming ? "From" : "To", value: recipient.isEmpty ? "Cash account" : recipient)
                            LabeledContent("Fees", value: scene.money(0))
                            LabeledContent("Available cash", value: scene.money(scene.balance))
                            if let error = store.error { Text(error).font(.footnote).foregroundStyle(.red) }
                            Spacer()
                            Button("Confirm transfer") {
                                guard valid, let value = parsed else { return }
                                if store.emit(kind: incoming ? .deposit : .payment, amount: value, detail: recipient.isEmpty ? "Cash transfer" : recipient, sceneID: sceneID) != nil { completed = true }
                            }.buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity).disabled(!valid)
                        }.padding(24)
                    } else {
                        Form {
                            Section("Transfer") { TextField("Amount", text: $amount).keyboardType(.decimalPad); TextField(incoming ? "From" : "To", text: $recipient).autocorrectionDisabled(); LabeledContent("Available cash", value: scene.money(scene.balance)) }
                            Section { Button("Review transfer") { reviewing = true }.disabled(!valid) }
                        }
                    }
                } else { ContentUnavailableView("Portfolio unavailable", systemImage: "banknote") }
            }
            .navigationTitle(incoming ? "Add cash" : "Send cash").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { if !completed { Button(reviewing ? "Back" : "Cancel") { if reviewing { reviewing = false } else { dismiss() } } } } }
            .tint(palette.accent).onAppear { recipient = initialRecipient }
        }
    }
}

private struct PortfolioScanPage: View {
    @Environment(\.dismiss) private var dismiss
    let sceneID: UUID
    @State private var imageItem: PhotosPickerItem?
    @State private var decoded = ""
    @State private var error: String?
    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Image(systemName: "viewfinder").font(.system(size: 126, weight: .ultraLight)).foregroundStyle(Color(portfolioHex: 0x0052FF)).padding(.top, 45)
                Text("Scan a QR code").font(.system(size: 27, weight: .semibold))
                Text("Choose an image containing a QR code.").font(.system(size: 15)).foregroundStyle(.secondary)
                PhotosPicker(selection: $imageItem, matching: .images) { Label("Choose QR image", systemImage: "photo").frame(minHeight: 44) }.buttonStyle(.borderedProminent)
                if let error { Text(error).font(.footnote).foregroundStyle(.red).padding(.horizontal, 24) }
                if !decoded.isEmpty {
                    Text(decoded).font(.system(.footnote, design: .monospaced)).textSelection(.enabled).lineLimit(6).padding(18).frame(maxWidth: .infinity).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 15)).padding(.horizontal, 24)
                    if MarketValidation.address(decoded) {
                        NavigationLink("Use for transfer") { PortfolioTransferPage(sceneID: sceneID, kind: .send, initialRecipient: decoded) }.buttonStyle(.borderedProminent)
                    } else { Text("This code does not contain a supported public address.").font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 24) }
                }
                Spacer()
            }
            .navigationTitle("Scan").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .onChange(of: imageItem) { _, item in
                Task {
                    decoded = ""; error = nil
                    guard let data = try? await item?.loadTransferable(type: Data.self), let bitmap = UIImage(data: data), let image = CIImage(image: bitmap) else { error = "Unable to open this image."; return }
                    let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
                    let result = detector?.features(in: image).compactMap { ($0 as? CIQRCodeFeature)?.messageString }.first
                    guard let result, !result.isEmpty else { error = "No QR code found. Choose a clearer image."; return }
                    decoded = result
                }
            }
        }
    }
}

private struct PortfolioTransferPage: View {
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    let sceneID: UUID
    let kind: WalletTransferKind
    var initialRecipient = ""
    @State private var assetID: UUID?
    @State private var quantity = "0.01"
    @State private var address = ""
    @State private var reviewing = false
    @State private var result: WalletTransaction?
    private var profile: PortfolioProfile { store.portfolioProfile(for: sceneID) }
    private var scene: StudioScene? { store.scenes.first { $0.id == sceneID } }
    private var position: MarketPosition? { profile.positions.first { $0.id == assetID && $0.kind == .crypto } }
    private var palette: PortfolioPalette { PortfolioPalette(profile.theme) }
    private var parsed: Double? { Simulation.parseAmount(quantity) }
    private var valid: Bool {
        guard let position, let quantity = parsed else { return false }
        return MarketValidation.quantity(quantity, allowZero: false) && MarketValidation.address(address) &&
            Simulation.validAmount(quantity * position.price) &&
            (kind == .send ? quantity <= position.units : (position.units + quantity) * position.price <= 1_000_000_000)
    }
    var body: some View {
        NavigationStack {
            Group {
                if let result, let scene { confirmation(result, scene: scene) }
                else if let position, let scene {
                    if reviewing { review(position, scene: scene) }
                    else { entry(position, scene: scene) }
                } else {
                    List(profile.positions.filter { $0.kind == .crypto }) { token in
                        Button {
                            assetID = token.id
                            if initialRecipient.isEmpty { address = kind == .receive ? PortfolioTransferMetadata.address(for: token.symbol) : "" }
                            else { address = initialRecipient }
                        } label: {
                            HStack(spacing: 14) { PortfolioAssetIcon(position: token).frame(width: 42, height: 42); VStack(alignment: .leading, spacing: 5) { Text(token.name).font(.system(size: 16, weight: .medium)); Text(token.symbol).font(.system(size: 13)).foregroundStyle(palette.secondary) }; Spacer(); Text(PortfolioFormatting.quantity(token.units)).monospacedDigit() }.frame(minHeight: 58).foregroundStyle(palette.ink)
                        }.listRowBackground(palette.background).accessibilityIdentifier("portfolio-transfer-asset-\(token.symbol)")
                    }.listStyle(.plain).scrollContentBackground(.hidden).background(palette.background)
                }
            }
            .navigationTitle(result == nil ? "\(kind == .send ? "Send" : "Receive") \(position?.symbol ?? "crypto")" : "Transfer complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { if result == nil { Button(reviewing ? "Back" : "Cancel") { if reviewing { reviewing = false } else { dismiss() } } } } }
            .background(palette.background.ignoresSafeArea()).foregroundStyle(palette.ink).tint(palette.accent)
            .preferredColorScheme(palette.isDark ? .dark : .light)
        }
    }
    private func entry(_ position: MarketPosition, scene: StudioScene) -> some View {
        ScrollView {
            VStack(spacing: 22) {
                PortfolioAssetIcon(position: position).frame(width: 49, height: 49).padding(.top, 20)
                Text(position.name).font(.system(size: 21, weight: .medium))
                if kind == .receive {
                    PortfolioQRCode(value: address).frame(width: 178, height: 178).padding(12).background(.white, in: RoundedRectangle(cornerRadius: 18))
                    HStack(spacing: 16) { Button { UIPasteboard.general.string = address } label: { Label("Copy", systemImage: "doc.on.doc").frame(minHeight: 44) }; ShareLink(item: address) { Label("Share", systemImage: "square.and.arrow.up").frame(minHeight: 44) } }.font(.system(size: 14, weight: .medium))
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text(kind == .send ? "To" : "Receiving address").font(.system(size: 14, weight: .medium))
                    TextField("Public address", text: $address, axis: .vertical).font(.system(.footnote, design: .monospaced)).textInputAutocapitalization(.never).autocorrectionDisabled().lineLimit(2...3).padding(14).background(palette.surface, in: RoundedRectangle(cornerRadius: 12)).accessibilityIdentifier("portfolio-transfer-address")
                    HStack { Text("Network").foregroundStyle(palette.secondary); Spacer(); Text(position.transferNetwork) }.font(.system(size: 14)).padding(.top, 5)
                }
                HStack(spacing: 10) { TextField("Quantity", text: $quantity).keyboardType(.decimalPad).font(.system(size: 32, weight: .medium)).accessibilityIdentifier("portfolio-transfer-quantity"); Text(position.symbol).font(.system(size: 18, weight: .medium)) }.padding(16).background(palette.surface, in: RoundedRectangle(cornerRadius: 12))
                Text("\(scene.money((parsed ?? 0) * position.price)) · \(PortfolioFormatting.quantity(position.units)) \(position.symbol) available").font(.system(size: 13)).foregroundStyle(palette.secondary)
                if !address.isEmpty && !MarketValidation.address(address) { Text("Enter a public address with 16–120 letters or numbers.").font(.footnote).foregroundStyle(palette.loss) }
                if kind == .send, let parsed, parsed > position.units { Text("There are not enough available \(position.symbol) tokens to send this quantity.").font(.footnote).foregroundStyle(palette.loss) }
                actionButton(kind == .send ? "Review send" : "Review receive", disabled: !valid) { reviewing = true }.accessibilityIdentifier("portfolio-transfer-review")
            }.padding(24)
        }
    }
    private func review(_ position: MarketPosition, scene: StudioScene) -> some View {
        VStack(alignment: .leading, spacing: 25) {
            Text("Review transfer").font(.system(size: 29, weight: .medium)).padding(.top, 25)
            LabeledContent("Asset", value: position.name)
            LabeledContent("Quantity", value: "\(PortfolioFormatting.quantity(parsed ?? 0)) \(position.symbol)")
            LabeledContent("Value", value: scene.money((parsed ?? 0) * position.price))
            LabeledContent("Network", value: position.transferNetwork)
            VStack(alignment: .leading, spacing: 8) { Text(kind == .send ? "To" : "Receiving address").foregroundStyle(palette.secondary); Text(address).font(.system(.footnote, design: .monospaced)).textSelection(.enabled) }
            if let error = store.error { Text(error).font(.footnote).foregroundStyle(palette.loss) }
            Spacer()
            actionButton(kind == .send ? "Confirm send" : "Confirm receive", disabled: !valid) {
                guard let amount = parsed else { return }
                result = store.executePortfolioTransfer(sceneID: sceneID, assetID: position.id, kind: kind, quantity: amount, address: address)
            }.accessibilityIdentifier("portfolio-transfer-confirm")
        }.padding(24)
    }
    private func confirmation(_ transaction: WalletTransaction, scene: StudioScene) -> some View {
        VStack(spacing: 23) {
            Spacer()
            Image(systemName: "checkmark.circle.fill").font(.system(size: 83)).foregroundStyle(palette.accent)
            Text(transaction.kind == .send ? "Crypto sent" : "Crypto received").font(.system(size: 29, weight: .medium))
            Text("\(PortfolioFormatting.quantity(transaction.quantity)) \(transaction.symbol)").font(.system(size: 25)).monospacedDigit()
            Text(scene.money(transaction.value)).font(.system(size: 17)).foregroundStyle(palette.secondary)
            Spacer()
            actionButton("Done", disabled: false) { dismiss() }.accessibilityIdentifier("portfolio-transfer-done")
        }.padding(24).frame(maxWidth: .infinity)
    }
    private func actionButton(_ title: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).font(.system(size: 16, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 52).background(palette.accent, in: Capsule()).foregroundStyle(palette.isDark ? .black : palette.background) }.buttonStyle(.plain).disabled(disabled).opacity(disabled ? 0.4 : 1)
    }
}

private enum PortfolioTransferMetadata {
    static func network(for symbol: String) -> String {
        switch symbol.uppercased() { case "BTC": return "Bitcoin"; case "ETH", "USDC", "USDT": return "Ethereum"; case "SOL": return "Solana"; default: return symbol.uppercased() }
    }
    static func address(for symbol: String) -> String {
        switch network(for: symbol) { case "Bitcoin": return "1111111111111111111114oLvT2"; case "Solana": return "11111111111111111111111111111111"; default: return "0x0000000000000000000000000000000000000000" }
    }
}

private struct PortfolioQRCode: View {
    let value: String
    private var bitmap: UIImage? {
        guard let generator = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        generator.setValue(Data(value.utf8), forKey: "inputMessage")
        generator.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = generator.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)), let bitmap = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: bitmap)
    }
    var body: some View {
        if let bitmap { Image(uiImage: bitmap).interpolation(.none).resizable().scaledToFit().accessibilityLabel("Receiving address QR code") }
        else { Image(systemName: "qrcode").resizable().scaledToFit().accessibilityLabel("QR code unavailable") }
    }
}

private struct PortfolioAssetDetail: View {
    @EnvironmentObject private var store: StudioStore
    let sceneID: UUID
    let assetID: UUID
    @State private var range: PortfolioRange = .day
    @State private var trade: MarketTradeSide?
    private var profile: PortfolioProfile { store.portfolioProfile(for: sceneID) }
    private var palette: PortfolioPalette { PortfolioPalette(profile.theme) }
    private var position: MarketPosition? { profile.positions.first { $0.id == assetID } }
    var body: some View {
        Group {
            if let scene = store.scenes.first(where: { $0.id == sceneID }), let position {
                ScrollView {
                    VStack(alignment: .leading, spacing: 25) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack { PortfolioAssetIcon(position: position).frame(width: 38, height: 38); Text(position.name).font(.system(size: 25, weight: .medium)) }
                            Text(scene.money(position.price)).font(.system(size: 39, weight: .medium)).monospacedDigit()
                            Text("\(position.changePercent >= 0 ? "+" : "")\(PortfolioFormatting.percent(position.changePercent)) \(range.changeLabel)")
                                .font(.system(size: 14, weight: .medium)).foregroundStyle(position.changePercent >= 0 ? palette.gain : palette.loss)
                        }
                        PortfolioTrend(values: position.chart, range: range, color: position.changePercent >= 0 ? palette.gain : palette.loss, fill: profile.theme == .coinbase).frame(height: 210)
                        HStack(spacing: 0) {
                            ForEach(PortfolioRange.options(for: profile.theme)) { option in
                                Button { range = option } label: {
                                    Text(option.title).font(.system(size: 12, weight: .semibold)).padding(.horizontal, 5).frame(minHeight: 28)
                                        .foregroundStyle(range == option && profile.theme == .robinhood ? .black : range == option ? palette.accent : profile.theme == .robinhood ? palette.accent : palette.secondary)
                                        .background(range == option ? profile.theme == .robinhood ? palette.accent : palette.surface : .clear, in: RoundedRectangle(cornerRadius: 7))
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                }.buttonStyle(.plain)
                            }
                        }
                        Text(profile.theme == .robinhood ? "Your position" : "Your balance").font(.system(size: 23, weight: .semibold))
                        VStack(spacing: 18) {
                            detailRow("Market value", value: scene.money(position.value))
                            detailRow(position.kind == .stock ? "Shares" : "Units", value: "\(PortfolioFormatting.quantity(position.units)) \(position.symbol)")
                            detailRow("Average cost", value: scene.money(position.averageCost))
                            detailRow("Total return", value: scene.money(position.unrealizedGain), color: position.unrealizedGain >= 0 ? palette.gain : palette.loss)
                            detailRow("Buying power", value: scene.money(scene.balance))
                        }.padding(20).background(palette.surface, in: RoundedRectangle(cornerRadius: 16))
                        NavigationLink { PortfolioActivityPage(sceneID: sceneID, assetID: assetID) } label: { HStack { Text("Activity").font(.system(size: 18, weight: .medium)); Spacer(); Image(systemName: "chevron.right").font(.caption) }.frame(minHeight: 48) }.buttonStyle(.plain)
                    }.padding(24)
                }
                .safeAreaInset(edge: .bottom) {
                    HStack(spacing: 14) {
                        tradeButton("Sell", side: .sell, outlined: true)
                        tradeButton("Buy", side: .buy, outlined: false)
                    }.padding(.horizontal, 24).padding(.vertical, 12).background(palette.background)
                }
            } else { ContentUnavailableView("Asset unavailable", systemImage: "chart.line.uptrend.xyaxis") }
        }
        .background(palette.background.ignoresSafeArea()).foregroundStyle(palette.ink)
        .navigationTitle(position?.symbol ?? "Asset").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
        .sheet(isPresented: Binding(get: { trade != nil }, set: { if !$0 { trade = nil } })) {
            if let trade { PortfolioTradePage(sceneID: sceneID, assetID: assetID, side: trade) }
        }
    }
    private func detailRow(_ title: String, value: String, color: Color? = nil) -> some View {
        HStack { Text(title).foregroundStyle(palette.secondary); Spacer(); Text(value).foregroundStyle(color ?? palette.ink).monospacedDigit() }.font(.system(size: 15))
    }
    private func tradeButton(_ title: String, side: MarketTradeSide, outlined: Bool) -> some View {
        Button { trade = side } label: {
            Text(title).font(.system(size: 16, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 50)
                .foregroundStyle(outlined ? palette.accent : profile.theme == .robinhood ? .black : palette.background)
                .background(outlined ? palette.background : palette.accent, in: Capsule())
                .overlay(Capsule().stroke(palette.accent, lineWidth: outlined ? 1 : 0))
        }.buttonStyle(.plain).accessibilityIdentifier("portfolio-\(side.rawValue)")
    }
}

private struct PortfolioTradePage: View {
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    let sceneID: UUID
    let assetID: UUID
    let side: MarketTradeSide
    @State private var amount = "100"
    @State private var enteredUnits = false
    @State private var reviewing = false
    @State private var completed = false
    @State private var completedUnits = 0.0
    @State private var completedTotal = 0.0
    private var profile: PortfolioProfile { store.portfolioProfile(for: sceneID) }
    private var position: MarketPosition? { profile.positions.first { $0.id == assetID } }
    private var scene: StudioScene? { store.scenes.first { $0.id == sceneID } }
    private var palette: PortfolioPalette { PortfolioPalette(profile.theme) }
    private var units: Double {
        guard let amount = Simulation.parseAmount(amount), let position else { return 0 }
        return enteredUnits ? amount : amount / position.price
    }
    private var total: Double { units * (position?.price ?? 0) }
    private var valid: Bool {
        guard let position, let scene else { return false }
        return units.isFinite && units > 0 && total.isFinite && Simulation.validAmount(total) &&
            (side == .buy ? total <= scene.balance : units <= position.units)
    }
    var body: some View {
        NavigationStack {
            Group {
                if let position, let scene {
                    if completed { confirmation(position, scene: scene) }
                    else if reviewing { review(position, scene: scene) }
                    else { entry(position, scene: scene) }
                } else { ContentUnavailableView("Asset unavailable", systemImage: "chart.line.uptrend.xyaxis") }
            }
            .background(palette.background.ignoresSafeArea()).foregroundStyle(palette.ink)
            .navigationTitle(completed && profile.theme == .coinbase ? "" : completed ? "Order complete" : "\(side.rawValue.capitalized) \(position?.symbol ?? "asset")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(reviewing && !completed ? "Back" : "Cancel") { if reviewing && !completed { reviewing = false } else { dismiss() } }.opacity(completed ? 0 : 1).disabled(completed) }
            }
            .preferredColorScheme(palette.isDark ? .dark : .light).tint(palette.accent)
        }
    }
    private func entry(_ position: MarketPosition, scene: StudioScene) -> some View {
        VStack(spacing: 24) {
            PortfolioAssetIcon(position: position).frame(width: 48, height: 48).padding(.top, 30)
            Text(position.name).font(.system(size: 22, weight: .medium))
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(enteredUnits ? "" : scene.currency == "GBP" ? "£" : scene.currency == "EUR" ? "€" : "$ ").font(.system(size: 37))
                TextField("Amount", text: $amount).keyboardType(.decimalPad).font(.system(size: 49, weight: .medium)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("portfolio-trade-amount")
            }.padding(.horizontal, 50)
            Picker("Enter amount in", selection: $enteredUnits) { Text(scene.currency).tag(false); Text(position.kind == .stock ? "Shares" : position.symbol).tag(true) }.pickerStyle(.segmented).padding(.horizontal, 60)
            Text(enteredUnits ? scene.money(total) : "\(PortfolioFormatting.quantity(units)) \(position.symbol)").foregroundStyle(palette.secondary)
            Text(side == .buy ? "\(scene.money(scene.balance)) buying power" : "\(PortfolioFormatting.quantity(position.units)) \(position.symbol) available").font(.system(size: 14)).foregroundStyle(palette.secondary)
            if !amount.isEmpty && !valid { Text("Enter an amount within your available \(side == .buy ? "buying power" : "holdings").").font(.footnote).foregroundStyle(palette.loss).multilineTextAlignment(.center).padding(.horizontal, 24) }
            Spacer()
            primaryButton("Review order", disabled: !valid) { reviewing = true }.accessibilityIdentifier("portfolio-trade-review")
        }.padding(.bottom, 24)
    }
    private func review(_ position: MarketPosition, scene: StudioScene) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Review your order").font(.system(size: 30, weight: .medium)).padding(.top, 24)
            Text("\(side.rawValue.capitalized) \(PortfolioFormatting.quantity(units)) \(position.symbol)").font(.system(size: 21, weight: .medium))
            VStack(spacing: 22) {
                tradeRow("Asset", value: position.name)
                tradeRow("Order type", value: "Market \(side.rawValue)")
                tradeRow("Price", value: scene.money(position.price))
                tradeRow("Quantity", value: "\(PortfolioFormatting.quantity(units)) \(position.symbol)")
                tradeRow("Fees", value: scene.money(0))
                Divider()
                tradeRow("Total", value: scene.money(total))
            }
            if let error = store.error { Text(error).font(.footnote).foregroundStyle(palette.loss) }
            Spacer()
            primaryButton("Confirm \(side.rawValue)", disabled: !valid) {
                let quantity = units
                let cost = total
                if store.executeMarketTrade(sceneID: sceneID, assetID: assetID, side: side, units: quantity) != nil {
                    completedUnits = quantity; completedTotal = cost; completed = true
                }
            }.padding(.horizontal, -24).accessibilityIdentifier("portfolio-trade-confirm")
        }.padding(24)
    }
    @ViewBuilder private func confirmation(_ position: MarketPosition, scene: StudioScene) -> some View {
        if profile.theme == .coinbase {
            VStack(spacing: 24) {
                Spacer()
                CoinbaseSuccessMark().frame(width: 140, height: 140).padding(.bottom, 24)
                Text("Trade successful!").font(.system(size: 25, weight: .semibold))
                Text("\(side == .buy ? "You got" : "You sold") \(PortfolioFormatting.quantity(completedUnits)) \(position.symbol)")
                    .font(.system(size: 19)).foregroundStyle(palette.secondary).multilineTextAlignment(.center)
                Text(scene.money(completedTotal)).font(.system(size: 16)).foregroundStyle(palette.secondary).monospacedDigit()
                Spacer()
                primaryButton("Done", disabled: false) { dismiss() }.accessibilityIdentifier("portfolio-trade-done")
            }.padding(.bottom, 24).frame(maxWidth: .infinity)
        } else {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "checkmark").font(.system(size: 42, weight: .medium)).frame(width: 86, height: 86).background(palette.accent, in: Circle()).foregroundStyle(profile.theme == .robinhood ? .black : palette.background)
            Text(side == .buy ? "Purchase complete" : "Sale complete").font(.system(size: 29, weight: .medium))
            Text("\(PortfolioFormatting.quantity(completedUnits)) \(position.symbol)\n\(scene.money(completedTotal))").font(.system(size: 20)).multilineTextAlignment(.center)
            Text("Your portfolio and activity have been updated.").font(.system(size: 15)).foregroundStyle(palette.secondary).multilineTextAlignment(.center).padding(.horizontal, 28)
            Spacer()
            primaryButton("Done", disabled: false) { dismiss() }.accessibilityIdentifier("portfolio-trade-done")
        }.padding(.bottom, 24)
        }
    }
    private func tradeRow(_ title: String, value: String) -> some View { HStack { Text(title).foregroundStyle(palette.secondary); Spacer(); Text(value).multilineTextAlignment(.trailing).monospacedDigit() }.font(.system(size: 15)) }
    private func primaryButton(_ title: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).font(.system(size: 16, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 52).background(palette.accent, in: Capsule()).foregroundStyle(profile.theme == .robinhood ? .black : palette.background) }.buttonStyle(.plain).padding(.horizontal, 24).disabled(disabled).opacity(disabled ? 0.45 : 1)
    }
}

private struct CoinbaseSuccessMark: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Circle().fill(Color(portfolioHex: 0x244BEF))
                Image(systemName: "checkmark").font(.system(size: geometry.size.width * 0.36, weight: .medium)).foregroundStyle(.white)
                PortfolioPolygon(points: [.init(x: 0.5, y: 0), .init(x: 0.62, y: 0.38), .init(x: 1, y: 0.5), .init(x: 0.62, y: 0.62), .init(x: 0.5, y: 1), .init(x: 0.38, y: 0.62), .init(x: 0, y: 0.5), .init(x: 0.38, y: 0.38)])
                    .fill(Color(portfolioHex: 0xF9DE51)).frame(width: geometry.size.width * 0.35, height: geometry.size.height * 0.35).offset(x: -geometry.size.width * 0.39, y: -geometry.size.height * 0.39)
                PortfolioPolygon(points: [.init(x: 0.5, y: 0), .init(x: 0.6, y: 0.4), .init(x: 1, y: 0.5), .init(x: 0.6, y: 0.6), .init(x: 0.5, y: 1), .init(x: 0.4, y: 0.6), .init(x: 0, y: 0.5), .init(x: 0.4, y: 0.4)])
                    .fill(Color(portfolioHex: 0x0A0B0D)).frame(width: geometry.size.width * 0.35, height: geometry.size.height * 0.35).offset(x: -geometry.size.width * 0.29, y: -geometry.size.height * 0.31)
            }
        }.accessibilityLabel("Trade complete")
    }
}

private struct PortfolioActivityPage: View {
    @EnvironmentObject private var store: StudioStore
    let sceneID: UUID
    var assetID: UUID? = nil
    var embedded = false
    @State private var search = ""
    private var profile: PortfolioProfile { store.portfolioProfile(for: sceneID) }
    private var palette: PortfolioPalette { PortfolioPalette(profile.theme) }
    private var transactions: [MarketTransaction] {
        profile.transactions.filter { (assetID == nil || $0.assetID == assetID) && (search.isEmpty || $0.symbol.localizedCaseInsensitiveContains(search) || $0.side.rawValue.localizedCaseInsensitiveContains(search)) }.sorted { $0.date > $1.date }
    }
    private var cashTransfers: [SceneEvent] {
        guard assetID == nil else { return [] }
        return store.events.filter { $0.sceneID == sceneID && ($0.kind == .deposit || $0.kind == .payment) && (search.isEmpty || $0.detail.localizedCaseInsensitiveContains(search) || $0.title.localizedCaseInsensitiveContains(search)) }.sorted { $0.date > $1.date }
    }
    private var cryptoTransfers: [WalletTransaction] {
        profile.transfers.filter { (assetID == nil || $0.assetID == assetID) && (search.isEmpty || $0.symbol.localizedCaseInsensitiveContains(search) || $0.kind.title.localizedCaseInsensitiveContains(search) || $0.address.localizedCaseInsensitiveContains(search)) }.sorted { $0.date > $1.date }
    }
    var body: some View {
        Group {
            if let scene = store.scenes.first(where: { $0.id == sceneID }) {
                VStack(spacing: 0) {
                    HStack { Image(systemName: "magnifyingglass").foregroundStyle(palette.secondary); TextField("Search activity", text: $search).autocorrectionDisabled() }.padding(.horizontal, 16).frame(minHeight: 48).background(palette.surface, in: RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 24).padding(.vertical, 12)
                    List {
                    if transactions.isEmpty && cashTransfers.isEmpty && cryptoTransfers.isEmpty { ContentUnavailableView(search.isEmpty ? "No activity yet" : "No matching activity", systemImage: "clock", description: Text("Completed orders and transfers appear here.")).listRowBackground(palette.background) }
                    ForEach(transactions) { transaction in
                        NavigationLink {
                            PortfolioTransactionDetail(transaction: transaction, scene: scene, theme: profile.theme)
                        } label: {
                            HStack(spacing: 13) {
                                Image(systemName: transaction.side == .buy ? "arrow.down.left" : "arrow.up.right").frame(width: 40, height: 40).background(palette.surface, in: Circle())
                                VStack(alignment: .leading, spacing: 5) { Text("\(transaction.symbol) \(transaction.side.rawValue)").font(.system(size: 16, weight: .medium)); Text(transaction.date.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 12)).foregroundStyle(palette.secondary) }
                                Spacer()
                                Text(scene.money(transaction.total)).font(.system(size: 15)).monospacedDigit()
                            }.frame(minHeight: 62)
                        }.listRowBackground(palette.background).accessibilityIdentifier("portfolio-transaction-\(transaction.id.uuidString)")
                    }
                    if !cryptoTransfers.isEmpty {
                        Section("Crypto transfers") {
                            ForEach(cryptoTransfers) { transfer in
                                NavigationLink {
                                    List {
                                        LabeledContent("Status", value: "Completed")
                                        LabeledContent("Quantity", value: "\(PortfolioFormatting.quantity(transfer.quantity)) \(transfer.symbol)")
                                        LabeledContent("Value", value: scene.money(transfer.value))
                                        LabeledContent("Network", value: transfer.network)
                                        LabeledContent("Date", value: transfer.date.formatted(date: .abbreviated, time: .shortened))
                                        Section(transfer.kind == .send ? "To" : "Receiving address") { Text(transfer.address).font(.system(.footnote, design: .monospaced)).textSelection(.enabled) }
                                    }.navigationTitle("\(transfer.symbol) \(transfer.kind.title.lowercased())").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
                                } label: {
                                    HStack(spacing: 13) {
                                        Image(systemName: transfer.kind == .send ? "arrow.up.right" : "arrow.down.left").frame(width: 40, height: 40).background(palette.surface, in: Circle())
                                        VStack(alignment: .leading, spacing: 5) { Text("\(transfer.symbol) \(transfer.kind.title.lowercased())").font(.system(size: 16, weight: .medium)); Text(transfer.date.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 12)).foregroundStyle(palette.secondary) }
                                        Spacer()
                                        Text("\(PortfolioFormatting.quantity(transfer.quantity)) \(transfer.symbol)").font(.system(size: 14)).monospacedDigit()
                                    }.frame(minHeight: 62)
                                }.listRowBackground(palette.background).accessibilityIdentifier("portfolio-transfer-\(transfer.id.uuidString)")
                            }
                        }
                    }
                    if !cashTransfers.isEmpty {
                        Section("Cash transfers") {
                            ForEach(cashTransfers) { transfer in
                                NavigationLink {
                                    List {
                                        LabeledContent("Status", value: "Completed")
                                        LabeledContent("Amount", value: scene.money(transfer.amount))
                                        LabeledContent(transfer.kind == .deposit ? "From" : "To", value: transfer.detail)
                                        LabeledContent("Date", value: transfer.date.formatted(date: .abbreviated, time: .shortened))
                                    }.navigationTitle(transfer.title).navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
                                } label: {
                                    HStack(spacing: 13) {
                                        Image(systemName: transfer.kind.symbol).frame(width: 40, height: 40).background(palette.surface, in: Circle())
                                        VStack(alignment: .leading, spacing: 5) { Text(transfer.detail.isEmpty ? transfer.title : transfer.detail).font(.system(size: 16, weight: .medium)); Text(transfer.date.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 12)).foregroundStyle(palette.secondary) }
                                        Spacer()
                                        Text(scene.money(transfer.kind.isOutflow ? -transfer.amount : transfer.amount)).font(.system(size: 15)).monospacedDigit()
                                    }.frame(minHeight: 62)
                                }.listRowBackground(palette.background)
                            }
                        }
                    }
                    }.listStyle(.plain).scrollContentBackground(.hidden).background(palette.background)
                }
            } else { ContentUnavailableView("Portfolio unavailable", systemImage: "clock") }
        }
        .foregroundStyle(palette.ink).navigationTitle("Activity").navigationBarTitleDisplayMode(.inline).toolbar(embedded ? .hidden : .visible, for: .navigationBar).accessibilityIdentifier("portfolio-activity")
    }
}

private struct PortfolioTransactionDetail: View {
    let transaction: MarketTransaction
    let scene: StudioScene
    let theme: PortfolioTheme
    var body: some View {
        List {
            Section {
                Text("\(transaction.symbol) \(transaction.side.rawValue)").font(.title2).padding(.vertical, 8)
                LabeledContent("Status", value: "Completed")
                LabeledContent("Date", value: transaction.date.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Quantity", value: "\(PortfolioFormatting.quantity(transaction.units)) \(transaction.symbol)")
                LabeledContent("Price", value: scene.money(transaction.price))
                LabeledContent("Total", value: scene.money(transaction.total))
                LabeledContent("Cash impact", value: scene.money(transaction.side == .buy ? -transaction.total : transaction.total))
            }
            Section { Text("Order ID").font(.caption).foregroundStyle(.secondary); Text(transaction.id.uuidString).font(.caption).textSelection(.enabled) }
        }.navigationTitle("Order details").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
    }
}

private struct PortfolioEditor: View {
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    let sceneID: UUID
    @State private var cash = ""
    @State private var change = ""
    @State private var chart = ""
    @State private var position: MarketPosition?
    @State private var showAdd = false
    private var profile: PortfolioProfile { store.portfolioProfile(for: sceneID) }
    private var parsedChart: [Double]? {
        let values = chart.split(separator: ",", omittingEmptySubsequences: false).compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        guard values.count == chart.split(separator: ",", omittingEmptySubsequences: false).count, (2...120).contains(values.count), values.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else { return nil }
        return values
    }
    private var valid: Bool { Simulation.parseAmount(cash).map { (0...1_000_000_000).contains($0) } == true && Double(change).map { $0.isFinite && (-100...10000).contains($0) } == true && parsedChart != nil }
    var body: some View {
        NavigationStack {
            Form {
                Section("Portfolio") {
                    TextField("Cash balance", text: $cash).keyboardType(.decimalPad)
                    TextField("Daily change (%)", text: $change).keyboardType(.numbersAndPunctuation)
                }
                Section {
                    ForEach(profile.positions) { holding in
                        Button { position = holding } label: { HStack { Text(holding.symbol); Spacer(); Text(PortfolioFormatting.quantity(holding.units)).foregroundStyle(.secondary) }.foregroundStyle(.primary) }
                            .deleteDisabled(profile.transactions.contains { $0.assetID == holding.id } || profile.transfers.contains { $0.assetID == holding.id })
                    }
                    .onDelete { offsets in
                        var updated = profile
                        updated.positions.remove(atOffsets: offsets)
                        _ = store.updatePortfolioProfile(updated)
                    }
                    Button("Add asset") { showAdd = true }.disabled(profile.positions.count >= 100)
                } header: { Text("Holdings") } footer: { Text("Assets with completed orders or transfers remain available so their activity can be viewed. You can edit their quantity.") }
                Section {
                    TextField("Values separated by commas", text: $chart, axis: .vertical).font(.system(.body, design: .monospaced)).lineLimit(3...8).autocorrectionDisabled()
                } header: { Text("Chart shape") } footer: { Text("Enter 2–120 values from 0 to 1. These values control the saved chart.") }
                if let error = store.error { Section { Text(error).foregroundStyle(.red).font(.footnote) } }
            }
            .navigationTitle("Portfolio settings").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") {
                    guard valid, let balance = Simulation.parseAmount(cash), let percent = Double(change), let points = parsedChart else { return }
                    var updated = profile; updated.dailyChange = percent; updated.chart = points
                    if store.updatePortfolioProfile(updated, cashBalance: balance) { dismiss() }
                }.disabled(!valid) }
            }
            .onAppear { cash = (store.scenes.first { $0.id == sceneID }?.balance ?? 0).formatted(.number.grouping(.never)); change = String(profile.dailyChange); chart = profile.chart.map { String($0) }.joined(separator: ", ") }
            .sheet(item: $position) { PortfolioPositionEditor(sceneID: sceneID, existing: $0) }
            .sheet(isPresented: $showAdd) { PortfolioPositionEditor(sceneID: sceneID) }
        }
    }
}

private struct PortfolioPositionEditor: View {
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    let sceneID: UUID
    var existing: MarketPosition? = nil
    @State private var name = ""
    @State private var symbol = ""
    @State private var kind: MarketAssetKind = .stock
    @State private var units = ""
    @State private var price = ""
    @State private var cost = ""
    @State private var change = "0"
    private var candidate: MarketPosition? {
        guard let amount = Simulation.parseAmount(units), let quote = Simulation.parseAmount(price), let average = Simulation.parseAmount(cost), let percent = Double(change) else { return nil }
        let value = MarketPosition(id: existing?.id ?? UUID(), symbol: symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(), name: name.trimmingCharacters(in: .whitespacesAndNewlines), kind: kind, units: amount, price: quote, averageCost: average, changePercent: percent, chart: existing?.chart ?? [0.18,0.28,0.24,0.43,0.38,0.5,0.48,0.62,0.74,0.69,0.82])
        return value.isValid ? value : nil
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Asset") { TextField("Name", text: $name); TextField("Symbol", text: $symbol).textInputAutocapitalization(.characters).autocorrectionDisabled(); Picker("Type", selection: $kind) { Text("Stock / ETF").tag(MarketAssetKind.stock); Text("Crypto").tag(MarketAssetKind.crypto) } }
                Section("Position") { TextField("Units held", text: $units).keyboardType(.decimalPad); TextField("Current price", text: $price).keyboardType(.decimalPad); TextField("Average cost", text: $cost).keyboardType(.decimalPad); TextField("Daily change (%)", text: $change).keyboardType(.numbersAndPunctuation) }
                if let error = store.error { Section { Text(error).foregroundStyle(.red).font(.footnote) } }
            }
            .navigationTitle(existing == nil ? "Add asset" : "Edit asset").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") {
                    guard let candidate else { return }
                    var updated = store.portfolioProfile(for: sceneID)
                    if let index = updated.positions.firstIndex(where: { $0.id == candidate.id }) { updated.positions[index] = candidate } else { updated.positions.append(candidate) }
                    if store.updatePortfolioProfile(updated) { dismiss() }
                }.disabled(candidate == nil) }
            }
            .onAppear { guard let existing else { return }; name = existing.name; symbol = existing.symbol; kind = existing.kind; units = existing.units.formatted(.number.grouping(.never)); price = existing.price.formatted(.number.grouping(.never)); cost = existing.averageCost.formatted(.number.grouping(.never)); change = String(existing.changePercent) }
        }
    }
}

private extension Color {
    init(portfolioHex: UInt32) { self.init(red: Double((portfolioHex >> 16) & 255) / 255, green: Double((portfolioHex >> 8) & 255) / 255, blue: Double(portfolioHex & 255) / 255) }
}
