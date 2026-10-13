import SwiftUI
import Charts
import CoreImage.CIFilterBuiltins

/// A saved crypto-wallet scene. All transfers affect this device's session only.
struct WalletPlayback: View {
    let sceneID: UUID
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("cleanPlayback") private var cleanPlayback = false
    @State private var tab: WalletPage = .assets
    @State private var sheet: WalletDestination?
    @State private var search = ""
    @State private var hiddenBalance = false
    @State private var showProfileActions = false

    private var scene: StudioScene? { store.scenes.first { $0.id == sceneID } }
    private var profile: WalletProfile { store.walletProfile(for: sceneID) }
    private var palette: WalletPalette { WalletPalette(theme: profile.theme) }
    private var holdings: [WalletHolding] {
        profile.holdings.filter { search.isEmpty || "\($0.name) \($0.symbol) \($0.network)".localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let scene {
                    VStack(spacing: 0) {
                        header(scene)
                        switch tab {
                        case .assets: assetPage(scene)
                        case .activity: activityPage(scene)
                        case .settings: settingsPage(scene)
                        case .money: moneyPage(scene)
                        case .rewards: rewardsPage
                        }
                    }
                    .background(palette.background)
                    .safeAreaInset(edge: .bottom, spacing: 0) { if profile.theme != .phantom { bottomNavigation } }
                } else {
                    ContentUnavailableView("Wallet unavailable", systemImage: "wallet.bifold")
                        .overlay(alignment: .topTrailing) { Button("Close") { dismiss() }.padding() }
                }
            }
            .background(palette.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .tint(palette.accent)
            .preferredColorScheme(profile.theme == .trustWallet ? .light : .dark)
            .sheet(item: $sheet) { destination in
                if let scene { sheetView(destination, scene: scene) }
            }
            .confirmationDialog("Wallet actions", isPresented: $showProfileActions, titleVisibility: .hidden) {
                Button("Edit wallet") { sheet = .edit }
                Button("Receive") { sheet = .receive }
                Button("Activity") { tab = .activity }.accessibilityIdentifier("wallet-tab-activity")
                Button("Settings") { tab = .settings }.accessibilityIdentifier("wallet-tab-settings")
                Button("Close scene") { dismiss() }
                Button("Cancel", role: .cancel) { }
            }
            .alert("Unable to update wallet", isPresented: Binding(get: { store.error != nil && sheet?.id == nil }, set: { if !$0 { store.error = nil } })) {
                Button("OK") { store.error = nil }
            } message: { Text(store.error ?? "") }
            .onChange(of: scene?.kind) { _, kind in if kind != .wallet { dismiss() } }
        }
        .accessibilityIdentifier("wallet-playback")
    }

