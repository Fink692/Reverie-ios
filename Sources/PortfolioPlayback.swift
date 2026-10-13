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
    @State private var wealthAccount: WealthsimpleAccount = .holdings

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
                case .coinbaseRewards: CoinbaseRewardsPage(sceneID: sceneID)
                case .coinbaseWallet: coinbaseUnavailableFeature(.wallet)
                case .coinbaseAdvanced: CoinbaseAdvancedTradePage(sceneID: sceneID)
                case .security: PortfolioSecurityPage(sceneID: sceneID)
                case .cashAccount: PortfolioCashAccountPage(sceneID: sceneID)
                case .cryptoAccount: PortfolioCryptoAccountPage(sceneID: sceneID)
                }
            }
        }
        .accessibilityIdentifier("portfolio-playback")
    }

    @ViewBuilder private var header: some View {
        if theme == .wealthsimple {
            Button { modal = .menu } label: {
                HStack(spacing: 5) {
                    Text(tab == .home ? wealthAccount.title : tab == .assets ? "Discover" : tab == .activity ? "Activity" : "Move")
                }
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
                case .wealthsimple:
                    switch wealthAccount {
                    case .holdings: wealthsimpleHome(scene)
                    case .chequing: WealthsimpleChequingContent(sceneID: sceneID)
                    case .crypto: WealthsimpleCryptoContent(sceneID: sceneID)
                    case .visa: WealthsimpleVisaContent(sceneID: sceneID)
                    case .security: PortfolioSecurityContent(sceneID: sceneID)
                    }
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
                        Button { modal = .cryptoAccount } label: { Image(systemName: "info.circle").font(.system(size: 21)).foregroundStyle(palette.secondary).frame(width: 44, height: 44) }
                            .accessibilityLabel("Crypto account details")
                    }
                }
                performanceLabel(scene, value: cryptoAccount ? cryptoValue : profile.total(cash: scene.balance), percent: profile.dailyChange)
            }.padding(.horizontal, 24).padding(.top, 14)
            PortfolioTrend(values: profile.chart, range: range, color: palette.accent, fill: false, highlightLastPoint: true)
                .frame(height: 180).padding(.horizontal, 4)
            rangePicker.padding(.horizontal, 24)
            Button { modal = .cashAccount } label: {
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
                    Button { wealthAccount = .chequing } label: {
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
                Button { modal = .cashAccount } label: {
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
                profileButton("Cash", symbol: "banknote") { modal = .cashAccount }
                profileButton("Security", symbol: "lock.shield") { modal = .security }
                if theme == .coinbase {
                    profileButton("Rewards", symbol: "gift") { modal = .coinbaseRewards }
                    profileButton("Advanced trade", symbol: "chart.bar.xaxis") { modal = .coinbaseAdvanced }
                }
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
                if theme == .wealthsimple {
                    Section("Accounts") {
                        ForEach(WealthsimpleAccount.allCases) { account in
                            Button { wealthAccount = account; tab = .home; modal = nil } label: {
                                HStack { Image(systemName: account.symbol).frame(width: 26); Text(account.title); Spacer(); if wealthAccount == account { Image(systemName: "checkmark") } }
                            }.accessibilityIdentifier("portfolio-account-\(account.rawValue)")
                        }
                    }
                }
                Section {
                    Button("Edit portfolio") { modal = .editor }
                    Button("Choose platform") { modal = .themes }.accessibilityIdentifier("portfolio-theme-picker")
                    Button("Activity") { modal = nil; tab = .activity }
                    Button("Cash") { modal = .cashAccount }.accessibilityIdentifier("portfolio-cash-account")
                    Button("Security") { modal = .security }.accessibilityIdentifier("portfolio-security")
                    if theme == .coinbase {
                        Button("Rewards") { modal = .coinbaseRewards }.accessibilityIdentifier("portfolio-rewards")
                        Button("Advanced trade") { modal = .coinbaseAdvanced }.accessibilityIdentifier("portfolio-advanced")
                    }
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
    case security, cashAccount, cryptoAccount
    var id: String { rawValue }
}
private enum CoinbaseUnavailableFeature {
    case card, wallet
    var title: String {
        switch self { case .card: return "Card"; case .wallet: return "Coinbase Wallet" }
    }
    var symbol: String {
        switch self { case .card: return "creditcard"; case .wallet: return "wallet.pass" }
    }
    var message: String {
        switch self {
        case .card: return "Card information is unavailable."
        case .wallet: return "A separate wallet is not set up."
        }
    }
}
private enum PortfolioTab: String { case home, assets, activity, profile }
private enum WealthsimpleAccount: String, CaseIterable, Identifiable {
    case holdings, chequing, visa, crypto, security
    var id: String { rawValue }
    var title: String {
        switch self { case .holdings: return "Holdings"; case .chequing: return "Chequing"; case .visa: return "Visa Infinite"; case .crypto: return "Crypto"; case .security: return "Security" }
    }
    var symbol: String {
        switch self { case .holdings: return "chart.pie"; case .chequing: return "building.columns"; case .visa: return "creditcard"; case .crypto: return "bitcoinsign.circle"; case .security: return "lock.shield" }
    }
}
enum PortfolioRange: String, CaseIterable, Identifiable {
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

struct PortfolioPalette {
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

enum PortfolioFormatting {
    static func percent(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(2))) + "%" }
    static func quantity(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...8))) }
    // Holdings uses the compact currency symbol while CAD/USD remain explicit filters.
    // This changes presentation only; saved amounts and their currency are preserved.
    static func holdingsMoney(_ value: Double, currency: String) -> String {
        value.formatted(.currency(code: currency).presentation(.narrow))
    }
}