    private func header(_ scene: StudioScene) -> some View {
        HStack(spacing: 8) {
            profileMenu
            if profile.theme == .phantom {
                Button { tab = .assets } label: { Text("Home").font(.system(size: 15, weight: .medium)).padding(.horizontal, 16).frame(minHeight: 44).background(tab == .assets ? palette.accent : palette.card, in: Capsule()).foregroundStyle(tab == .assets ? .black : palette.ink) }.accessibilityIdentifier("wallet-tab-assets")
                Button { sheet = .swap(.swap) } label: { Text("Trade").font(.system(size: 15, weight: .medium)).padding(.horizontal, 13).frame(minHeight: 44).background(palette.card, in: Capsule()) }
                Button { sheet = .explore } label: { Text("Explore").font(.system(size: 15, weight: .medium)).padding(.horizontal, 13).frame(minHeight: 44).background(palette.card, in: Capsule()) }
                Spacer(minLength: 0)
            } else if profile.theme == .trustWallet {
                Spacer()
                Text("Home").font(.system(size: 19, weight: .semibold))
                Spacer()
                Button { tab = .activity } label: { Image(systemName: "bell.fill").font(.system(size: 18)).frame(width: 44, height: 44) }.accessibilityLabel("Activity")
            } else {
                Spacer()
                Button { tab = .activity } label: { Image(systemName: "clock").font(.system(size: 21)).frame(width: 44, height: 44) }.accessibilityLabel("Activity")
                Button { UIPasteboard.general.string = profile.address } label: { Image(systemName: "square.on.square").font(.system(size: 21)).frame(width: 44, height: 44) }.accessibilityLabel("Copy wallet address")
                Button { tab = .settings } label: { Image(systemName: "line.3.horizontal").font(.system(size: 21)).frame(width: 44, height: 44) }.accessibilityLabel("Wallet menu")
            }
            if !cleanPlayback {
                Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)).frame(width: 44, height: 44) }
                    .accessibilityLabel("Close wallet playback").accessibilityIdentifier("close-scene")
            }
        }
        .buttonStyle(.plain).foregroundStyle(palette.ink)
        .padding(.horizontal, 16).padding(.vertical, 5)
    }
    private var profileMenu: some View {
        Button { showProfileActions = true } label: {
            HStack(spacing: 7) {
                if profile.theme == .trustWallet { Image(systemName: "gearshape.fill").font(.system(size: 21)).frame(width: 44, height: 44) }
                else if profile.theme == .phantom { WalletBrandMark(theme: profile.theme).frame(width: 36, height: 36).frame(width: 44, height: 44) }
                else {
                    Text("Account 1").font(.system(size: 15, weight: .semibold)).lineLimit(1)
                    Image(systemName: "chevron.down").font(.system(size: 11))
                }
            }.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Wallet profile and close scene").accessibilityIdentifier("wallet-profile-menu")
    }

    private func assetPage(_ scene: StudioScene) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                balanceHeader(scene)
                if profile.theme != .phantom { actionRow }
                stablecoinCard(scene)
                if profile.theme == .trustWallet {
                    HStack {
                        Text("Crypto").font(.system(size: 17, weight: .semibold))
                        Spacer()
                        Button { sheet = .edit } label: {
                            Image(systemName: "slider.horizontal.3").font(.system(size: 19)).frame(width: 44, height: 44).contentShape(Rectangle())
                        }.accessibilityLabel("Manage crypto")
                    }
                } else {
                    HStack {
                        Text("Tokens").font(.system(size: 17, weight: .semibold))
                        Spacer()
                        Menu {
                            Button("All networks") { search = "" }
                            ForEach(Array(Set(profile.holdings.map(\.network))).sorted(), id: \.self) { network in
                                Button(network) { search = network }
                            }
                        } label: {
                            HStack(spacing: 5) { Text(search.isEmpty ? "All networks" : search).lineLimit(1); Image(systemName: "chevron.down").font(.system(size: 9)) }
                                .font(.system(size: 12)).frame(minHeight: 44).contentShape(Rectangle())
                        }
                    }
                }
                if holdings.isEmpty {
                    ContentUnavailableView("No assets", systemImage: "bitcoinsign.circle", description: Text("Manage your assets to add a token."))
                } else {
                    LazyVStack(spacing: profile.theme == .phantom ? 9 : 0) {
                        ForEach(holdings) { holding in
                            Button { sheet = .token(holding.id) } label: {
                                WalletAssetRow(holding: holding, currency: scene.currency, theme: profile.theme)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("wallet-asset-" + holding.symbol.lowercased())
                            if profile.theme != .phantom && holding.id != holdings.last?.id {
                                Divider().overlay(palette.separator).padding(.leading, 59)
                            }
                        }
                    }
                }
                Button { sheet = .edit } label: {
                    Label(profile.theme == .metamask ? "Manage tokens" : "Manage assets", systemImage: "plus")
                        .font(.system(size: 14, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 10)
            }
            .padding(.horizontal, 20).padding(.top, 14)
            .foregroundStyle(palette.ink)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("wallet-assets")
    }

    private func balanceHeader(_ scene: StudioScene) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if profile.theme != .metamask {
                HStack {
                    Button { sheet = .edit } label: {
                        HStack(spacing: 6) {
                            Text(profile.theme == .phantom ? "My Wallet" : "Main wallet").font(.system(size: 15, weight: .medium))
                            Image(systemName: "chevron.down").font(.system(size: 11))
                        }.frame(minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain).foregroundStyle(palette.secondary)
                    Spacer()
                    Button { hiddenBalance.toggle() } label: {
                        Image(systemName: hiddenBalance ? "eye.slash" : "eye").font(.system(size: 16)).frame(width: 44, height: 44)
                    }.accessibilityLabel(hiddenBalance ? "Show balance" : "Hide balance")
                }
            }
            Text(hiddenBalance ? "••••••" : scene.money(profile.fiatValue))
                .font(.system(size: profile.theme == .phantom ? 44 : 39, weight: profile.theme == .trustWallet ? .bold : .semibold))
                .minimumScaleFactor(0.65).lineLimit(1).accessibilityIdentifier("wallet-total")
            if !hiddenBalance && profile.theme != .trustWallet {
                Text((weightedChange >= 0 ? "+" : "") + scene.money(profile.fiatValue * weightedChange / 100)
                     + (profile.theme == .phantom ? " Today" : " (" + weightedChange.formatted(.number.precision(.fractionLength(1))) + "%)"))
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(weightedChange >= 0 ? palette.positive : .red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    @ViewBuilder private func stablecoinCard(_ scene: StudioScene) -> some View {
        if profile.theme != .trustWallet, let stable = profile.holdings.first(where: { $0.symbol.uppercased() == "USDC" || $0.symbol.uppercased() == "USDT" }) {
            HStack {
                if profile.theme == .phantom { Image(systemName: "banknote").font(.system(size: 22)) }
                VStack(alignment: .leading, spacing: 8) {
                    Text(profile.theme == .phantom ? "Cash" : "Money balance").font(.system(size: 15, weight: .medium))
                    if profile.theme == .metamask {
                        HStack(spacing: 8) {
                            Text(scene.money(stable.value)).font(.system(size: 20, weight: .semibold))
                            Text(stable.symbol).font(.system(size: 12)).foregroundStyle(palette.secondary)
                        }
                    }
                }
                Spacer()
                if profile.theme == .phantom {
                    Button { sheet = .token(stable.id) } label: { Text(scene.money(stable.value)).font(.system(size: 19)).frame(minHeight: 44) }
                        .buttonStyle(.plain)
                } else {
                    Button { sheet = .swap(.sell) } label: {
                        Text("Add").font(.system(size: 14, weight: .semibold)).padding(.horizontal, 16).frame(minHeight: 44)
                            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 13))
                    }.buttonStyle(.plain)
                }
            }
            .padding(18).background(palette.card, in: RoundedRectangle(cornerRadius: 19))
        }
    }
    private var actionRow: some View {
        HStack(spacing: profile.theme == .trustWallet ? 4 : 10) {
            if profile.theme == .metamask {
                walletAction(title: "Buy", symbol: "dollarsign") { sheet = .swap(.buy) }
                walletAction(title: "Swap", symbol: "arrow.up.arrow.down") { sheet = .swap(.swap) }
            }
            walletAction(title: "Send", symbol: "arrow.up.right") { sheet = .send(nil) }
            walletAction(title: "Receive", symbol: "arrow.down.left") { sheet = .receive }
            if profile.theme == .trustWallet {
                walletAction(title: "Buy", symbol: "creditcard.fill") { sheet = .swap(.buy) }
                walletAction(title: "Sell", symbol: "building.columns.fill") { sheet = .swap(.sell) }
                walletAction(title: "History", symbol: "clock") { tab = .activity }
            }
            if profile.theme == .phantom { walletAction(title: "Swap", symbol: "arrow.left.arrow.right") { sheet = .swap(.swap) } }
        }.padding(.vertical, 5)
    }
    private func walletAction(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 9) {
                Image(systemName: symbol).font(.system(size: 21, weight: .medium))
                    .frame(width: profile.theme == .trustWallet ? 44 : 50, height: profile.theme == .trustWallet ? 44 : 39)
                    .background(profile.theme == .trustWallet ? palette.card : .clear, in: Circle())
                Text(title).font(.system(size: 12, weight: .medium))
            }
            .padding(.vertical, profile.theme == .metamask ? 9 : 0)
            .frame(maxWidth: .infinity, minHeight: profile.theme == .metamask ? 82 : 72)
            .background(profile.theme == .metamask ? palette.card : .clear, in: RoundedRectangle(cornerRadius: 15))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(palette.ink)
        .accessibilityIdentifier("wallet-" + title.lowercased())
    }

    private func activityPage(_ scene: StudioScene) -> some View {
        List {
            if profile.transactions.isEmpty {
                ContentUnavailableView("No activity yet", systemImage: "clock", description: Text("Your sends and received assets appear here."))
            }
            ForEach(profile.transactions.sorted { $0.date > $1.date }) { transaction in
                Button { sheet = .transaction(transaction.id) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: transaction.kind == .send ? "arrow.up.right" : "arrow.down.left")
                            .font(.system(size: 17, weight: .medium)).frame(width: 43, height: 43)
                            .foregroundStyle(palette.accent).background(palette.card, in: Circle())
                        VStack(alignment: .leading, spacing: 5) {
                            Text(transaction.kind == .send ? "Sent \(transaction.symbol)" : "Received \(transaction.symbol)").font(.system(size: 15, weight: .semibold))
                            Text(transaction.date.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 11)).foregroundStyle(palette.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 5) {
                            Text((transaction.kind == .send ? "−" : "+") + walletQuantity(transaction.quantity) + " " + transaction.symbol)
                                .font(.system(size: 13, weight: .medium))
                            Text(scene.money(transaction.value)).font(.system(size: 11)).foregroundStyle(palette.secondary)
                        }
                    }.padding(.vertical, 8)
                }
                .buttonStyle(.plain).listRowBackground(palette.background)
            }
        }
        .listStyle(.plain).scrollContentBackground(.hidden)
        .foregroundStyle(palette.ink)
        .navigationTitle("Activity")
        .accessibilityIdentifier("wallet-activity")
    }

    private func settingsPage(_ scene: StudioScene) -> some View {
        List {
            Section {
                HStack(spacing: 12) {
                    WalletBrandMark(theme: profile.theme).frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(scene.name).font(.headline)
                        Text(profile.theme.name).font(.caption).foregroundStyle(palette.secondary)
                    }
                }.padding(.vertical, 7)
            }
            Section {
                Button { sheet = .edit } label: { Label("Edit wallet and assets", systemImage: "slider.horizontal.3") }.frame(minHeight: 44)
                Button { sheet = .receive } label: { Label("Address and QR code", systemImage: "qrcode") }.frame(minHeight: 44)
                Button { tab = .activity } label: { Label("Activity", systemImage: "clock") }.frame(minHeight: 44)
            }
            Section {
                Button { dismiss() } label: { Label("Close scene", systemImage: "xmark.circle") }.frame(minHeight: 44)
                    .accessibilityIdentifier("wallet-close-scene")
            }
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden)
        .foregroundStyle(palette.ink)
        .accessibilityIdentifier("wallet-settings")
    }

    @ViewBuilder private var bottomNavigation: some View {
        if profile.theme == .metamask {
            HStack(spacing: 0) {
                metaNavigationButton("Home", symbol: "house.fill", page: .assets, identifier: "wallet-tab-assets") { tab = .assets }
                metaNavigationButton("Explore", symbol: "safari", page: nil, identifier: "wallet-tab-explore") { sheet = .explore }
                Button { sheet = .swap(.swap) } label: {
                    VStack(spacing: 5) {
                        Image(systemName: "plus").font(.system(size: 22, weight: .regular)).frame(width: 39, height: 39).background(palette.accent, in: Circle()).foregroundStyle(.white)
                        Text("Trade").font(.system(size: 10, weight: .medium)).foregroundStyle(palette.secondary)
                    }.frame(maxWidth: .infinity, minHeight: 56).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("wallet-tab-trade")
                metaNavigationButton("Money", symbol: "banknote", page: .money, identifier: "wallet-tab-money") { tab = .money }
                metaNavigationButton("Rewards", symbol: "gift", page: .rewards, identifier: "wallet-tab-rewards") { tab = .rewards }
            }
            .padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 3).background(palette.background)
            .overlay(alignment: .top) { Rectangle().fill(palette.separator).frame(height: 0.5) }
        } else { standardBottomNavigation }
    }
    private func metaNavigationButton(_ title: String, symbol: String, page: WalletPage?, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.system(size: 20, weight: .regular))
                Text(title).font(.system(size: 10, weight: .medium))
            }.foregroundStyle(page == tab ? palette.ink : palette.secondary).frame(maxWidth: .infinity, minHeight: 56).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier(identifier)
    }
    private var standardBottomNavigation: some View {
        HStack {
            ForEach([WalletPage.assets, .activity, .settings]) { page in
                Button { tab = page } label: {
                    VStack(spacing: 5) {
                        Image(systemName: page.symbol).font(.system(size: 20, weight: .medium))
                        Text(page.title).font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(tab == page ? palette.accent : palette.secondary)
                    .frame(maxWidth: .infinity, minHeight: 51).contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityIdentifier("wallet-tab-" + page.rawValue)
                .accessibilityAddTraits(tab == page ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 3)
        .background(palette.background)
        .overlay(alignment: .top) { Rectangle().fill(palette.separator).frame(height: 0.5) }
    }

    private func moneyPage(_ scene: StudioScene) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Money").font(.system(size: 25, weight: .semibold))
                let stablecoins = profile.holdings.filter { ["USDC", "USDT", "DAI"].contains($0.symbol.uppercased()) }
                Text(scene.money(stablecoins.reduce(0) { $0 + $1.value })).font(.system(size: 39, weight: .semibold)).monospacedDigit()
                HStack(spacing: 12) {
                    Button { sheet = .swap(.sell) } label: { Label("Add", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 48).background(palette.card, in: RoundedRectangle(cornerRadius: 13)) }
                    Button { sheet = .send(stablecoins.first?.id) } label: { Label("Transfer", systemImage: "arrow.up.right").frame(maxWidth: .infinity, minHeight: 48).background(palette.card, in: RoundedRectangle(cornerRadius: 13)) }
                }.font(.system(size: 14, weight: .medium)).buttonStyle(.plain)
                Text("Balances").font(.system(size: 19, weight: .semibold))
                if stablecoins.isEmpty { Text("No stablecoin balance").foregroundStyle(palette.secondary) }
                ForEach(stablecoins) { holding in
                    Button { sheet = .token(holding.id) } label: { WalletAssetRow(holding: holding, currency: scene.currency, theme: profile.theme) }.buttonStyle(.plain)
                }
                Button { tab = .activity } label: { HStack { Text("Activity"); Spacer(); Image(systemName: "chevron.right").font(.caption) }.frame(minHeight: 48) }.buttonStyle(.plain)
            }.padding(22).foregroundStyle(palette.ink)
        }.accessibilityIdentifier("wallet-money")
    }
    private var rewardsPage: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "gift").font(.system(size: 54, weight: .light)).foregroundStyle(palette.secondary)
            Text("No rewards yet").font(.system(size: 23, weight: .semibold))
            Button("Wallet overview") { tab = .settings }.font(.system(size: 15, weight: .medium)).frame(minHeight: 44)
            Spacer()
        }.frame(maxWidth: .infinity).foregroundStyle(palette.ink)
    }

    @ViewBuilder private func sheetView(_ destination: WalletDestination, scene: StudioScene) -> some View {
        switch destination {
        case .edit: WalletProfileEditor(sceneID: sceneID)
        case .token(let id): WalletAssetDetail(sceneID: sceneID, assetID: id)
        case .send(let id): WalletTransferSheet(sceneID: sceneID, initialAssetID: id, incoming: false)
        case .receive: WalletReceiveSheet(sceneID: sceneID)
        case .transaction(let id): WalletTransactionDetail(sceneID: sceneID, transactionID: id)
        case .swap(let mode): WalletSwapSheet(sceneID: sceneID, mode: mode)
        case .explore: WalletExploreSheet(sceneID: sceneID)
        }
    }
    private var weightedChange: Double {
        guard profile.fiatValue > 0 else { return 0 }
        return profile.holdings.reduce(0) { $0 + $1.changePercent * $1.value } / profile.fiatValue
    }
    private var portfolioChart: [Double] {
        (0..<14).map { index in
            profile.holdings.reduce(0) { total, holding in
                guard !holding.chart.isEmpty else { return total }
                return total + holding.chart[min(index * holding.chart.count / 14, holding.chart.count - 1)] * holding.value
            }
        }
    }
}

private enum WalletPage: String, CaseIterable, Identifiable {
    case assets, activity, settings, money, rewards
    var id: String { rawValue }
    var title: String { self == .assets ? "Home" : rawValue.capitalized }
    var symbol: String { self == .assets ? "wallet.bifold.fill" : self == .activity ? "clock" : "gearshape" }
}
private enum WalletDestination: Identifiable {
    case edit, token(UUID), send(UUID?), receive, transaction(UUID), swap(WalletSwapMode), explore
    var id: String {
        switch self {
        case .edit: return "edit"
        case .token(let id): return "token-" + id.uuidString
        case .send(let id): return "send-" + (id?.uuidString ?? "pick")
        case .receive: return "receive"
        case .transaction(let id): return "transaction-" + id.uuidString
        case .swap(let mode): return "swap-" + mode.rawValue
        case .explore: return "explore"
        }
    }
}
private struct WalletPalette {
    let theme: WalletTheme
    var accent: Color { theme == .phantom ? Color(red: 0.68, green: 0.61, blue: 0.98) : theme == .trustWallet ? Color(red: 0.03, green: 0.36, blue: 1) : Color(red: 0.12, green: 0.37, blue: 0.89) }
    var background: Color { theme == .phantom ? .black : theme == .metamask ? Color(red: 0.07, green: 0.07, blue: 0.08) : .white }
    var card: Color { theme == .phantom ? Color(red: 0.065, green: 0.065, blue: 0.07) : theme == .metamask ? Color(red: 0.12, green: 0.12, blue: 0.13) : Color(red: 0.96, green: 0.96, blue: 0.97) }
    var ink: Color { theme != .trustWallet ? .white : Color(red: 0.10, green: 0.10, blue: 0.12) }
    var secondary: Color { theme != .trustWallet ? Color(red: 0.62, green: 0.62, blue: 0.65) : Color(red: 0.48, green: 0.48, blue: 0.5) }
    var positive: Color { theme == .metamask ? Color(red: 0.74, green: 0.91, blue: 0.29) : Color(red: 0.12, green: 0.85, blue: 0.39) }
    var separator: Color { theme != .trustWallet ? .white.opacity(0.07) : .black.opacity(0.06) }
}
private func compactAddress(_ address: String) -> String { address.count > 17 ? String(address.prefix(7)) + "…" + String(address.suffix(5)) : address }
private func walletQuantity(_ value: Double) -> String { value.formatted(.number.grouping(.never).precision(.fractionLength(0...12))) }
/// Expands Swift's round-tripping decimal representation so Max never rounds above the
/// saved quantity. Tiny positive quantities retain their digits without exponent syntax.
private func walletMaximumInput(_ quantity: Double, locale: Locale = .current) -> String {
    guard quantity.isFinite, quantity >= 0 else { return "0" }
    let parts = String(quantity).lowercased().split(separator: "e", omittingEmptySubsequences: false)
    let coefficient = String(parts[0])
    let fixed: String
    if parts.count == 2, let exponent = Int(parts[1]) {
        let integerCount = coefficient.split(separator: ".", omittingEmptySubsequences: false)[0].count
        let digits = coefficient.replacingOccurrences(of: ".", with: "")
        let decimalIndex = integerCount + exponent
        if decimalIndex <= 0 {
            fixed = "0." + String(repeating: "0", count: -decimalIndex) + digits
        } else if decimalIndex >= digits.count {
            fixed = digits + String(repeating: "0", count: decimalIndex - digits.count)
        } else {
            fixed = String(digits.prefix(decimalIndex)) + "." + String(digits.dropFirst(decimalIndex))
        }
    } else { fixed = coefficient }
    return fixed.replacingOccurrences(of: ".", with: locale.decimalSeparator ?? ".")
}