struct PortfolioTrend: View {
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

struct PortfolioAssetIcon: View {
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

struct PortfolioUSDCMark: View {
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
    var title: String? = nil
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
            .navigationTitle(title ?? (incoming ? "Add cash" : "Send cash")).navigationBarTitleDisplayMode(.inline)
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

struct PortfolioAssetDetail: View {
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

struct PortfolioTradePage: View {
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
    var cashOnly = false
    var kindFilter: MarketAssetKind? = nil
    @State private var search = ""
    private var profile: PortfolioProfile { store.portfolioProfile(for: sceneID) }
    private var palette: PortfolioPalette { PortfolioPalette(profile.theme) }
    private var transactions: [MarketTransaction] {
        guard !cashOnly else { return [] }
        return profile.transactions.filter { transaction in
            (assetID == nil || transaction.assetID == assetID) &&
            (kindFilter == nil || profile.positions.contains { $0.id == transaction.assetID && $0.kind == kindFilter }) &&
            (search.isEmpty || transaction.symbol.localizedCaseInsensitiveContains(search) || transaction.side.rawValue.localizedCaseInsensitiveContains(search))
        }.sorted { $0.date > $1.date }
    }
    private var cashTransfers: [SceneEvent] {
        guard assetID == nil && kindFilter == nil else { return [] }
        return store.events.filter { $0.sceneID == sceneID && ($0.kind == .deposit || $0.kind == .payment) && (search.isEmpty || $0.detail.localizedCaseInsensitiveContains(search) || $0.title.localizedCaseInsensitiveContains(search)) }.sorted { $0.date > $1.date }
    }
    private var cryptoTransfers: [WalletTransaction] {
        guard !cashOnly && kindFilter != .stock else { return [] }
        return profile.transfers.filter { (assetID == nil || $0.assetID == assetID) && (search.isEmpty || $0.symbol.localizedCaseInsensitiveContains(search) || $0.kind.title.localizedCaseInsensitiveContains(search) || $0.address.localizedCaseInsensitiveContains(search)) }.sorted { $0.date > $1.date }
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
    @State private var showAccountState = false
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
                Section { Button("Account details, card, and earnings") { showAccountState = true }.accessibilityIdentifier("portfolio-account-state-editor") }
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
            .sheet(isPresented: $showAccountState) { PortfolioAccountStateEditor(sceneID: sceneID) }
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

// Account scenes use the same saved portfolio, cash ledger, and order tickets as Holdings.
// The App Store references establish these overview layouts; their unpictured sheets are local flows.
private struct CoinbaseRewardsPage: View {
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    let sceneID: UUID
    @State private var buying = false
    private let blue = Color(portfolioHex: 0x0052FF)
    private var usdc: MarketPosition? { store.portfolioProfile(for: sceneID).positions.first { $0.symbol.uppercased() == "USDC" && $0.kind == .crypto } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    CoinbaseRewardsArtwork().frame(height: 235).padding(.top, 20)
                    Text("Earn 5% rewards by\nsimply holding USDC").font(.system(size: 29, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                    rewardFact("USDC is designed to be pegged to the US dollar and redeemable 1:1 for USD")
                    rewardFact("Backed by cash and short-dated U.S. treasuries.")
                    rewardFact("Fast and cheap way to send money")
                    if let scene = store.scenes.first(where: { $0.id == sceneID }) {
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Your USDC").font(.system(size: 18, weight: .semibold))
                            HStack { Text("Balance"); Spacer(); Text("\(PortfolioFormatting.quantity(usdc?.units ?? 0)) USDC").monospacedDigit() }
                            HStack { Text("Annual rewards estimate"); Spacer(); Text(scene.money((usdc?.value ?? 0) * 0.05)).monospacedDigit() }
                            Text("Estimate at the displayed 5% rate. Rewards are not credited to this account.").font(.system(size: 12)).foregroundStyle(Color(portfolioHex: 0x6B7077))
                        }.font(.system(size: 14)).padding(20).background(Color(portfolioHex: 0xF3F5F7), in: RoundedRectangle(cornerRadius: 16))
                    }
                    if usdc != nil {
                        Button("Buy USDC") { buying = true }.buttonStyle(.plain).font(.system(size: 16, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 52).background(blue, in: Capsule()).foregroundStyle(.white).accessibilityIdentifier("portfolio-rewards-buy")
                        if let usdc { NavigationLink("View USDC") { PortfolioAssetDetail(sceneID: sceneID, assetID: usdc.id) }.font(.system(size: 15, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 44) }
                    } else {
                        Button("Buy USDC") {
                            if store.addPortfolioMarketAsset(sceneID: sceneID, symbol: "USDC") { buying = true }
                        }.buttonStyle(.plain).font(.system(size: 16, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 52).background(blue, in: Capsule()).foregroundStyle(.white).accessibilityIdentifier("portfolio-rewards-buy")
                        if let error = store.error { Text(error).font(.footnote).foregroundStyle(.red) }
                    }
                }.padding(.horizontal, 26).padding(.bottom, 28)
            }.background(.white).foregroundStyle(Color(portfolioHex: 0x0A0B0D))
                .navigationTitle("Rewards").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 18)).frame(width: 44, height: 44) }.accessibilityLabel("Close rewards") } }
                .tint(blue)
        }.preferredColorScheme(.light)
            .sheet(isPresented: $buying) { if let usdc { PortfolioTradePage(sceneID: sceneID, assetID: usdc.id, side: .buy) } }
    }
    private func rewardFact(_ title: String) -> some View {
        HStack(alignment: .top, spacing: 18) {
            Image(systemName: "checkmark").font(.system(size: 22, weight: .medium)).foregroundStyle(blue).frame(width: 22).padding(.top, 5)
            Text(title).font(.system(size: 17)).foregroundStyle(Color(portfolioHex: 0x6B7077)).fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct CoinbaseRewardsArtwork: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            ZStack {
                ForEach(0..<3) { index in
                    Rectangle().fill(Color(portfolioHex: 0xD0D3DB))
                        .frame(width: width * 0.145, height: height * (0.42 + Double(index) * 0.15))
                        .position(x: width * (0.2 + Double(index) * 0.255), y: height * (0.72 - Double(index) * 0.075))
                }
                PortfolioPolygon(points: [.init(x: 0.04, y: 0.7), .init(x: 0.91, y: 0.28), .init(x: 0.91, y: 0.7)]).fill(Color(portfolioHex: 0x57D18E))
                PortfolioPolygon(points: [.init(x: 0.14, y: 0.7), .init(x: 0.26, y: 0.64), .init(x: 0.26, y: 0.7)]).fill(Color(portfolioHex: 0x2351F5))
                PortfolioPolygon(points: [.init(x: 0.4, y: 0.7), .init(x: 0.56, y: 0.55), .init(x: 0.56, y: 0.7)]).fill(Color(portfolioHex: 0x2351F5))
                PortfolioPolygon(points: [.init(x: 0.66, y: 0.7), .init(x: 0.81, y: 0.35), .init(x: 0.81, y: 0.7)]).fill(Color(portfolioHex: 0x2351F5))
                ForEach(0..<2) { index in
                    Circle().fill(Color(portfolioHex: 0x75DCEC)).overlay(alignment: .bottom) { Rectangle().fill(Color(portfolioHex: 0x2351F5)).frame(height: width * 0.085) }.clipShape(Circle())
                        .overlay { Circle().stroke(.black, lineWidth: 2).padding(9) }
                        .frame(width: width * 0.17, height: width * 0.17)
                        .position(x: width * (0.2 + Double(index) * 0.255), y: height * (0.47 - Double(index) * 0.13))
                }
                Circle().fill(Color(portfolioHex: 0x2351F5)).overlay { PortfolioUSDCMark().padding(width * 0.035) }
                    .frame(width: width * 0.29, height: width * 0.29).position(x: width * 0.72, y: height * 0.19)
                Path { path in
                    path.move(to: CGPoint(x: width * 0.04, y: height * 0.88)); path.addLine(to: CGPoint(x: width * 0.91, y: height * 0.88))
                    path.move(to: CGPoint(x: width * 0.72, y: height * 0.88)); path.addLine(to: CGPoint(x: width * 0.72, y: height * 0.4))
                    path.move(to: CGPoint(x: width * 0.69, y: height * 0.44)); path.addLine(to: CGPoint(x: width * 0.72, y: height * 0.4)); path.addLine(to: CGPoint(x: width * 0.75, y: height * 0.44))
                }.stroke(.black, lineWidth: 2)
                Image(systemName: "sparkle").font(.system(size: 25)).foregroundStyle(Color(portfolioHex: 0xC8CDD5)).position(x: width * 0.54, y: height * 0.16)
                Image(systemName: "sparkle").font(.system(size: 20)).foregroundStyle(Color(portfolioHex: 0xC8CDD5)).position(x: width * 0.88, y: height * 0.31)
                Image(systemName: "sparkle").font(.system(size: 25)).foregroundStyle(.black).position(x: width * 0.81, y: height * 0.61)
            }
        }.accessibilityHidden(true)
    }
}

private struct PortfolioCryptoAccountPage: View {
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    let sceneID: UUID
    private var profile: PortfolioProfile { store.portfolioProfile(for: sceneID) }
    private var palette: PortfolioPalette { PortfolioPalette(profile.theme) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let scene = store.scenes.first(where: { $0.id == sceneID }) {
                        Text("Crypto").font(.system(size: 32))
                        Text(scene.money(profile.positions.filter { $0.kind == .crypto }.reduce(0) { $0 + $1.value })).font(.system(size: 39)).monospacedDigit()
                        Text("Your crypto holdings").font(.system(size: 21, weight: .semibold))
                        ForEach(profile.positions.filter { $0.kind == .crypto }) { position in
                            NavigationLink { PortfolioAssetDetail(sceneID: sceneID, assetID: position.id) } label: { PortfolioAssetRow(position: position, scene: scene, theme: profile.theme) }.buttonStyle(.plain)
                        }
                        if !profile.positions.contains(where: { $0.kind == .crypto }) { Text("No crypto holdings").foregroundStyle(palette.secondary) }
                        NavigationLink("Activity") { PortfolioActivityPage(sceneID: sceneID, kindFilter: .crypto) }.frame(minHeight: 44)
                    }
                }.padding(24)
            }.background(palette.background).foregroundStyle(palette.ink)
                .navigationTitle("Crypto").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }.tint(palette.accent)
        }.preferredColorScheme(palette.isDark ? .dark : .light)
    }
}

private struct WealthsimpleCryptoContent: View {
    @EnvironmentObject private var store: StudioStore
    let sceneID: UUID
    @State private var showingBanner = true
    @State private var showingCoins = false
    @State private var showingStaking = false
    @State private var showingAllTime = true
    private var profile: PortfolioProfile { store.portfolioProfile(for: sceneID) }
    private var positions: [MarketPosition] { profile.positions.filter { $0.kind == .crypto } }
    private let palette = PortfolioPalette(.wealthsimple)
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            if showingBanner {
                ZStack(alignment: .trailing) {
                    PortfolioIridescentCoins().frame(width: 165, height: 140).offset(x: 18, y: 24).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Text("Crypto trading").font(.system(size: 19, weight: .semibold)); Spacer(); Button { showingBanner = false } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("Dismiss crypto banner").accessibilityIdentifier("portfolio-crypto-banner-close") }
                        Text("Buy and sell Bitcoin,\nEthereum, Solana, and\nmore cryptocurrencies.").font(.system(size: 16)).lineSpacing(4)
                        Button { showingCoins = true } label: { Image(systemName: "arrow.right").font(.system(size: 21)).frame(width: 38, height: 38).foregroundStyle(.white).background(.black, in: Circle()) }.accessibilityLabel("Explore cryptocurrencies").accessibilityIdentifier("portfolio-crypto-explore")
                    }.padding(18)
                }.background(Color(portfolioHex: 0xE8DEDD), in: RoundedRectangle(cornerRadius: 23)).clipped()
            }
            VStack(alignment: .leading, spacing: 12) {
                Button { showingStaking = true } label: { HStack(spacing: 8) { Text("Explore staking").font(.system(size: 24, weight: .medium)); Image(systemName: "chevron.right").font(.system(size: 17)).foregroundStyle(palette.secondary) } }.buttonStyle(.plain).accessibilityIdentifier("portfolio-staking")
                Text("Earn rewards when you stake your crypto.").font(.system(size: 16)).foregroundStyle(palette.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        stakingCard(symbol: "SOL", rate: "4.4%", color: .black)
                        stakingCard(symbol: "DOT", rate: "11.8%", color: Color(portfolioHex: 0xE6007A))
                        stakingCard(symbol: "ETH", rate: "2.3%", color: Color(portfolioHex: 0x627EEA))
                    }.padding(.bottom, 8)
                }
            }
            VStack(spacing: 12) {
                HStack {
                    Text("Holdings").font(.system(size: 24, weight: .medium)); Spacer()
                    Button { showingAllTime.toggle() } label: { HStack(spacing: 6) { Text(showingAllTime ? "All time return" : "Today's return").font(.system(size: 12, weight: .semibold)); Image(systemName: "line.3.horizontal.decrease").font(.system(size: 16)) }.foregroundStyle(palette.secondary).frame(minHeight: 44) }.accessibilityIdentifier("portfolio-crypto-return-filter")
                }
                if let scene = store.scenes.first(where: { $0.id == sceneID }) {
                    ForEach(positions) { position in
                        NavigationLink { PortfolioAssetDetail(sceneID: sceneID, assetID: position.id) } label: { cryptoHolding(position, scene: scene) }.buttonStyle(.plain).accessibilityIdentifier("portfolio-asset-\(position.symbol)")
                        Divider().padding(.leading, 45)
                    }
                }
                if positions.isEmpty {
                    Text("No crypto holdings").foregroundStyle(palette.secondary).padding(.vertical, 18)
                    Button("Explore crypto") { showingCoins = true }.frame(minHeight: 44).accessibilityIdentifier("portfolio-crypto-add-assets")
                }
            }
        }.padding(.horizontal, 18).padding(.top, 10)
            .sheet(isPresented: $showingCoins) { cryptoCatalog }
            .sheet(isPresented: $showingStaking) { stakingInformation }

    }
    private func stakingCard(symbol: String, rate: String, color: Color) -> some View {
        Button { showingStaking = true } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Group { if symbol == "SOL" { PortfolioSolanaMark().padding(7).background(.black, in: RoundedRectangle(cornerRadius: 9)) } else if symbol == "ETH" { PortfolioEthereumMark().padding(6).background(color, in: RoundedRectangle(cornerRadius: 9)) } else { Image(systemName: "circle.dotted").resizable().scaledToFit().foregroundStyle(color).padding(4) } }.frame(width: 34, height: 34)
                    Text(symbol).font(.system(size: 18, weight: .semibold))
                }
                Text("Up to \(rate) APY").font(.system(size: 15)).foregroundStyle(palette.secondary)
            }.frame(width: 120, alignment: .leading).padding(18).background(.white, in: RoundedRectangle(cornerRadius: 22)).overlay(RoundedRectangle(cornerRadius: 22).stroke(palette.separator, lineWidth: 1)).shadow(color: .black.opacity(0.04), radius: 4, y: 3)
        }.buttonStyle(.plain).accessibilityIdentifier("portfolio-staking-\(symbol.lowercased())")
    }
    private func cryptoHolding(_ position: MarketPosition, scene: StudioScene) -> some View {
        let gain = showingAllTime ? position.unrealizedGain : position.value * position.changePercent / 100
        let percent = showingAllTime ? (position.costBasis > 0 ? gain / position.costBasis * 100 : 0) : position.changePercent
        return HStack(spacing: 12) {
            PortfolioAssetIcon(position: position, square: true).frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 5) { Text(position.symbol).font(.system(size: 17, weight: .medium)); Text(PortfolioFormatting.quantity(position.units)).font(.system(size: 14)).foregroundStyle(palette.secondary) }
            Spacer(minLength: 5)
            VStack(alignment: .trailing, spacing: 5) {
                Text("\(PortfolioFormatting.holdingsMoney(position.value, currency: scene.currency)) \(scene.currency)").font(.system(size: 16, weight: .medium)).monospacedDigit()
                Text("\(gain >= 0 ? "+" : "−") \(PortfolioFormatting.holdingsMoney(abs(gain), currency: scene.currency)) (\(percent >= 0 ? "+" : "−")\(PortfolioFormatting.percent(abs(percent))))").font(.system(size: 13, weight: .semibold)).foregroundStyle(gain >= 0 ? palette.gain : palette.loss).lineLimit(1).minimumScaleFactor(0.75)
            }
        }.frame(minHeight: 68)
    }
    private var cryptoCatalog: some View {
        NavigationStack {
            List {
                if let scene = store.scenes.first(where: { $0.id == sceneID }) {
                    ForEach(positions) { position in NavigationLink { PortfolioAssetDetail(sceneID: sceneID, assetID: position.id) } label: { PortfolioAssetRow(position: position, scene: scene, theme: .wealthsimple, showsPrice: true) } }
                }
                if positions.isEmpty { Text("No crypto assets in this account") }
                Section("Explore") {
                    ForEach(["BTC", "ETH", "SOL", "USDC"], id: \.self) { symbol in
                        if !positions.contains(where: { $0.symbol.uppercased() == symbol }) {
                            Button("Add \(symbol)") { _ = store.addPortfolioMarketAsset(sceneID: sceneID, symbol: symbol) }.accessibilityIdentifier("portfolio-crypto-add-\(symbol.lowercased())")
                        }
                    }
                }
                if let error = store.error { Text(error).font(.footnote).foregroundStyle(.red) }
            }.navigationTitle("Cryptocurrencies").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingCoins = false } } }
        }
    }
    private var stakingInformation: some View {
        NavigationStack {
            List {
                Section { Text("Earn rewards when you stake your crypto.").font(.system(size: 24, weight: .medium)); Text("Staking locks eligible crypto with a network to support validation. Rates and withdrawal times vary.").foregroundStyle(palette.secondary) }
                Section("Reference rates") { LabeledContent("Solana", value: "Up to 4.4% APY"); LabeledContent("Polkadot", value: "Up to 11.8% APY"); LabeledContent("Ethereum", value: "Up to 2.3% APY") }
                Section("Your holdings") { ForEach(positions) { position in NavigationLink("\(position.name) · \(PortfolioFormatting.quantity(position.units)) \(position.symbol)") { PortfolioAssetDetail(sceneID: sceneID, assetID: position.id) } }; if positions.isEmpty { Text("No crypto holdings") } }
                Section { Text("These are the rates pictured in the saved screen reference. This account does not submit staking transactions or accrue staking rewards.").font(.footnote).foregroundStyle(palette.secondary) }
            }.navigationTitle("Staking").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingStaking = false } } }
        }
    }
}