private struct WalletBrandMark: View {
    let theme: WalletTheme
    var body: some View {
        Group {
            if let image = UIImage(named: "WalletBrand-" + theme.rawValue) { Image(uiImage: image).resizable().scaledToFit() }
            else {
                Image(systemName: theme == .metamask ? "flame.fill" : theme == .phantom ? "sparkle" : "shield.fill")
                    .resizable().scaledToFit().padding(6)
                    .foregroundStyle(theme == .metamask ? .orange : theme == .phantom ? Color(red: 0.68, green: 0.61, blue: 0.98) : .blue)
                    .background(theme == .phantom ? Color(red: 0.16, green: 0.15, blue: 0.22) : Color.white, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}
private struct WalletTokenMark: View {
    let symbol: String
    var body: some View {
        ZStack {
            Circle().fill(color)
            if symbol.uppercased() == "ETH" {
                Image(systemName: "diamond.fill").font(.system(size: 23)).foregroundStyle(Color(red: 0.34, green: 0.38, blue: 0.51))
            } else if symbol.uppercased() == "SOL" {
                VStack(spacing: 3) {
                    ForEach(0..<3) { _ in Capsule().fill(LinearGradient(colors: [.green, .purple], startPoint: .leading, endPoint: .trailing)).frame(width: 23, height: 5).rotationEffect(.degrees(-15)) }
                }
            } else {
                Text(symbol.uppercased() == "BTC" ? "₿" : symbol.uppercased().hasPrefix("USD") ? "$" : String(symbol.prefix(1)))
                    .font(.system(size: 23, weight: .semibold)).foregroundStyle(.white)
            }
        }.frame(width: 44, height: 44).accessibilityHidden(true)
    }
    private var color: Color {
        switch symbol.uppercased() {
        case "BTC": return Color(red: 0.97, green: 0.57, blue: 0.08)
        case "ETH": return Color(red: 0.9, green: 0.91, blue: 0.97)
        case "SOL": return .black
        case "USDC": return Color(red: 0.14, green: 0.47, blue: 0.86)
        default: return Color(red: 0.46, green: 0.45, blue: 0.86)
        }
    }
}
private struct WalletAssetRow: View {
    let holding: WalletHolding
    let currency: String
    let theme: WalletTheme
    private var palette: WalletPalette { WalletPalette(theme: theme) }
    var body: some View {
        HStack(spacing: 13) {
            WalletTokenMark(symbol: holding.symbol)
            VStack(alignment: .leading, spacing: 6) {
                Text(holding.name).font(.system(size: 15, weight: .semibold))
                if theme != .trustWallet {
                    Text(walletQuantity(holding.quantity) + " " + holding.symbol).font(.system(size: 12)).foregroundStyle(palette.secondary)
                } else {
                    HStack(spacing: 5) {
                        Text(holding.price.formatted(.currency(code: currency))).foregroundStyle(palette.secondary)
                        Text((holding.changePercent >= 0 ? "+" : "") + holding.changePercent.formatted(.number.precision(.fractionLength(2))) + "%")
                            .foregroundStyle(holding.changePercent >= 0 ? palette.positive : .red)
                    }.font(.system(size: 11))
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(holding.value.formatted(.currency(code: currency))).font(.system(size: 15, weight: .semibold))
                if theme == .trustWallet {
                    Text(walletQuantity(holding.quantity) + " " + holding.symbol).font(.system(size: 11)).foregroundStyle(palette.secondary)
                } else {
                    Text((holding.changePercent >= 0 ? "+" : "") + (theme == .metamask
                        ? holding.changePercent.formatted(.number.precision(.fractionLength(2))) + "%"
                        : (holding.value * holding.changePercent / 100).formatted(.currency(code: currency))))
                        .font(.system(size: 12)).foregroundStyle(holding.changePercent >= 0 ? palette.positive : .red)
                }
            }
        }
        .foregroundStyle(palette.ink).padding(.vertical, 15).padding(.horizontal, theme == .phantom ? 14 : 0)
        .background(theme == .phantom ? palette.card : .clear, in: RoundedRectangle(cornerRadius: 17))
        .contentShape(Rectangle())
    }
}
private struct WalletMiniChart: View {
    let values: [Double]
    let color: Color
    var body: some View {
        Chart(Array(values.enumerated()), id: \.offset) { entry in
            AreaMark(x: .value("Time", entry.offset), y: .value("Value", entry.element))
                .interpolationMethod(.catmullRom).foregroundStyle(LinearGradient(colors: [color.opacity(0.15), color.opacity(0)], startPoint: .top, endPoint: .bottom))
            LineMark(x: .value("Time", entry.offset), y: .value("Value", entry.element))
                .interpolationMethod(.catmullRom).foregroundStyle(color).lineStyle(StrokeStyle(lineWidth: 2))
        }
        .chartXAxis(.hidden).chartYAxis(.hidden)
        .chartYScale(domain: min(values.min() ?? 0, 0)...max(values.max() ?? 1, 1))
    }
}

private struct WalletAssetDetail: View {
    let sceneID: UUID
    let assetID: UUID
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @State private var range: WalletChartRange = .week
    @State private var sending = false
    @State private var receiving = false
    private var profile: WalletProfile { store.walletProfile(for: sceneID) }
    private var holding: WalletHolding? { profile.holdings.first { $0.id == assetID } }
    private var scene: StudioScene? { store.scenes.first { $0.id == sceneID } }
    private var palette: WalletPalette { WalletPalette(theme: profile.theme) }
    var body: some View {
        NavigationStack {
            Group {
                if let holding, let scene {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 23) {
                            HStack(spacing: 12) {
                                WalletTokenMark(symbol: holding.symbol)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(holding.name).font(.system(size: 22, weight: .semibold))
                                    Text(holding.network).font(.system(size: 12)).foregroundStyle(palette.secondary)
                                }
                            }
                            VStack(alignment: .leading, spacing: 7) {
                                Text(scene.money(holding.price)).font(.system(size: 36, weight: .semibold))
                                Text((holding.changePercent >= 0 ? "+" : "") + holding.changePercent.formatted(.number.precision(.fractionLength(2))) + "%")
                                    .font(.system(size: 14, weight: .medium)).foregroundStyle(holding.changePercent >= 0 ? palette.positive : .red)
                            }
                            WalletMiniChart(values: chartValues(holding), color: palette.accent).frame(height: 180)
                                .accessibilityLabel("\(holding.name) price chart, \(range.title)")
                            Picker("Chart period", selection: $range) {
                                ForEach(WalletChartRange.allCases) { Text($0.title).tag($0) }
                            }.pickerStyle(.segmented)
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Your balance").font(.system(size: 13)).foregroundStyle(palette.secondary)
                                HStack {
                                    Text(walletQuantity(holding.quantity) + " " + holding.symbol).font(.system(size: 21, weight: .semibold))
                                    Spacer()
                                    Text(scene.money(holding.value)).font(.system(size: 15)).foregroundStyle(palette.secondary)
                                }
                                HStack(spacing: 12) {
                                    Button { sending = true } label: { Label("Send", systemImage: "arrow.up.right").frame(maxWidth: .infinity, minHeight: 44) }
                                        .buttonStyle(.borderedProminent)
                                        .accessibilityIdentifier("wallet-token-send")
                                    Button { receiving = true } label: { Label("Receive", systemImage: "arrow.down.left").frame(maxWidth: .infinity, minHeight: 44) }
                                        .buttonStyle(.bordered)
                                }
                            }
                            .padding(18).background(palette.card, in: RoundedRectangle(cornerRadius: 20))
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Recent activity").font(.system(size: 17, weight: .semibold))
                                let transactions = profile.transactions.filter { $0.assetID == assetID }.sorted { $0.date > $1.date }
                                if transactions.isEmpty {
                                    Text("No activity for this asset yet.").font(.system(size: 14)).foregroundStyle(palette.secondary)
                                } else {
                                    ForEach(transactions.prefix(10)) { transaction in
                                        HStack {
                                            Text(transaction.kind == .send ? "Sent" : "Received").font(.system(size: 14, weight: .medium))
                                            Spacer()
                                            Text(walletQuantity(transaction.quantity) + " " + transaction.symbol).font(.system(size: 13))
                                        }
                                    }
                                }
                            }
                        }
                        .padding(22).foregroundStyle(palette.ink)
                    }
                } else { ContentUnavailableView("Asset unavailable", systemImage: "bitcoinsign.circle") }
            }
            .background(palette.background)
            .navigationTitle(holding?.symbol ?? "Asset").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $sending) { WalletTransferSheet(sceneID: sceneID, initialAssetID: assetID, incoming: false) }
            .sheet(isPresented: $receiving) { WalletReceiveSheet(sceneID: sceneID, initialAssetID: assetID) }
        }
        .tint(palette.accent).preferredColorScheme(profile.theme == .trustWallet ? .light : .dark)
        .accessibilityIdentifier("wallet-token-detail")
    }
    private func chartValues(_ holding: WalletHolding) -> [Double] {
        let values = range == .day ? Array(holding.chart.suffix(4)) : range == .week ? Array(holding.chart.suffix(7)) : holding.chart
        return values.map { $0 * holding.price }
    }
}
private enum WalletChartRange: String, CaseIterable, Identifiable {
    case day, week, month
    var id: String { rawValue }
    var title: String { self == .day ? "1D" : self == .week ? "1W" : "1M" }
}