private struct PortfolioIridescentCoins: View {
    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Color(portfolioHex: 0xE9C9DA), Color(portfolioHex: 0xD2E7D8), Color(portfolioHex: 0xEBE6CF)], startPoint: .topLeading, endPoint: .bottomTrailing)).overlay { Circle().stroke(.white.opacity(0.6), lineWidth: 3).padding(3); PortfolioEthereumMark().frame(width: 40, height: 63).opacity(0.85) }.frame(width: 112, height: 112).rotation3DEffect(.degrees(40), axis: (x: 1, y: 0.6, z: 0)).rotationEffect(.degrees(-25)).offset(x: -28, y: -9)
            Circle().fill(LinearGradient(colors: [Color(portfolioHex: 0xD5AEDD), Color(portfolioHex: 0x82CEE5), Color(portfolioHex: 0xAAC9EA)], startPoint: .topLeading, endPoint: .bottomTrailing)).overlay { Circle().stroke(.white.opacity(0.6), lineWidth: 3).padding(3); Image(systemName: "bitcoinsign").font(.system(size: 55, weight: .light)).foregroundStyle(Color(portfolioHex: 0xB4A6E2)) }.frame(width: 116, height: 116).rotation3DEffect(.degrees(25), axis: (x: 0, y: 1, z: 0)).rotationEffect(.degrees(22)).offset(x: 41, y: 26)
        }
    }
}