private struct WalletReceiveSheet: View {
    let sceneID: UUID
    let initialAssetID: UUID?
    init(sceneID: UUID, initialAssetID: UUID? = nil) { self.sceneID = sceneID; self.initialAssetID = initialAssetID }
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false
    @State private var recording = false
    @State private var selectedAssetID: UUID?
    private var profile: WalletProfile { store.walletProfile(for: sceneID) }
    private var palette: WalletPalette { WalletPalette(theme: profile.theme) }
    private var selectedHolding: WalletHolding? { profile.holdings.first { $0.id == selectedAssetID } }
    private var address: String { selectedHolding?.address ?? profile.address }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 23) {
                    WalletBrandMark(theme: profile.theme).frame(width: 48, height: 48)
                    Text("Receive crypto").font(.system(size: 26, weight: .semibold))
                    Picker("Asset", selection: $selectedAssetID) {
                        ForEach(profile.holdings) { Text($0.name + " · " + $0.network).tag(Optional($0.id)) }
                    }.pickerStyle(.menu).frame(minHeight: 44)
                    if let qr = walletQR(address) {
                        Image(uiImage: qr).interpolation(.none).resizable().scaledToFit().padding(15)
                            .frame(width: 230, height: 230).background(Color.white, in: RoundedRectangle(cornerRadius: 22))
                            .accessibilityLabel("Wallet address QR code")
                    }
                    Text(address).font(.system(size: 13, design: .monospaced)).multilineTextAlignment(.center).textSelection(.enabled)
                        .padding(18).frame(maxWidth: .infinity).background(palette.card, in: RoundedRectangle(cornerRadius: 16))
                    HStack(spacing: 15) {
                        Button {
                            UIPasteboard.general.string = address
                            copied = true
                        } label: { Label(copied ? "Copied" : "Copy address", systemImage: copied ? "checkmark" : "doc.on.doc").frame(maxWidth: .infinity, minHeight: 44) }
                        .buttonStyle(.borderedProminent).accessibilityIdentifier("wallet-copy-address")
                        ShareLink(item: address) { Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44) }
                            .buttonStyle(.bordered).accessibilityLabel("Share address")
                    }
                    Text("Address only. Choose the asset’s matching network when entering a transfer.")
                        .font(.system(size: 13)).foregroundStyle(palette.secondary).multilineTextAlignment(.center)
                    Button { recording = true } label: {
                        Text("Add received assets").font(.system(size: 15, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered).accessibilityIdentifier("wallet-record-receive")
                }
                .padding(24).foregroundStyle(palette.ink)
            }
            .background(palette.background)
            .navigationTitle("Receive").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $recording) { WalletTransferSheet(sceneID: sceneID, initialAssetID: selectedAssetID, incoming: true) }
            .onAppear { if selectedAssetID == nil { selectedAssetID = initialAssetID ?? profile.holdings.first?.id } }
            .onChange(of: selectedAssetID) { _, _ in copied = false }
        }
        .tint(palette.accent).preferredColorScheme(profile.theme == .trustWallet ? .light : .dark)
        .accessibilityIdentifier("wallet-receive-sheet")
    }
}
private func walletQR(_ address: String) -> UIImage? {
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(address.utf8)
    filter.correctionLevel = "M"
    guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
          let image = CIContext().createCGImage(output, from: output.extent) else { return nil }
    return UIImage(cgImage: image)
}