private struct WealthsimpleChequingContent: View {
    @EnvironmentObject private var store: StudioStore
    let sceneID: UUID
    @State private var movement: WealthsimpleCashAction?
    @State private var showingAccount = false
    private let palette = PortfolioPalette(.wealthsimple)
    private var state: PortfolioAccountState { store.portfolioProfile(for: sceneID).accountState }
    private var events: [SceneEvent] { store.events.filter { $0.sceneID == sceneID && ($0.kind == .deposit || $0.kind == .payment) }.sorted { $0.date > $1.date } }
    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            if let scene = store.scenes.first(where: { $0.id == sceneID }) {
                HStack {
                    Text(PortfolioFormatting.holdingsMoney(scene.balance, currency: scene.currency)).font(.system(size: 40, weight: .semibold)).monospacedDigit().minimumScaleFactor(0.75).lineLimit(1)
                    Spacer(minLength: 8)
                    Button { showingAccount = true } label: { HStack(spacing: 5) { Image(systemName: "building.columns"); Text("••••1234") }.font(.system(size: 12, weight: .semibold)).padding(.horizontal, 11).frame(minHeight: 32).background(Color(portfolioHex: 0xE6E4E4), in: Capsule()).padding(.vertical, 6) }.accessibilityLabel("Account details").accessibilityIdentifier("portfolio-chequing-details")
                }.padding(.top, 28)
                HStack(alignment: .bottom, spacing: 16) {
                    VStack(alignment: .leading, spacing: 38) {
                        Text("\(Date().formatted(.dateTime.month(.wide))) interest").font(.system(size: 14, weight: .semibold)).foregroundStyle(palette.secondary)
                        VStack(alignment: .leading, spacing: 0) { Text(PortfolioFormatting.holdingsMoney(state.monthlyInterest, currency: scene.currency)).font(.system(size: 28, weight: .medium)).monospacedDigit(); Text("\(state.chequingInterestRate.formatted(.number.precision(.fractionLength(0...2))))%").font(.system(size: 16)).foregroundStyle(palette.secondary) }
                    }
                    Spacer(minLength: 8)
                    HStack(alignment: .bottom, spacing: 7) {
                        ForEach(Array([0.52, 0.37, 1.0, 0.27].enumerated()), id: \.offset) { item in
                            Capsule().fill(Color(portfolioHex: 0xEFEFEF)).frame(width: 23, height: 102).overlay(alignment: .bottom) { Capsule().fill(LinearGradient(colors: [Color(portfolioHex: 0xD9E3FF), Color(portfolioHex: 0x7BA3E6)], startPoint: .top, endPoint: .bottom)).frame(height: 102 * item.element) }
                        }
                    }.accessibilityHidden(true)
                }.padding(18).background(.white, in: RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(palette.separator, lineWidth: 1)).shadow(color: .black.opacity(0.04), radius: 5, y: 3)
                HStack(spacing: 8) {
                    ForEach(WealthsimpleCashAction.allCases) { action in
                        Button { movement = action } label: {
                            VStack(spacing: 10) {
                                Group { if action == .interac { Text("Interac").font(.system(size: 12, weight: .bold)).rotationEffect(.degrees(-10)) } else { Image(systemName: action.symbol).font(.system(size: 21)) } }.frame(maxWidth: .infinity, minHeight: 57).foregroundStyle(action.isDark ? .white : palette.ink).background(action.isDark ? Color(portfolioHex: 0x303030) : .white, in: RoundedRectangle(cornerRadius: 17)).overlay(RoundedRectangle(cornerRadius: 17).stroke(action.isDark ? .black : palette.separator, lineWidth: 1)).shadow(color: .black.opacity(0.05), radius: 4, y: 3)
                                Text(action.title).font(.system(size: 12, weight: .semibold))
                            }.frame(maxWidth: .infinity)
                        }.buttonStyle(.plain).accessibilityIdentifier("portfolio-chequing-\(action.rawValue)")
                    }
                }
                VStack(alignment: .leading, spacing: 14) {
                    Text("Requests").font(.system(size: 23, weight: .medium))
                    Text("No pending requests").font(.system(size: 15)).foregroundStyle(palette.secondary).padding(.vertical, 9)
                    Divider()
                }.padding(.top, 18)
                VStack(alignment: .leading, spacing: 13) {
                    NavigationLink { PortfolioActivityPage(sceneID: sceneID, cashOnly: true) } label: { HStack(spacing: 8) { Text("Activity").font(.system(size: 23, weight: .medium)); Image(systemName: "chevron.right").font(.system(size: 15)).foregroundStyle(palette.secondary) } }.buttonStyle(.plain)
                    if events.isEmpty { Text("No activity yet").foregroundStyle(palette.secondary).font(.system(size: 14)).padding(.vertical, 12) }
                    ForEach(events.prefix(5)) { event in
                        NavigationLink { PortfolioCashEventDetail(event: event, scene: scene) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: event.kind.symbol).frame(width: 34, height: 34).background(Color(portfolioHex: 0xE7E7E7), in: Circle())
                                VStack(alignment: .leading, spacing: 4) { Text(event.detail.isEmpty ? event.title : event.detail).font(.system(size: 15, weight: .medium)); Text(event.date.formatted(date: .abbreviated, time: .omitted)).font(.system(size: 13)).foregroundStyle(palette.secondary) }
                                Spacer(); Text(PortfolioFormatting.holdingsMoney(event.kind.isOutflow ? -event.amount : event.amount, currency: scene.currency)).font(.system(size: 14)).monospacedDigit()
                            }.frame(minHeight: 57)
                        }.buttonStyle(.plain)
                        Divider().padding(.leading, 45)
                    }
                }
            }
        }.padding(.horizontal, 18).padding(.top, 6)
            .sheet(item: $movement) { action in PortfolioCashMovementPage(sceneID: sceneID, incoming: action == .add, title: action.title) }
            .sheet(isPresented: $showingAccount) { NavigationStack { List { LabeledContent("Account", value: "Chequing"); LabeledContent("Account number", value: "••••1234"); if let scene = store.scenes.first(where: { $0.id == sceneID }) { LabeledContent("Currency", value: scene.currency); LabeledContent("Balance", value: scene.money(scene.balance)) }; LabeledContent("Interest rate", value: "\(state.chequingInterestRate)%") }.navigationTitle("Account details").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingAccount = false } } } } }
    }
}

private enum WealthsimpleCashAction: String, CaseIterable, Identifiable {
    case add, transfer, interac, bill
    var id: String { rawValue }
    var title: String { switch self { case .add: return "Add"; case .transfer: return "Transfer"; case .interac: return "e-Transfer"; case .bill: return "Pay bill" } }
    var symbol: String { switch self { case .add: return "plus"; case .transfer: return "arrow.left.arrow.right"; case .interac: return "arrow.up.right"; case .bill: return "doc.text" } }
    var isDark: Bool { self == .add || self == .transfer }
}

private struct PortfolioCashEventDetail: View {
    let event: SceneEvent
    let scene: StudioScene
    var body: some View {
        List { LabeledContent("Status", value: "Completed"); LabeledContent("Amount", value: scene.money(event.amount)); LabeledContent(event.kind.isOutflow ? "To" : "From", value: event.detail); LabeledContent("Date", value: event.date.formatted(date: .abbreviated, time: .shortened)) }.navigationTitle(event.title).navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
    }
}