private struct WalletTransferSheet: View {
    let sceneID: UUID
    let initialAssetID: UUID?
    let incoming: Bool
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @State private var assetID: UUID?
    @State private var address = ""
    @State private var amount = ""
    @State private var reviewing = false
    @State private var result: WalletTransaction?
    @State private var submitting = false
    @FocusState private var editing: Bool
    private var profile: WalletProfile { store.walletProfile(for: sceneID) }
    private var scene: StudioScene? { store.scenes.first { $0.id == sceneID } }
    private var holding: WalletHolding? { profile.holdings.first { $0.id == assetID } }
    private var palette: WalletPalette { WalletPalette(theme: profile.theme) }
    private var quantity: Double? { Simulation.parseAmount(amount) }
    private var valid: Bool {
        guard let holding, let quantity, quantity.isFinite, quantity > 0, quantity <= 1_000_000_000,
              incoming || quantity <= holding.quantity else { return false }
        let destination = address.trimmingCharacters(in: .whitespacesAndNewlines)
        return MarketValidation.address(destination) && MarketValidation.nonnegative(quantity * holding.price)
            && (!incoming || MarketValidation.quantity(holding.quantity + quantity))
            && MarketValidation.nonnegative(incoming ? profile.fiatValue + quantity * holding.price : profile.fiatValue - quantity * holding.price)
    }
    var body: some View {
        NavigationStack {
            Group {
                if let result { completed(result) }
                else if reviewing, let holding, let scene { review(holding, scene: scene) }
                else { form }
            }
            .navigationTitle(result != nil ? "Complete" : reviewing ? "Review transfer" : incoming ? "Receive" : "Send")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(result != nil ? "Done" : reviewing ? "Back" : "Cancel") {
                        if reviewing && result == nil { reviewing = false } else { dismiss() }
                    }
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { editing = false } }
            }
            .onAppear {
                if assetID == nil { assetID = initialAssetID ?? profile.holdings.first?.id }
                if incoming && address.isEmpty { address = holding?.address ?? profile.address }
            }
            .onChange(of: assetID) { _, _ in if incoming { address = holding?.address ?? profile.address } }
        }
        .tint(palette.accent).preferredColorScheme(profile.theme == .trustWallet ? .light : .dark)
        .accessibilityIdentifier("wallet-transfer-sheet")
    }
    private var form: some View {
        Form {
            Section("Asset") {
                Picker("Token", selection: $assetID) {
                    ForEach(profile.holdings) { holding in Text(holding.name + " (" + holding.symbol + ")").tag(Optional(holding.id)) }
                }
                if let holding { LabeledContent("Available", value: walletQuantity(holding.quantity) + " " + holding.symbol) }
            }
            Section(incoming ? "Address" : "Recipient") {
                if incoming { Text(address).font(.system(size: 12, design: .monospaced)).textSelection(.enabled) }
                else { TextField("Public wallet address", text: $address).textInputAutocapitalization(.never).autocorrectionDisabled().focused($editing).accessibilityIdentifier("wallet-recipient") }
                if let holding { LabeledContent("Network", value: holding.network) }
            }
            Section("Amount") {
                TextField(holding?.symbol ?? "Amount", text: $amount).keyboardType(.decimalPad).focused($editing).accessibilityIdentifier("wallet-transfer-amount")
                if let holding, let scene, let quantity { Text(scene.money(quantity * holding.price)).font(.subheadline).foregroundStyle(.secondary) }
                if !incoming, let holding {
                    Button("Use maximum") { amount = walletMaximumInput(holding.quantity) }
                        .frame(minHeight: 44).accessibilityIdentifier("wallet-use-max")
                }
            }
            Section {
                Button { editing = false; reviewing = true } label: {
                    Text("Review transfer").frame(maxWidth: .infinity, minHeight: 44)
                }
                .disabled(!valid).accessibilityIdentifier("wallet-review-transfer")
            }
            if let error = store.error { Section { Text(error).foregroundStyle(.red) } }
        }
    }
    private func review(_ holding: WalletHolding, scene: StudioScene) -> some View {
        VStack(spacing: 24) {
            WalletTokenMark(symbol: holding.symbol).padding(.top, 25)
            VStack(spacing: 7) {
                Text(walletQuantity(quantity ?? 0) + " " + holding.symbol).font(.system(size: 29, weight: .semibold)).minimumScaleFactor(0.7).lineLimit(1)
                Text(scene.money((quantity ?? 0) * holding.price)).font(.system(size: 16)).foregroundStyle(palette.secondary)
            }
            VStack(alignment: .leading, spacing: 18) {
                LabeledContent("Network", value: holding.network)
                VStack(alignment: .leading, spacing: 7) {
                    Text(incoming ? "Wallet address" : "To").font(.caption).foregroundStyle(palette.secondary)
                    Text(address).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                }
                LabeledContent("Network fee", value: "0 " + holding.symbol)
            }
            .font(.system(size: 14)).padding(20).background(palette.card, in: RoundedRectangle(cornerRadius: 20))
            if let error = store.error { Text(error).font(.footnote).foregroundStyle(.red) }
            Spacer()
            Button(action: confirm) {
                Text(incoming ? "Confirm received assets" : "Confirm send").font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent).disabled(!valid || submitting)
            .accessibilityIdentifier("wallet-confirm-transfer")
        }
        .padding(24).foregroundStyle(palette.ink).background(palette.background)
    }
    private func completed(_ transaction: WalletTransaction) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill").font(.system(size: 65)).foregroundStyle(palette.positive)
            Text(incoming ? "Assets received" : "Transfer complete").font(.system(size: 27, weight: .semibold))
                .accessibilityIdentifier("wallet-transfer-complete")
            Text(walletQuantity(transaction.quantity) + " " + transaction.symbol).font(.system(size: 21))
            Text(compactAddress(transaction.address)).font(.system(size: 13, design: .monospaced)).foregroundStyle(palette.secondary)
            Spacer()
            Button("Done") { dismiss() }.buttonStyle(.borderedProminent).frame(minHeight: 44)
        }
        .padding(24).foregroundStyle(palette.ink).frame(maxWidth: .infinity).background(palette.background)
    }
    private func confirm() {
        guard result == nil, valid, !submitting, let holding, let quantity else { return }
        submitting = true
        defer { submitting = false }
        result = store.walletTransfer(sceneID: sceneID, assetID: holding.id, kind: incoming ? .receive : .send, quantity: quantity,
                                      address: address.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

private struct WalletTransactionDetail: View {
    let sceneID: UUID
    let transactionID: UUID
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    private var profile: WalletProfile { store.walletProfile(for: sceneID) }
    private var transaction: WalletTransaction? { profile.transactions.first { $0.id == transactionID } }
    var body: some View {
        NavigationStack {
            Group {
                if let transaction {
                    Form {
                        Section {
                            VStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 45)).foregroundStyle(.green)
                                Text(transaction.kind.title).font(.title2.weight(.semibold))
                                Text(walletQuantity(transaction.quantity) + " " + transaction.symbol).font(.title3)
                            }.frame(maxWidth: .infinity).padding(.vertical, 16)
                        }
                        Section("Details") {
                            LabeledContent("Status", value: "Completed")
                            LabeledContent("Network", value: transaction.network)
                            LabeledContent("Date", value: transaction.date.formatted(date: .abbreviated, time: .shortened))
                            if let scene = store.scenes.first(where: { $0.id == sceneID }) { LabeledContent("Value", value: scene.money(transaction.value)) }
                        }
                        Section(transaction.kind == .send ? "To" : "Address") {
                            Text(transaction.address).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                            Button("Copy address") { UIPasteboard.general.string = transaction.address }.frame(minHeight: 44)
                        }
                    }
                } else { ContentUnavailableView("Transaction unavailable", systemImage: "clock") }
            }
            .navigationTitle("Transaction").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .tint(WalletPalette(theme: profile.theme).accent).preferredColorScheme(profile.theme == .trustWallet ? .light : .dark)
    }
}

private struct WalletProfileEditor: View {
    let sceneID: UUID
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: WalletProfile?
    @State private var editingAsset: WalletHolding?
    @State private var addingAsset = false
    private var profile: WalletProfile { draft ?? store.walletProfile(for: sceneID) }
    var body: some View {
        NavigationStack {
            Form {
                Section("Wallet") {
                    Picker("Style", selection: Binding(get: { profile.theme }, set: { draft?.theme = $0 })) {
                        ForEach(WalletTheme.allCases) { Text($0.name).tag($0) }
                    }.accessibilityIdentifier("wallet-theme-picker")
                    TextField("Public address", text: Binding(get: { profile.address }, set: { draft?.address = $0 }))
                        .textInputAutocapitalization(.never).autocorrectionDisabled().font(.system(size: 13, design: .monospaced))
                }
                Section("Assets") {
                    ForEach(profile.holdings) { holding in
                        Button { editingAsset = holding } label: {
                            HStack {
                                WalletTokenMark(symbol: holding.symbol).scaleEffect(0.75).frame(width: 35, height: 35)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(holding.name).font(.system(size: 15, weight: .medium))
                                    Text(walletQuantity(holding.quantity) + " " + holding.symbol).font(.system(size: 12)).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(.secondary)
                            }.frame(minHeight: 44)
                        }
                    }
                    Button { addingAsset = true } label: { Label("Add asset", systemImage: "plus").frame(minHeight: 44) }.disabled(profile.holdings.count >= 100)
                    if Set(profile.holdings.map { $0.symbol.uppercased() }).count != profile.holdings.count {
                        Text("Give each asset a unique symbol.").font(.footnote).foregroundStyle(.red)
                    }
                }
                if let error = store.error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("Wallet settings").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard var draft else { return }
                        draft.address = draft.address.trimmingCharacters(in: .whitespacesAndNewlines)
                        // Retain transfers recorded while this settings sheet was open.
                        draft.transactions = store.walletProfile(for: sceneID).transactions
                        if store.updateWalletProfile(draft) { dismiss() }
                    }.disabled(!profile.isValid || draft == nil)
                }
            }
            .onAppear { if draft == nil { draft = store.walletProfile(for: sceneID) } }
            .sheet(item: $editingAsset) { asset in
                WalletHoldingEditor(holding: asset) { updated in
                    if let index = draft?.holdings.firstIndex(where: { $0.id == updated.id }) { draft?.holdings[index] = updated }
                }
            }
            .sheet(isPresented: $addingAsset) {
                WalletHoldingEditor(holding: WalletHolding(symbol: "TOKEN", name: "New token", network: "Ethereum", quantity: 0,
                                                          price: 1, changePercent: 0, chart: [0.4, 0.5, 0.65, 0.6, 0.8, 0.75, 1], address: nil)) { updated in
                    draft?.holdings.append(updated)
                }
            }
        }
        .preferredColorScheme(.light)
        .accessibilityIdentifier("wallet-profile-editor")
    }
}
private struct WalletHoldingEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var holding: WalletHolding
    let onSave: (WalletHolding) -> Void
    @State private var quantity = ""
    @State private var price = ""
    @State private var change = ""
    @State private var address = ""
    @State private var chart = ""
    @State private var loaded = false
    @FocusState private var editing: Bool
    private var parsedChart: [Double]? {
        let fields = chart.split(separator: ",", omittingEmptySubsequences: false)
        let values = fields.compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return values.count == fields.count && MarketValidation.chart(values) ? values : nil
    }
    private var updated: WalletHolding? {
        guard let quantity = Simulation.parseAmount(quantity), let price = Simulation.parseAmount(price),
              let change = Double(change.replacingOccurrences(of: Locale.current.decimalSeparator ?? ".", with: ".")), let chart = parsedChart else { return nil }
        var result = holding
        result.symbol = holding.symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        result.name = holding.name.trimmingCharacters(in: .whitespacesAndNewlines)
        result.network = holding.network.trimmingCharacters(in: .whitespacesAndNewlines)
        result.quantity = quantity; result.price = price; result.changePercent = change; result.chart = chart
        result.address = address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : address.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isValid ? result : nil
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Token") {
                    TextField("Name", text: $holding.name).focused($editing)
                    TextField("Symbol", text: $holding.symbol).textInputAutocapitalization(.characters).autocorrectionDisabled().focused($editing)
                    TextField("Network", text: $holding.network).focused($editing)
                }
                Section("Balance and price") {
                    numeric("Quantity", text: $quantity)
                    numeric("Price", text: $price)
                    numeric("Daily change (%)", text: $change, signed: true)
                }
                Section {
                    TextField("Public address (optional)", text: $address).font(.system(size: 12, design: .monospaced))
                        .textInputAutocapitalization(.never).autocorrectionDisabled().focused($editing)
                } header: { Text("Receive address") } footer: {
                    Text("Use public address metadata. Leave empty to use the wallet address.")
                }
                Section {
                    TextField("Chart values", text: $chart, axis: .vertical).keyboardType(.numbersAndPunctuation).lineLimit(3...6).focused($editing)
                } header: { Text("Chart shape") } footer: {
                    Text("Enter 2–120 comma-separated values between 0 and 1. Use a period for decimals.")
                }
            }
            .navigationTitle("Edit asset").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { if let updated { onSave(updated); dismiss() } }.disabled(updated == nil) }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { editing = false } }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                quantity = holding.quantity.formatted(.number.grouping(.never).precision(.fractionLength(0...12)))
                price = holding.price.formatted(.number.grouping(.never).precision(.fractionLength(0...12)))
                change = holding.changePercent.formatted(.number.grouping(.never))
                address = holding.address ?? ""
                chart = holding.chart.map { String($0) }.joined(separator: ", ")
            }
        }
    }
    private func numeric(_ title: String, text: Binding<String>, signed: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(title, text: text).keyboardType(signed ? .numbersAndPunctuation : .decimalPad).focused($editing)
        }
    }
}