private struct PortfolioCashAccountPage: View {
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    let sceneID: UUID
    @State private var adding = false
    @State private var withdrawing = false
    @State private var earningsDetail: PortfolioEarningsKind?
    private var profile: PortfolioProfile { store.portfolioProfile(for: sceneID) }
    private var palette: PortfolioPalette { PortfolioPalette(profile.theme) }
    private var state: PortfolioAccountState { profile.accountState }
    private var totalEarnings: Double { state.highYieldCashEarnings + state.iraMatchEarnings }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if let scene = store.scenes.first(where: { $0.id == sceneID }) {
                        if profile.theme == .robinhood {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 8) { Text(scene.money(totalEarnings)).font(.system(size: 38)).monospacedDigit(); Text("Lifetime earnings").font(.system(size: 18)) }
                                Spacer(); Image(systemName: "feather.fill").font(.system(size: 32)).foregroundStyle(Color(portfolioHex: 0xBEA869)).padding(.top, 4)
                            }.padding(.top, 20)
                            GeometryReader { geometry in
                                HStack(spacing: 0) { Rectangle().fill(LinearGradient(colors: [Color(portfolioHex: 0x94844C), Color(portfolioHex: 0xCFBB77)], startPoint: .leading, endPoint: .trailing)).frame(width: geometry.size.width * (totalEarnings > 0 ? state.highYieldCashEarnings / totalEarnings : 1)); Rectangle().fill(palette.accent) }
                            }.frame(height: 98).padding(.vertical, 22).accessibilityLabel("High-yield cash and IRA match earnings")
                            earningsRow(.highYield, amount: state.highYieldCashEarnings, scene: scene)
                            Divider().overlay(palette.separator)
                            earningsRow(.iraMatch, amount: state.iraMatchEarnings, scene: scene)
                            Divider().overlay(palette.separator)
                        }
                        VStack(alignment: .leading, spacing: 12) { Text(profile.theme == .robinhood ? "Buying power" : "Cash balance").font(.system(size: 23, weight: .medium)); Text(scene.money(scene.balance)).font(.system(size: 30)).monospacedDigit() }
                        HStack(spacing: 12) {
                            Button("Add cash") { adding = true }.frame(maxWidth: .infinity, minHeight: 48).background(palette.accent, in: Capsule()).foregroundStyle(profile.theme == .robinhood ? .black : .white)
                            Button("Withdraw") { withdrawing = true }.frame(maxWidth: .infinity, minHeight: 48).overlay(Capsule().stroke(palette.accent, lineWidth: 1))
                        }.font(.system(size: 15, weight: .semibold)).buttonStyle(.plain)
                        NavigationLink { PortfolioActivityPage(sceneID: sceneID, cashOnly: true) } label: { HStack { Text("Activity").font(.system(size: 19, weight: .medium)); Spacer(); Image(systemName: "chevron.right").font(.system(size: 13)) }.frame(minHeight: 48) }.buttonStyle(.plain)
                    }
                }.padding(24)
            }.background(palette.background).foregroundStyle(palette.ink).navigationTitle(profile.theme == .robinhood ? "Earnings" : "Cash").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel("Back") } }.tint(palette.accent)
        }.preferredColorScheme(palette.isDark ? .dark : .light)
            .sheet(isPresented: $adding) { PortfolioCashMovementPage(sceneID: sceneID, incoming: true) }
            .sheet(isPresented: $withdrawing) { PortfolioCashMovementPage(sceneID: sceneID, incoming: false, title: "Withdraw") }
            .sheet(item: $earningsDetail) { kind in NavigationStack { List { if let scene = store.scenes.first(where: { $0.id == sceneID }) { LabeledContent("Lifetime earnings", value: scene.money(kind == .highYield ? state.highYieldCashEarnings : state.iraMatchEarnings)); LabeledContent("Available cash", value: scene.money(scene.balance)) }; Text(kind == .highYield ? "Earnings from eligible cash are tracked separately from your available buying power." : "IRA match earnings are tracked separately from your available buying power.").foregroundStyle(palette.secondary) }.navigationTitle(kind.title).navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { earningsDetail = nil } } } } }
    }
    private func earningsRow(_ kind: PortfolioEarningsKind, amount: Double, scene: StudioScene) -> some View {
        Button { earningsDetail = kind } label: { HStack(spacing: 16) { Rectangle().fill(kind == .highYield ? Color(portfolioHex: 0xC0A967) : palette.accent).frame(width: 18, height: 18); Text(kind.title).font(.system(size: 17)); Spacer(); Text(scene.money(amount)).font(.system(size: 17)).monospacedDigit(); Image(systemName: "chevron.right").font(.system(size: 15)).foregroundStyle(palette.secondary) }.frame(minHeight: 46) }.buttonStyle(.plain).accessibilityIdentifier("portfolio-earnings-\(kind.rawValue)")
    }
}

private enum PortfolioEarningsKind: String, Identifiable {
    case highYield, iraMatch
    var id: String { rawValue }
    var title: String { self == .highYield ? "High-Yield Cash" : "IRA match" }
}

private struct WealthsimpleVisaContent: View {
    @EnvironmentObject private var store: StudioStore
    let sceneID: UUID
    @State private var managing = false
    private let palette = PortfolioPalette(.wealthsimple)
    private var state: PortfolioAccountState { store.portfolioProfile(for: sceneID).accountState }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let scene = store.scenes.first(where: { $0.id == sceneID }) {
                Button { managing = true } label: {
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 12).fill(LinearGradient(colors: [Color(portfolioHex: 0x050505), Color(portfolioHex: 0x373737)], startPoint: .leading, endPoint: .trailing))
                        VStack {
                            HStack { Spacer(); Text("W").font(.system(size: 54, weight: .black, design: .serif)).foregroundStyle(.black.opacity(0.8)) }
                            Spacer()
                            HStack(alignment: .bottom) {
                                HStack(spacing: 7) { Image(systemName: state.locked ? "lock" : "arrow.left.arrow.right"); Text(state.locked ? "Card frozen" : "Manage card") }.font(.system(size: 12)).foregroundStyle(.white)
                                Spacer()
                                VStack(alignment: .trailing, spacing: -2) { Text("VISA").font(.system(size: 31, weight: .black)).italic(); Text("Infinite").font(.system(size: 13)) }.foregroundStyle(.black.opacity(0.85))
                            }
                        }.padding(17)
                    }.aspectRatio(1.586, contentMode: .fit).shadow(color: .black.opacity(0.08), radius: 3, y: 2)
                }.buttonStyle(.plain).accessibilityIdentifier("portfolio-visa-manage")
                HStack(alignment: .top, spacing: 9) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Total balance").font(.system(size: 15, weight: .semibold)).foregroundStyle(palette.secondary)
                        Text(PortfolioFormatting.holdingsMoney(state.cardBalance, currency: scene.currency)).font(.system(size: 27, weight: .semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                        Text("\(PortfolioFormatting.holdingsMoney(state.availableCredit, currency: scene.currency)) available").font(.system(size: 11)).foregroundStyle(palette.secondary).lineLimit(1).minimumScaleFactor(0.8)
                        GeometryReader { geometry in
                            let creditLimit = state.cardBalance + state.availableCredit
                            HStack(spacing: 2) { RoundedRectangle(cornerRadius: 3).fill(Color(portfolioHex: 0x608DD8)).frame(width: geometry.size.width * (creditLimit > 0 ? min(1, state.cardBalance / creditLimit) : 0)); RoundedRectangle(cornerRadius: 3).fill(Color(portfolioHex: 0xEEEDEC)) }
                        }.frame(height: 16).padding(.top, 10)
                    }.padding(17).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 24)).overlay(RoundedRectangle(cornerRadius: 24).stroke(palette.separator, lineWidth: 1))
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 3) { Text("Cash back").font(.system(size: 15, weight: .semibold)).foregroundStyle(palette.secondary); Spacer(minLength: 0); Text("2%").font(.system(size: 11, weight: .semibold)).padding(.horizontal, 7).padding(.vertical, 3).background(Color(portfolioHex: 0xF3F1F2), in: Capsule()) }
                        Text(PortfolioFormatting.holdingsMoney(state.cashBack, currency: scene.currency)).font(.system(size: 27, weight: .semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                        Text("\(PortfolioFormatting.holdingsMoney(state.monthCashBack, currency: scene.currency)) this month").font(.system(size: 11)).foregroundStyle(palette.secondary).lineLimit(1).minimumScaleFactor(0.8)
                        HStack(alignment: .bottom, spacing: 4) { ForEach(Array([0.13, 0.15, 0.36, 0.13, 0.5, 0.5].enumerated()), id: \.offset) { item in RoundedRectangle(cornerRadius: 2).fill(item.offset == 5 && state.monthCashBack > 0 ? Color(portfolioHex: 0x608DD8) : Color(portfolioHex: 0xEEEDEC)).frame(height: item.element * 33) } }.frame(height: 16, alignment: .bottom).padding(.top, 10).accessibilityHidden(true)
                    }.padding(17).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 24)).overlay(RoundedRectangle(cornerRadius: 24).stroke(palette.separator, lineWidth: 1))
                }.padding(.top, 10)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Latest statement").font(.system(size: 15, weight: .semibold)).foregroundStyle(palette.secondary)
                    Text(PortfolioFormatting.holdingsMoney(state.statementAmount, currency: scene.currency)).font(.system(size: 28, weight: .semibold)).monospacedDigit()
                    Button {
                        var updated = state; updated.autopay.toggle(); _ = store.updatePortfolioAccountState(sceneID: sceneID, state: updated)
                    } label: { HStack(spacing: 10) { Image(systemName: "dollarsign.arrow.circlepath").font(.system(size: 20)); Text(state.autopay ? "Auto-pay is on" : "Auto-pay is off").font(.system(size: 13, weight: .semibold)); Spacer() }.padding(.horizontal, 17).frame(minHeight: 49).background(Color(portfolioHex: 0xECECEC), in: RoundedRectangle(cornerRadius: 17)) }.buttonStyle(.plain).padding(.top, 4).accessibilityIdentifier("portfolio-visa-autopay").accessibilityValue(state.autopay ? "On" : "Off")
                }.padding(17).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 24)).overlay(RoundedRectangle(cornerRadius: 24).stroke(palette.separator, lineWidth: 1)).padding(.top, 1)
                Text("Activity").font(.system(size: 24, weight: .medium)).frame(maxWidth: .infinity, minHeight: 50, alignment: .leading).padding(.top, 17)
                Text("No card transactions").font(.system(size: 14)).foregroundStyle(palette.secondary)
                if let error = store.error { Text(error).font(.footnote).foregroundStyle(.red) }
            }
        }.padding(.horizontal, 18).padding(.top, 4)
            .sheet(isPresented: $managing) { cardManagement }
    }
    private var cardManagement: some View {
        NavigationStack {
            Form {
                Section("Card") { LabeledContent("Card", value: "Visa Infinite"); Toggle("Freeze card", isOn: Binding(get: { state.locked }, set: { value in var updated = state; updated.locked = value; _ = store.updatePortfolioAccountState(sceneID: sceneID, state: updated) })).accessibilityIdentifier("portfolio-visa-freeze") }
                Section("Payments") { Toggle("Auto-pay", isOn: Binding(get: { state.autopay }, set: { value in var updated = state; updated.autopay = value; _ = store.updatePortfolioAccountState(sceneID: sceneID, state: updated) })).accessibilityIdentifier("portfolio-visa-autopay-toggle") }
                if let scene = store.scenes.first(where: { $0.id == sceneID }) { Section("Summary") { LabeledContent("Total balance", value: scene.money(state.cardBalance)); LabeledContent("Available credit", value: scene.money(state.availableCredit)); LabeledContent("Cash back", value: scene.money(state.cashBack)) } }
                if let error = store.error { Section { Text(error).foregroundStyle(.red) } }
            }.navigationTitle("Manage card").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { managing = false } } }
        }
    }
}

private struct PortfolioSecurityPage: View {
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    let sceneID: UUID
    var body: some View {
        NavigationStack {
            ScrollView { PortfolioSecurityContent(sceneID: sceneID).padding(.bottom, 30) }
                .background(store.portfolioProfile(for: sceneID).theme == .wealthsimple ? PortfolioPalette(.wealthsimple).background : .white)
                .navigationTitle("Security").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 18)).frame(width: 44, height: 44) }.accessibilityLabel("Close security") } }
        }.preferredColorScheme(.light)
    }
}

private struct PortfolioSecurityContent: View {
    @EnvironmentObject private var store: StudioStore
    let sceneID: UUID
    private var profile: PortfolioProfile { store.portfolioProfile(for: sceneID) }
    private var enabled: Bool { profile.accountState.twoStepEnabled }
    private var wealthsimple: Bool { profile.theme == .wealthsimple }
    private var blue: Color { Color(portfolioHex: 0x0052FF) }
    var body: some View {
        VStack(spacing: wealthsimple ? 30 : 24) {
            if wealthsimple {
                WealthsimpleSecurityArtwork().frame(height: 240).padding(.top, 35)
                Text("We keep your data\nand money safe").font(.system(size: 29, weight: .semibold)).multilineTextAlignment(.center)
                Text("Your deposits and securities are protected through CDIC, up to $1M coverage or CIPF within specified limits.").font(.system(size: 17)).foregroundStyle(Color(portfolioHex: 0x787878)).multilineTextAlignment(.center).lineSpacing(3).padding(.horizontal, 15)
                Toggle("2-step verification", isOn: Binding(get: { enabled }, set: { value in var state = profile.accountState; state.twoStepEnabled = value; _ = store.updatePortfolioAccountState(sceneID: sceneID, state: state) })).font(.system(size: 15, weight: .medium)).padding(18).background(.white, in: RoundedRectangle(cornerRadius: 17)).tint(.black).accessibilityIdentifier("portfolio-security-two-step")
            } else {
                HStack(spacing: 8) { ForEach(0..<3) { index in Capsule().fill(index < (enabled ? 3 : 1) ? blue : Color(portfolioHex: 0xE1E2E6)).frame(height: 5) } }.padding(.top, 15).padding(.horizontal, 16)
                CoinbaseSecurityArtwork().frame(height: 260).padding(.vertical, 14)
                Text(enabled ? "Your account is secure" : "Let's secure your account").font(.system(size: 28, weight: .semibold)).frame(maxWidth: .infinity, alignment: .leading)
                securityStep(number: 1, title: "Create your account", subtitle: nil, done: enabled)
                securityStep(number: 2, title: "Secure your account", subtitle: "2-step verification", done: enabled)
                Button {
                    var state = profile.accountState; state.twoStepEnabled.toggle(); _ = store.updatePortfolioAccountState(sceneID: sceneID, state: state)
                } label: { Text(enabled ? "Manage 2-step verification" : "Enable 2-step verification").font(.system(size: 16, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 52).background(blue, in: Capsule()).foregroundStyle(.white) }.buttonStyle(.plain).padding(.top, 12).accessibilityIdentifier("portfolio-security-two-step").accessibilityValue(enabled ? "Enabled" : "Disabled")
            }
            if let error = store.error { Text(error).font(.footnote).foregroundStyle(.red) }
        }.padding(.horizontal, 24).foregroundStyle(Color(portfolioHex: 0x0A0B0D))
    }
    private func securityStep(number: Int, title: String, subtitle: String?, done: Bool) -> some View {
        HStack(spacing: 18) {
            Circle().fill(blue).frame(width: 35, height: 35).overlay { if done { Image(systemName: "checkmark").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white) } else { Text(String(number)).font(.system(size: 22, weight: .medium)).foregroundStyle(.white) } }
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.system(size: 20, weight: .semibold)); if let subtitle { Text(subtitle).font(.system(size: 19)).foregroundStyle(Color(portfolioHex: 0x6B7077)) } }
            Spacer(minLength: 0)
        }.frame(minHeight: 56)
    }
}