private enum WalletSwapMode: String {
    case swap, buy, sell
    var title: String { self == .swap ? "Swap" : self == .buy ? "Buy crypto" : "Sell crypto" }
}
private struct WalletSwapSheet: View {
    let sceneID: UUID
    let mode: WalletSwapMode
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @State private var fromID: UUID?
    @State private var toID: UUID?
    @State private var amount = ""
    @State private var reviewing = false
    @State private var completed = false
    @State private var completedQuantity: Double?
    @State private var completedSymbol = ""
    @FocusState private var editing: Bool
    private var profile: WalletProfile { store.walletProfile(for: sceneID) }
    private var palette: WalletPalette { WalletPalette(theme: profile.theme) }
    private var from: WalletHolding? { profile.holdings.first { $0.id == fromID } }
    private var to: WalletHolding? { profile.holdings.first { $0.id == toID } }
    private var quantity: Double? { Simulation.parseAmount(amount) }
    private var received: Double? {
        guard let quantity, let from, let to else { return nil }
        return quantity * from.price / to.price
    }
    private var valid: Bool {
        guard let from, let to, from.id != to.id, let quantity, let received,
              MarketValidation.quantity(quantity, allowZero: false), quantity <= from.quantity,
              MarketValidation.quantity(received, allowZero: false), MarketValidation.quantity(to.quantity + received),
              MarketValidation.nonnegative((to.quantity + received) * to.price) else { return false }
        return true
    }
    var body: some View {
        NavigationStack {
            Group {
                if completed { completion }
                else if reviewing { review }
                else { entry }
            }
            .navigationTitle(completed ? "Complete" : reviewing ? "Review " + mode.rawValue : mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(completed ? "Done" : reviewing ? "Back" : "Cancel") {
                        if reviewing && !completed { reviewing = false } else { dismiss() }
                    }
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { editing = false } }
            }
            .onAppear(perform: selectAssets)
        }
        .tint(palette.accent).preferredColorScheme(profile.theme == .trustWallet ? .light : .dark)
        .accessibilityIdentifier("wallet-swap-sheet")
    }
    private var entry: some View {
        VStack(spacing: 16) {
            assetCard(receiving: false)
            Button {
                let previous = fromID; fromID = toID; toID = previous; amount = ""
            } label: {
                Image(systemName: "arrow.up.arrow.down").font(.system(size: 21, weight: .semibold))
                    .frame(width: 44, height: 44).background(palette.card, in: Circle())
            }.buttonStyle(.plain).accessibilityLabel("Reverse assets")
            assetCard(receiving: true)
            if let from, let to {
                Text("1 " + from.symbol + " = " + walletQuantity(from.price / to.price) + " " + to.symbol)
                    .font(.system(size: 12)).foregroundStyle(palette.secondary)
            }
            if let error = store.error { Text(error).font(.footnote).foregroundStyle(.red) }
            Spacer()
            Button { editing = false; reviewing = true } label: {
                Text("Review " + mode.rawValue).font(.system(size: 16, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent).disabled(!valid).accessibilityIdentifier("wallet-review-swap")
        }
        .padding(22).foregroundStyle(palette.ink).background(palette.background)
    }
    private func assetCard(receiving: Bool) -> some View {
        VStack(alignment: .leading, spacing: 17) {
            Text(receiving ? "You receive" : "You pay").font(.system(size: 13)).foregroundStyle(palette.secondary)
            HStack {
                if let holding = receiving ? to : from { WalletTokenMark(symbol: holding.symbol) }
                Picker(receiving ? "To asset" : "From asset", selection: receiving ? $toID : $fromID) {
                    ForEach(profile.holdings) { Text($0.symbol).tag(Optional($0.id)) }
                }.pickerStyle(.menu).font(.system(size: 16, weight: .semibold)).frame(minHeight: 44)
                Spacer()
                if receiving {
                    Text(walletQuantity(received ?? 0)).font(.system(size: 25, weight: .semibold)).minimumScaleFactor(0.6).lineLimit(1)
                } else {
                    TextField("0", text: $amount).keyboardType(.decimalPad).focused($editing)
                        .font(.system(size: 25, weight: .semibold)).multilineTextAlignment(.trailing)
                        .accessibilityIdentifier("wallet-swap-amount")
                }
            }
            if let holding = receiving ? to : from {
                HStack {
                    Text("Balance: " + walletQuantity(holding.quantity)).font(.system(size: 12)).foregroundStyle(palette.secondary)
                    Spacer()
                    if !receiving {
                        Button("Max") { amount = walletMaximumInput(holding.quantity) }
                            .font(.system(size: 12, weight: .semibold)).frame(minWidth: 44, minHeight: 44)
                    }
                }
            }
        }
        .padding(18).background(palette.card, in: RoundedRectangle(cornerRadius: 20))
    }
    private var review: some View {
        VStack(spacing: 25) {
            Spacer()
            HStack(spacing: 25) {
                if let from { WalletTokenMark(symbol: from.symbol) }
                Image(systemName: "arrow.right").font(.title2)
                if let to { WalletTokenMark(symbol: to.symbol) }
            }
            Text(walletQuantity(quantity ?? 0) + " " + (from?.symbol ?? ""))
                .font(.system(size: 25, weight: .semibold))
            Text("Receive " + walletQuantity(received ?? 0) + " " + (to?.symbol ?? ""))
                .font(.system(size: 18)).foregroundStyle(palette.secondary)
            VStack(spacing: 16) {
                if let from { LabeledContent("From", value: from.network) }
                if let to { LabeledContent("To", value: to.network) }
                LabeledContent("Fee", value: "0")
                LabeledContent("Status", value: "Ready to confirm")
            }
            .font(.system(size: 14)).padding(20).background(palette.card, in: RoundedRectangle(cornerRadius: 20))
            if let error = store.error { Text(error).font(.footnote).foregroundStyle(.red) }
            Spacer()
            Button(action: confirm) {
                Text("Confirm " + mode.rawValue).font(.system(size: 16, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent).disabled(!valid).accessibilityIdentifier("wallet-confirm-swap")
        }
        .padding(24).foregroundStyle(palette.ink).background(palette.background)
    }
    private var completion: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "checkmark.circle.fill").font(.system(size: 65)).foregroundStyle(palette.positive)
            Text("Swap complete").font(.system(size: 28, weight: .semibold)).accessibilityIdentifier("wallet-swap-complete")
            Text(walletQuantity(completedQuantity ?? 0) + " " + completedSymbol).font(.system(size: 20))
            Spacer()
            Button("Done") { dismiss() }.buttonStyle(.borderedProminent).frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity).padding(24).foregroundStyle(palette.ink).background(palette.background)
    }
    private func selectAssets() {
        guard fromID == nil else { return }
        let stable = profile.holdings.first { ["USDC", "USDT", "DAI"].contains($0.symbol.uppercased()) }
        let crypto = profile.holdings.first { $0.id != stable?.id }
        if mode == .buy { fromID = stable?.id ?? profile.holdings.first?.id; toID = crypto?.id }
        else if mode == .sell { fromID = crypto?.id; toID = stable?.id ?? profile.holdings.last?.id }
        else { fromID = profile.holdings.first?.id; toID = profile.holdings.dropFirst().first?.id }
    }
    private func confirm() {
        guard !completed, valid, let from, let to, let quantity else { return }
        let amountReceived = received
        if store.swapWallet(sceneID: sceneID, fromAssetID: from.id, toAssetID: to.id, quantity: quantity) {
            completedQuantity = amountReceived; completedSymbol = to.symbol; completed = true
        }
    }
}

private struct WalletExploreSheet: View {
    let sceneID: UUID
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selected: WalletHolding?
    private var profile: WalletProfile { store.walletProfile(for: sceneID) }
    private var holdings: [WalletHolding] {
        profile.holdings.filter { query.isEmpty || "\($0.symbol) \($0.name) \($0.network)".localizedCaseInsensitiveContains(query) }
    }
    var body: some View {
        NavigationStack {
            List {
                if holdings.isEmpty { ContentUnavailableView.search(text: query) }
                ForEach(holdings) { holding in
                    Button { selected = holding } label: {
                        WalletAssetRow(holding: holding, currency: store.scenes.first { $0.id == sceneID }?.currency ?? "USD", theme: profile.theme)
                    }.buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search tokens")
            .navigationTitle("Explore").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $selected) { WalletAssetDetail(sceneID: sceneID, assetID: $0.id) }
        }
        .tint(WalletPalette(theme: profile.theme).accent).preferredColorScheme(profile.theme == .trustWallet ? .light : .dark)
    }
}