private struct CoinbaseSecurityArtwork: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            ZStack {
                Path { path in path.addArc(center: CGPoint(x: width * 0.5, y: height * 0.42), radius: width * 0.25, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false) }.stroke(Color(portfolioHex: 0xD0D3DB), lineWidth: width * 0.055)
                Path { path in path.addArc(center: CGPoint(x: width * 0.5, y: height * 0.42), radius: width * 0.165, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false) }.stroke(Color(portfolioHex: 0x0A0B0D), lineWidth: width * 0.012)
                Circle().fill(Color(portfolioHex: 0xFFD500)).frame(width: width * 0.22, height: width * 0.22).position(x: width * 0.5, y: height * 0.405)
                Rectangle().fill(Color(portfolioHex: 0xD0D3DB)).frame(width: width * 0.7, height: height * 0.17).position(x: width * 0.5, y: height * 0.69)
                Rectangle().fill(Color(portfolioHex: 0x0052FF)).frame(width: width * 0.46, height: height * 0.37).position(x: width * 0.5, y: height * 0.59)
                Rectangle().fill(Color(portfolioHex: 0xD0D3DB)).frame(width: width * 0.46, height: height * 0.055).position(x: width * 0.5, y: height * 0.795)
                Circle().fill(Color(portfolioHex: 0x0A0B0D)).frame(width: width * 0.057, height: width * 0.057).position(x: width * 0.5, y: height * 0.545)
                Rectangle().fill(Color(portfolioHex: 0x0A0B0D)).frame(width: width * 0.014, height: height * 0.12).position(x: width * 0.5, y: height * 0.6)
            }
        }.accessibilityHidden(true)
    }
}

private struct WealthsimpleSecurityArtwork: View {
    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Color(portfolioHex: 0x91BDDB), Color(portfolioHex: 0x3A709A)], startPoint: .topLeading, endPoint: .bottomTrailing)).overlay { Circle().stroke(Color(portfolioHex: 0x5E8DAF), lineWidth: 3).padding(3); Text("W").font(.system(size: 66, weight: .light, design: .serif)).foregroundStyle(Color(portfolioHex: 0x6C9ABD)) }.frame(width: 145, height: 145).rotation3DEffect(.degrees(40), axis: (x: 0.3, y: 1, z: 0)).rotationEffect(.degrees(-22)).offset(x: -78, y: -30)
            Circle().fill(LinearGradient(colors: [Color(portfolioHex: 0xE7C2B8), Color(portfolioHex: 0xC78D83)], startPoint: .topLeading, endPoint: .bottomTrailing)).overlay { Circle().stroke(Color(portfolioHex: 0xEFD0C5), lineWidth: 3).padding(4); Text("$").font(.system(size: 81, weight: .ultraLight)).foregroundStyle(Color(portfolioHex: 0xE1B5A9)) }.frame(width: 137, height: 137).rotation3DEffect(.degrees(-25), axis: (x: 0.3, y: 1, z: 0)).rotationEffect(.degrees(-17)).offset(x: 80, y: 41)
            Image(systemName: "shield.fill").resizable().scaledToFit().foregroundStyle(LinearGradient(colors: [Color(portfolioHex: 0xDED2C7), Color(portfolioHex: 0xB9CFD8)], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 135, height: 172).overlay { Image(systemName: "shield.fill").resizable().scaledToFit().foregroundStyle(.white).padding(18); Image(systemName: "lock").font(.system(size: 43, weight: .light)).foregroundStyle(LinearGradient(colors: [Color(portfolioHex: 0xE9D1BD), Color(portfolioHex: 0xBDC9CD)], startPoint: .topLeading, endPoint: .bottomTrailing)) }.offset(y: 6)
        }.accessibilityHidden(true)
    }
}

private struct PortfolioAccountStateEditor: View {
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    let sceneID: UUID
    @State private var values: [PortfolioAccountField: String] = [:]
    @State private var twoStep = false
    @State private var locked = false
    @State private var autopay = false
    private var candidate: PortfolioAccountState? {
        var state = store.portfolioProfile(for: sceneID).accountState
        for field in PortfolioAccountField.allCases {
            guard let text = values[field], let amount = Simulation.parseAmount(text) else { return nil }
            state[keyPath: field.keyPath] = amount
        }
        state.twoStepEnabled = twoStep; state.locked = locked; state.autopay = autopay
        return state.isValid ? state : nil
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Chequing") { accountField(.chequingInterestRate); accountField(.monthlyInterest) }
                Section("Visa Infinite") { accountField(.cardBalance); accountField(.availableCredit); accountField(.cashBack); accountField(.monthCashBack); accountField(.statementAmount); Toggle("Freeze card", isOn: $locked); Toggle("Auto-pay", isOn: $autopay) }
                Section("Earnings") { accountField(.highYieldCashEarnings); accountField(.iraMatchEarnings) }
                Section("Security") { Toggle("2-step verification", isOn: $twoStep) }
                Section { Text("Account summaries are separate from available cash. Editing a summary does not create an order or a transfer.").font(.footnote).foregroundStyle(.secondary) }
                if let error = store.error { Section { Text(error).foregroundStyle(.red) } }
            }.navigationTitle("Account scene details").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { if let candidate, store.updatePortfolioAccountState(sceneID: sceneID, state: candidate) { dismiss() } }.disabled(candidate == nil) } }
                .onAppear { let state = store.portfolioProfile(for: sceneID).accountState; values = Dictionary(uniqueKeysWithValues: PortfolioAccountField.allCases.map { ($0, state[keyPath: $0.keyPath].formatted(.number.grouping(.never))) }); twoStep = state.twoStepEnabled; locked = state.locked; autopay = state.autopay }
        }
    }
    private func accountField(_ field: PortfolioAccountField) -> some View {
        LabeledContent(field.title) { TextField(field.title, text: Binding(get: { values[field] ?? "" }, set: { values[field] = $0 })).keyboardType(.decimalPad).multilineTextAlignment(.trailing).accessibilityIdentifier("portfolio-account-field-\(field.rawValue)") }
    }
}

private enum PortfolioAccountField: String, CaseIterable {
    case cardBalance, availableCredit, cashBack, monthCashBack, statementAmount, chequingInterestRate, monthlyInterest, highYieldCashEarnings, iraMatchEarnings
    var title: String { switch self { case .cardBalance: return "Card balance"; case .availableCredit: return "Available credit"; case .cashBack: return "Cash back"; case .monthCashBack: return "Cash back this month"; case .statementAmount: return "Statement amount"; case .chequingInterestRate: return "Interest rate (%)"; case .monthlyInterest: return "Monthly interest"; case .highYieldCashEarnings: return "High-yield cash earnings"; case .iraMatchEarnings: return "IRA match earnings" } }
    var keyPath: WritableKeyPath<PortfolioAccountState, Double> { switch self { case .cardBalance: return \.cardBalance; case .availableCredit: return \.availableCredit; case .cashBack: return \.cashBack; case .monthCashBack: return \.monthCashBack; case .statementAmount: return \.statementAmount; case .chequingInterestRate: return \.chequingInterestRate; case .monthlyInterest: return \.monthlyInterest; case .highYieldCashEarnings: return \.highYieldCashEarnings; case .iraMatchEarnings: return \.iraMatchEarnings } }
}

private extension Color {
    init(portfolioHex: UInt32) { self.init(red: Double((portfolioHex >> 16) & 255) / 255, green: Double((portfolioHex >> 8) & 255) / 255, blue: Double(portfolioHex & 255) / 255) }
}
