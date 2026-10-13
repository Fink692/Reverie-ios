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
    @State private var trustSection: TrustWalletSection = .crypto
    @State private var showTrustRewards = true
    @State private var copiedAddress = false
    @FocusState private var searchFocused: Bool

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
                if profile.theme == .phantom { Button(hiddenBalance ? "Show balance" : "Hide balance") { hiddenBalance.toggle() } }
                Button("Close scene") { dismiss() }
                Button("Cancel", role: .cancel) { }
            }
            .alert("Unable to update wallet", isPresented: Binding(get: { store.error != nil && sheet?.id == nil }, set: { if !$0 { store.error = nil } })) {
                Button("OK") { store.error = nil }
            } message: { Text(store.error ?? "") }
            .onChange(of: scene?.kind) { _, kind in if kind != .wallet { dismiss() } }
            .overlay(alignment: .bottom) {
                if copiedAddress {
                    Text("Address copied").font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 18).padding(.vertical, 12)
                        .foregroundStyle(palette.ink).background(palette.card, in: Capsule())
                        .padding(.bottom, profile.theme == .phantom ? 20 : 85)
                        .accessibilityIdentifier("wallet-address-copied")
                }
            }
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
                Text(tab == .assets ? "Home" : tab.title).font(.system(size: 19, weight: .semibold))
                Spacer()
                Button { tab = .activity } label: { Image(systemName: "bell.fill").font(.system(size: 18)).foregroundStyle(palette.secondary).frame(width: 44, height: 44) }.accessibilityLabel("Activity")
            } else {
                Spacer()
                Button { tab = .activity } label: { Image(systemName: "clock").font(.system(size: 21)).frame(width: 44, height: 44) }.accessibilityLabel("Activity")
                Button { copyAddress() } label: { Image(systemName: "square.on.square").font(.system(size: 21)).frame(width: 44, height: 44) }.accessibilityLabel("Copy wallet address")
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
                if profile.theme == .trustWallet { Image(systemName: "gearshape.fill").font(.system(size: 21)).foregroundStyle(palette.secondary).frame(width: 44, height: 44) }
                else if profile.theme == .phantom { PhantomAccountAvatar().frame(width: 40, height: 40).frame(width: 44, height: 44) }
                else {
                    Text("Account 1").font(.system(size: 15, weight: .semibold)).lineLimit(1)
                    Image(systemName: "chevron.down").font(.system(size: 11))
                }
            }.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Wallet profile and close scene").accessibilityIdentifier("wallet-profile-menu")
    }

    private func assetPage(_ scene: StudioScene) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: profile.theme == .phantom ? 22 : 18) {
                if profile.theme == .trustWallet { trustSearchField }
                balanceHeader(scene)
                if profile.theme != .phantom { actionRow }
                stablecoinCard(scene)
                if profile.theme == .trustWallet {
                    if showTrustRewards { trustRewardsBanner }
                    trustSectionPicker
                } else {
                    HStack {
                        if profile.theme == .metamask {
                            Button { sheet = .edit } label: {
                                HStack(spacing: 8) { Text("Tokens").font(.system(size: 18, weight: .semibold)); Image(systemName: "chevron.right").font(.system(size: 14)).foregroundStyle(palette.secondary) }
                                    .frame(minHeight: 44)
                            }.buttonStyle(.plain)
                        } else { Text("Tokens").font(.system(size: 23, weight: .semibold)) }
                        Spacer()
                    }
                }
                if profile.theme == .trustWallet && trustSection == .nfts {
                    trustCollectibles
                } else if holdings.isEmpty {
                    ContentUnavailableView("No assets", systemImage: "bitcoinsign.circle", description: Text("Manage your assets to add a token."))
                } else {
                    LazyVStack(spacing: profile.theme == .phantom ? 9 : 0) {
                        ForEach(holdings) { holding in
                            Button { sheet = .token(holding.id) } label: {
                                WalletAssetRow(holding: holding, currency: scene.currency, theme: profile.theme)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("wallet-asset-" + holding.symbol.lowercased())
                            if profile.theme == .trustWallet && holding.id != holdings.last?.id {
                                Divider().overlay(palette.separator).padding(.leading, 59)
                            }
                        }
                    }
                }
                if profile.theme != .trustWallet || trustSection == .crypto {
                    Button { sheet = .edit } label: {
                        Label(profile.theme == .metamask ? "Manage tokens" : "Manage assets", systemImage: "plus")
                            .font(.system(size: 14, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 44)
                    }.buttonStyle(.plain).padding(.bottom, 10)
                }
            }
            .padding(.horizontal, profile.theme == .trustWallet ? 16 : 20).padding(.top, profile.theme == .phantom ? 6 : 14)
            .foregroundStyle(palette.ink)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("wallet-assets")
    }

    private func balanceHeader(_ scene: StudioScene) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if profile.theme == .trustWallet {
                HStack(spacing: 3) {
                    Button { hiddenBalance.toggle() } label: {
                        Group {
                            if hiddenBalance { Image(systemName: "eye.slash.fill").font(.system(size: 16)) }
                            else { TrustEyeMark().frame(width: 21, height: 17) }
                        }.frame(width: 26, height: 44)
                    }.accessibilityLabel(hiddenBalance ? "Show balance" : "Hide balance")
                    Button { sheet = .edit } label: {
                        HStack(spacing: 6) { Text("Main wallet").font(.system(size: 15, weight: .semibold)); Image(systemName: "chevron.down").font(.system(size: 10)) }
                            .frame(minHeight: 44)
                    }.foregroundStyle(palette.ink)
                    Spacer(minLength: 2)
                    trustUtility(.copy, label: "Copy wallet address", identifier: "wallet-copy-address") { copyAddress() }
                    trustUtility(.qr, label: "Wallet QR code", identifier: "wallet-show-qr") { sheet = .addressDetails }
                    trustUtility(.connections, label: "Wallet connections", identifier: "wallet-connections") { sheet = .connections }
                }.buttonStyle(.plain).foregroundStyle(palette.secondary)
            } else if profile.theme == .phantom {
                HStack {
                    Button { sheet = .edit } label: {
                        HStack(spacing: 6) {
                            Text("My Wallet").font(.system(size: 16, weight: .medium))
                            Image(systemName: "chevron.down").font(.system(size: 11))
                        }.frame(minHeight: 32).contentShape(Rectangle())
                    }.buttonStyle(.plain).foregroundStyle(palette.secondary)
                    Spacer()
                }
            }
            Text(hiddenBalance ? "••••••" : scene.money(profile.fiatValue))
                .font(.system(size: profile.theme == .phantom ? 44 : profile.theme == .trustWallet ? 28 : 37, weight: profile.theme == .trustWallet ? .bold : .semibold))
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
                if profile.theme == .phantom { PhantomCashMark().frame(width: 25, height: 19).padding(.trailing, 7).accessibilityHidden(true) }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 5) {
                        Text(profile.theme == .phantom ? "Cash" : "Money balance").font(.system(size: 15, weight: .medium))
                        if profile.theme == .metamask { Image(systemName: "info.circle").font(.system(size: 12)).foregroundStyle(palette.secondary) }
                    }
                    if profile.theme == .metamask {
                        HStack(spacing: 8) {
                            Text(scene.money(stable.value)).font(.system(size: 20, weight: .semibold))
                            Text(stable.symbol).font(.system(size: 12)).foregroundStyle(palette.secondary)
                        }
                    }
                }
                Spacer()
                if profile.theme == .phantom {
                    Button { sheet = .token(stable.id) } label: { Text(scene.money(stable.value)).font(.system(size: 17)).frame(minHeight: 36) }
                        .buttonStyle(.plain)
                } else {
                    Button { sheet = .swap(.sell) } label: {
                        Text("Add").font(.system(size: 14, weight: .semibold)).padding(.horizontal, 16).frame(minHeight: 44)
                            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 13))
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18).padding(.vertical, profile.theme == .phantom ? 12 : 18)
            .background(palette.card, in: RoundedRectangle(cornerRadius: 19))
        }
    }
    private var actionRow: some View {
        HStack(spacing: profile.theme == .trustWallet ? 4 : 10) {
            if profile.theme == .metamask {
                walletAction(title: "Buy", symbol: "dollarsign") { sheet = .swap(.buy) }
                walletAction(title: "Swap", symbol: "arrow.up.arrow.down") { sheet = .swap(.swap) }
            }
            walletAction(title: "Send", symbol: profile.theme == .trustWallet ? "arrow.up" : "paperplane") { sheet = .send(nil) }
            walletAction(title: "Receive", symbol: profile.theme == .trustWallet ? "arrow.down" : "arrow.down.left") { sheet = .receive }
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
                Group {
                    if profile.theme == .metamask && title == "Send" { MetaMaskSendMark().frame(width: 22, height: 20) }
                    else if profile.theme == .trustWallet && title == "History" { TrustHistoryMark().frame(width: 22, height: 22) }
                    else { Image(systemName: symbol).font(.system(size: 21, weight: .medium)) }
                }
                    .frame(width: profile.theme == .trustWallet ? 44 : 50, height: profile.theme == .trustWallet ? 44 : 30)
                    .background(profile.theme == .trustWallet ? palette.card : .clear, in: Circle())
                Text(title).font(.system(size: 12, weight: .medium))
            }
            .padding(.vertical, profile.theme == .metamask ? 8 : 0)
            .frame(maxWidth: .infinity, minHeight: profile.theme == .metamask ? 70 : 72)
            .background(profile.theme == .metamask ? palette.card : .clear, in: RoundedRectangle(cornerRadius: 15))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(palette.ink)
        .accessibilityIdentifier("wallet-" + title.lowercased())
    }

    private var trustSearchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 17, weight: .semibold)).foregroundStyle(palette.secondary)
            TextField("Search", text: $search).font(.system(size: 15))
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .focused($searchFocused).submitLabel(.search).onSubmit { searchFocused = false }
                .accessibilityIdentifier("wallet-home-search")
            if !search.isEmpty {
                Button { search = ""; searchFocused = false } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(palette.secondary).frame(width: 28, height: 39)
                }.accessibilityLabel("Clear search").accessibilityIdentifier("wallet-clear-search")
            }
        }.padding(.horizontal, 14).frame(height: 34).background(palette.card, in: Capsule())
    }

    private func trustUtility(_ mark: TrustUtilityMark.Kind, label: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            TrustUtilityMark(kind: mark).frame(width: 18, height: 18)
                .frame(width: 30, height: 30).background(palette.card, in: RoundedRectangle(cornerRadius: 5))
                .frame(width: 39, height: 44).contentShape(Rectangle())
        }.accessibilityLabel(label).accessibilityIdentifier(identifier)
    }

    private var trustRewardsBanner: some View {
        HStack(alignment: .center, spacing: 12) {
            TrustRewardsArtwork().frame(width: 55, height: 60).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text("Earn up to 210 Trust Points daily to unlock future rewards")
                    .font(.system(size: 13, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                Button { sheet = .trustRewards } label: {
                    HStack(spacing: 6) { Text("Check now"); Image(systemName: "arrow.right") }
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(palette.accent)
                        .frame(minHeight: 26)
                }.accessibilityIdentifier("wallet-trust-rewards")
            }
            Spacer(minLength: 6)
        }
        .padding(.horizontal, 13).padding(.vertical, 10)
        .padding(.bottom, 6).background(palette.card, in: RoundedRectangle(cornerRadius: 11))
        .overlay(alignment: .topTrailing) {
            Button { showTrustRewards = false } label: {
                Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(palette.secondary)
                    .frame(width: 44, height: 44)
            }.accessibilityLabel("Dismiss rewards banner").accessibilityIdentifier("wallet-dismiss-rewards")
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: 8) { ForEach(0..<7) { index in Capsule().fill(palette.secondary.opacity(index == 0 ? 1 : 0.5)).frame(width: 10, height: 2) } }
                .padding(.bottom, 8).accessibilityHidden(true)
        }
        .buttonStyle(.plain)
    }

    private var trustSectionPicker: some View {
        HStack(spacing: 0) {
            ForEach(TrustWalletSection.allCases) { section in
                Button { searchFocused = false; trustSection = section } label: {
                    VStack(spacing: 11) {
                        Text(section.title).font(.system(size: 16, weight: .medium))
                            .foregroundStyle(trustSection == section ? palette.ink : palette.secondary)
                        Rectangle().fill(trustSection == section ? palette.accent : .clear).frame(width: 25, height: 3)
                    }.frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("wallet-section-" + section.rawValue)
                    .accessibilityAddTraits(trustSection == section ? .isSelected : [])
            }
        }
    }

    private var trustCollectibles: some View {
        let collectibles = TrustCollectible.allCases.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }
        return Group {
            if collectibles.isEmpty { ContentUnavailableView.search(text: search) }
            else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], spacing: 20) {
                    ForEach(collectibles) { collectible in
                        Button { sheet = .collectible(collectible) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                TrustCollectibleArtwork(collectible: collectible).aspectRatio(1, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 11))
                                Text(collectible.title).font(.system(size: 13, weight: .semibold))
                                Text("Ethereum").font(.system(size: 11)).foregroundStyle(palette.secondary)
                            }
                        }.buttonStyle(.plain).accessibilityIdentifier("wallet-nft-" + collectible.rawValue)
                    }
                }
            }
        }
    }

    private func copyAddress() {
        UIPasteboard.general.string = profile.address
        copiedAddress = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            copiedAddress = false
        }
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
                metaNavigationButton("Explore", symbol: "magnifyingglass", page: nil, identifier: "wallet-tab-explore") { sheet = .explore }
                Button { sheet = .swap(.swap) } label: {
                    VStack(spacing: 5) {
                        Image(systemName: "plus").font(.system(size: 28, weight: .regular)).frame(width: 49, height: 49).background(palette.accent, in: Circle()).foregroundStyle(.white)
                        Text("Trade").font(.system(size: 10, weight: .medium)).foregroundStyle(palette.secondary)
                    }.frame(maxWidth: .infinity, minHeight: 56).contentShape(Rectangle()).offset(y: -10)
                }.buttonStyle(.plain).accessibilityIdentifier("wallet-tab-trade")
                metaNavigationButton("Money", symbol: "dollarsign.circle", page: .money, identifier: "wallet-tab-money") { tab = .money }
                metaNavigationButton("Rewards", symbol: "seal", page: .rewards, identifier: "wallet-tab-rewards") { tab = .rewards }
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
        case .addressDetails: WalletReceiveSheet(sceneID: sceneID, initialAssetID: profile.holdings.first?.id)
        case .transaction(let id): WalletTransactionDetail(sceneID: sceneID, transactionID: id)
        case .swap(let mode): WalletSwapSheet(sceneID: sceneID, mode: mode)
        case .explore: WalletExploreSheet(sceneID: sceneID)
        case .connections: TrustConnectionsSheet()
        case .trustRewards: TrustRewardsSheet()
        case .collectible(let collectible): TrustCollectibleSheet(collectible: collectible)
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
    case edit, token(UUID), send(UUID?), receive, addressDetails, transaction(UUID), swap(WalletSwapMode), explore, connections, trustRewards, collectible(TrustCollectible)
    var id: String {
        switch self {
        case .edit: return "edit"
        case .token(let id): return "token-" + id.uuidString
        case .send(let id): return "send-" + (id?.uuidString ?? "pick")
        case .receive: return "receive"
        case .addressDetails: return "addressDetails"
        case .transaction(let id): return "transaction-" + id.uuidString
        case .swap(let mode): return "swap-" + mode.rawValue
        case .explore: return "explore"
        case .connections: return "connections"
        case .trustRewards: return "trustRewards"
        case .collectible(let collectible): return "collectible-" + collectible.rawValue
        }
    }
}
private struct WalletPalette {
    let theme: WalletTheme
    var accent: Color { theme == .phantom ? Color(red: 0.68, green: 0.61, blue: 0.98) : theme == .trustWallet ? Color(red: 0.04, green: 0.02, blue: 0.96) : Color(red: 0.26, green: 0.31, blue: 1) }
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

private struct PhantomAccountAvatar: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            context.fill(Path(ellipseIn: CGRect(x: 0, y: 0, width: w, height: h)), with: .color(Color(red: 1, green: 0.98, blue: 0.69)))
            context.fill(Path(ellipseIn: CGRect(x: w * 0.25, y: h * 0.4, width: w * 0.61, height: h * 0.68)), with: .color(Color(red: 1, green: 0.34, blue: 0.15)))
            context.fill(Path(ellipseIn: CGRect(x: w * 0.21, y: h * 0.23, width: w * 0.59, height: h * 0.31)), with: .color(Color(red: 0.08, green: 0.08, blue: 0.1)))
            var brim = Path(); brim.move(to: CGPoint(x: w * 0.12, y: h * 0.53)); brim.addLine(to: CGPoint(x: w * 0.91, y: h * 0.37))
            context.stroke(brim, with: .color(.black), style: StrokeStyle(lineWidth: w * 0.075, lineCap: .round))
            for x in [0.45, 0.67] {
                context.fill(Path(ellipseIn: CGRect(x: w * x, y: h * 0.54, width: w * 0.16, height: h * 0.19)), with: .color(Color(red: 0.08, green: 0.09, blue: 0.16)))
                var shine = Path(); shine.move(to: CGPoint(x: w * (x + 0.035), y: h * 0.6)); shine.addLine(to: CGPoint(x: w * (x + 0.085), y: h * 0.56))
                context.stroke(shine, with: .color(Color(red: 0.25, green: 0.45, blue: 0.75)), lineWidth: w * 0.025)
            }
            var bridge = Path(); bridge.move(to: CGPoint(x: w * 0.59, y: h * 0.61)); bridge.addLine(to: CGPoint(x: w * 0.7, y: h * 0.61))
            context.stroke(bridge, with: .color(.black), lineWidth: w * 0.03)
        }.clipShape(Circle()).accessibilityHidden(true)
    }
}

private struct PhantomCashMark: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 2).fill(.white)
                Ellipse().fill(.black).frame(width: proxy.size.width * 0.23, height: proxy.size.height * 0.6)
                ForEach(0..<4) { index in
                    Circle().fill(.black).frame(width: 3, height: 3)
                        .position(x: proxy.size.width * (index < 2 ? 0.15 : 0.85), y: proxy.size.height * (index.isMultiple(of: 2) ? 0.22 : 0.78))
                }
            }
        }
    }
}

private struct WalletVectorPolygon: Shape {
    let points: [CGPoint]
    func path(in rect: CGRect) -> Path {
        Path { path in
            for (index, point) in points.enumerated() {
                let scaled = CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height)
                if index == 0 { path.move(to: scaled) } else { path.addLine(to: scaled) }
            }
            path.closeSubpath()
        }
    }
}

private struct TrustEyeMark: View {
    var body: some View {
        ZStack {
            WalletVectorPolygon(points: [CGPoint(x: 0, y: 0.5), CGPoint(x: 0.5, y: 0), CGPoint(x: 1, y: 0.5), CGPoint(x: 0.5, y: 1)])
            Circle().fill(.white).frame(width: 11, height: 11)
            Circle().frame(width: 5, height: 5)
        }.accessibilityHidden(true)
    }
}

private struct MetaMaskSendMark: View {
    var body: some View {
        Canvas { context, size in
            var arrow = Path()
            arrow.move(to: CGPoint(x: size.width * 0.1, y: size.height * 0.15))
            arrow.addLine(to: CGPoint(x: size.width * 0.93, y: size.height * 0.5))
            arrow.addLine(to: CGPoint(x: size.width * 0.1, y: size.height * 0.85))
            arrow.closeSubpath()
            arrow.move(to: CGPoint(x: size.width * 0.1, y: size.height * 0.5))
            arrow.addLine(to: CGPoint(x: size.width * 0.84, y: size.height * 0.5))
            context.stroke(arrow, with: .color(.white), style: StrokeStyle(lineWidth: 1.7, lineJoin: .miter))
        }.accessibilityHidden(true)
    }
}

private struct TrustHistoryMark: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            var document = Path()
            document.move(to: CGPoint(x: w * 0.12, y: h * 0.03))
            document.addLine(to: CGPoint(x: w * 0.58, y: h * 0.03))
            document.addLine(to: CGPoint(x: w * 0.81, y: h * 0.26))
            document.addLine(to: CGPoint(x: w * 0.81, y: h * 0.47))
            document.addLine(to: CGPoint(x: w * 0.62, y: h * 0.4))
            document.addLine(to: CGPoint(x: w * 0.36, y: h * 0.52))
            document.addLine(to: CGPoint(x: w * 0.36, y: h * 0.88))
            document.addLine(to: CGPoint(x: w * 0.12, y: h * 0.88))
            document.closeSubpath()
            let ink = Color(red: 0.10, green: 0.10, blue: 0.12)
            context.fill(document, with: .color(ink))
            context.stroke(Path(ellipseIn: CGRect(x: w * 0.43, y: h * 0.48, width: w * 0.53, height: h * 0.53)), with: .color(ink), lineWidth: 2)
            var hands = Path()
            hands.move(to: CGPoint(x: w * 0.69, y: h * 0.56)); hands.addLine(to: CGPoint(x: w * 0.69, y: h * 0.75)); hands.addLine(to: CGPoint(x: w * 0.8, y: h * 0.78))
            context.stroke(hands, with: .color(ink), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }.accessibilityHidden(true)
    }
}

private struct TrustUtilityMark: View {
    enum Kind { case copy, qr, connections }
    let kind: Kind
    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            switch kind {
            case .copy:
                context.fill(Path(CGRect(x: w * 0.13, y: h * 0.26, width: w * 0.58, height: h * 0.71)), with: .color(Color(red: 0.57, green: 0.58, blue: 0.62)))
                var outline = Path()
                outline.move(to: CGPoint(x: w * 0.37, y: h * 0.03))
                outline.addLine(to: CGPoint(x: w * 0.92, y: h * 0.03))
                outline.addLine(to: CGPoint(x: w * 0.92, y: h * 0.71))
                context.stroke(outline, with: .color(Color(red: 0.57, green: 0.58, blue: 0.62)), style: StrokeStyle(lineWidth: w * 0.14, lineJoin: .miter))
            case .qr:
                for (x, y) in [(0.04, 0.04), (0.62, 0.04), (0.04, 0.62)] {
                    context.fill(Path(CGRect(x: w * x, y: h * y, width: w * 0.3, height: h * 0.3)), with: .color(Color(red: 0.57, green: 0.58, blue: 0.62)))
                }
                for (x, y) in [(0.43, 0.43), (0.74, 0.43), (0.43, 0.74), (0.74, 0.74), (0.88, 0.88)] {
                    context.fill(Path(CGRect(x: w * x, y: h * y, width: w * 0.14, height: h * 0.14)), with: .color(Color(red: 0.57, green: 0.58, blue: 0.62)))
                }
            case .connections:
                let radius = w * 0.3
                context.fill(Path(ellipseIn: CGRect(x: w * 0.08, y: h * 0.42, width: radius * 2, height: radius * 2)), with: .color(Color(red: 0.57, green: 0.58, blue: 0.62)))
                context.fill(Path(ellipseIn: CGRect(x: w * 0.41, y: h * 0.09, width: radius * 2, height: radius * 2)), with: .color(Color(red: 0.57, green: 0.58, blue: 0.62)))
                var diagonal = Path()
                diagonal.move(to: CGPoint(x: w * 0.38, y: h * 0.68)); diagonal.addLine(to: CGPoint(x: w * 0.69, y: h * 0.37))
                context.stroke(diagonal, with: .color(Color(red: 0.96, green: 0.96, blue: 0.97)), style: StrokeStyle(lineWidth: w * 0.12, lineCap: .round))
            }
        }.accessibilityHidden(true)
    }
}

private struct EthereumWalletMark: View {
    var body: some View {
        ZStack {
            WalletVectorPolygon(points: [CGPoint(x: 0.5, y: 0), CGPoint(x: 0.5, y: 0.68), CGPoint(x: 0, y: 0.51)])
                .fill(Color(red: 0.98, green: 0.98, blue: 1))
            WalletVectorPolygon(points: [CGPoint(x: 0.5, y: 0), CGPoint(x: 1, y: 0.51), CGPoint(x: 0.5, y: 0.68)])
                .fill(Color(red: 0.86, green: 0.88, blue: 1))
            WalletVectorPolygon(points: [CGPoint(x: 0, y: 0.51), CGPoint(x: 0.5, y: 0.38), CGPoint(x: 0.5, y: 0.68)])
                .fill(Color(red: 0.77, green: 0.80, blue: 0.97))
            WalletVectorPolygon(points: [CGPoint(x: 1, y: 0.51), CGPoint(x: 0.5, y: 0.38), CGPoint(x: 0.5, y: 0.68)])
                .fill(Color(red: 0.68, green: 0.73, blue: 0.94))
            WalletVectorPolygon(points: [CGPoint(x: 0, y: 0.59), CGPoint(x: 0.5, y: 0.76), CGPoint(x: 0.5, y: 1)])
                .fill(Color(red: 0.98, green: 0.98, blue: 1))
            WalletVectorPolygon(points: [CGPoint(x: 1, y: 0.59), CGPoint(x: 0.5, y: 0.76), CGPoint(x: 0.5, y: 1)])
                .fill(Color(red: 0.83, green: 0.87, blue: 1))
        }
    }
}

private enum TrustWalletSection: String, CaseIterable, Identifiable {
    case crypto, nfts
    var id: String { rawValue }
    var title: String { self == .crypto ? "Crypto" : "NFTs" }
}

private struct TrustRewardsArtwork: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                WalletVectorPolygon(points: [CGPoint(x: 0.08, y: 0.52), CGPoint(x: 0.65, y: 0.39), CGPoint(x: 0.88, y: 0.57), CGPoint(x: 0.32, y: 0.73)])
                    .fill(Color(red: 0.1, green: 0.15, blue: 0.8))
                WalletVectorPolygon(points: [CGPoint(x: 0.08, y: 0.52), CGPoint(x: 0.32, y: 0.73), CGPoint(x: 0.36, y: 0.99), CGPoint(x: 0.12, y: 0.81)])
                    .fill(Color(red: 0.14, green: 0.45, blue: 1))
                WalletVectorPolygon(points: [CGPoint(x: 0.32, y: 0.73), CGPoint(x: 0.88, y: 0.57), CGPoint(x: 0.87, y: 0.9), CGPoint(x: 0.36, y: 0.99)])
                    .fill(Color(red: 0.24, green: 0.6, blue: 1))
                WalletVectorPolygon(points: [CGPoint(x: 0.08, y: 0.49), CGPoint(x: 0.3, y: 0.14), CGPoint(x: 0.87, y: 0.03), CGPoint(x: 0.64, y: 0.4)])
                    .fill(.white).overlay {
                        WalletVectorPolygon(points: [CGPoint(x: 0.08, y: 0.49), CGPoint(x: 0.3, y: 0.14), CGPoint(x: 0.87, y: 0.03), CGPoint(x: 0.64, y: 0.4)])
                            .stroke(Color(red: 0.23, green: 0.3, blue: 0.75), lineWidth: 0.8)
                    }
                RoundedRectangle(cornerRadius: 3).fill(Color(red: 0.07, green: 0.1, blue: 0.15))
                    .frame(width: proxy.size.width * 0.28, height: proxy.size.height * 0.3)
                    .rotationEffect(.degrees(-12)).position(x: proxy.size.width * 0.65, y: proxy.size.height * 0.74)
                Text("?").font(.system(size: 21, weight: .bold)).foregroundStyle(.green)
                    .rotationEffect(.degrees(-12)).position(x: proxy.size.width * 0.65, y: proxy.size.height * 0.74)
                Ellipse().fill(Color(red: 0.68, green: 0.61, blue: 1)).frame(width: 6, height: 12)
                    .rotationEffect(.degrees(-18)).position(x: proxy.size.width * 0.77, y: proxy.size.height * 0.21)
            }
        }
    }
}

private enum TrustCollectible: String, CaseIterable, Identifiable {
    case sunset, lagoon, orchid, cosmos
    var id: String { rawValue }
    var title: String {
        switch self { case .sunset: return "Sunset Ape #101"; case .lagoon: return "Lagoon Ape #408"; case .orchid: return "Orchid Ape #215"; case .cosmos: return "Cosmos Ape #702" }
    }
    var background: Color {
        switch self { case .sunset: return Color(red: 0.26, green: 0.58, blue: 0.76); case .lagoon: return Color(red: 0.14, green: 0.75, blue: 0.62); case .orchid: return Color(red: 0.66, green: 0.48, blue: 0.82); case .cosmos: return Color(red: 0.13, green: 0.17, blue: 0.42) }
    }
    var fur: Color { self == .sunset || self == .orchid ? Color(red: 0.81, green: 0.33, blue: 0.15) : Color(red: 0.31, green: 0.76, blue: 0.81) }
}

private struct TrustCollectibleArtwork: View {
    let collectible: TrustCollectible
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            ZStack {
                collectible.background
                Ellipse().fill(collectible.fur).frame(width: w * 0.8, height: h * 0.69).position(x: w * 0.5, y: h * 0.99)
                Circle().fill(collectible.fur).frame(width: w * 0.72).position(x: w * 0.5, y: h * 0.52)
                Ellipse().fill(Color(red: 0.94, green: 0.74, blue: 0.5)).frame(width: w * 0.53, height: h * 0.34).position(x: w * 0.5, y: h * 0.68)
                ForEach(0..<2) { index in
                    Ellipse().fill(Color(red: 0.94, green: 0.74, blue: 0.5)).frame(width: w * 0.22, height: h * 0.19).position(x: w * (index == 0 ? 0.35 : 0.65), y: h * 0.46)
                    Ellipse().fill(.black).frame(width: w * 0.105, height: h * 0.065).position(x: w * (index == 0 ? 0.35 : 0.65), y: h * 0.47)
                }
                Capsule().fill(.black.opacity(0.8)).frame(width: w * 0.13, height: h * 0.04).position(x: w * 0.5, y: h * 0.62)
                Capsule().fill(.black.opacity(0.8)).frame(width: w * 0.28, height: h * 0.025).rotationEffect(.degrees(7)).position(x: w * 0.5, y: h * 0.76)
                RoundedRectangle(cornerRadius: w * 0.06).fill(collectible == .lagoon ? Color(red: 0.14, green: 0.23, blue: 0.38) : Color(red: 0.82, green: 0.28, blue: 0.11))
                    .frame(width: w * 0.66, height: h * 0.13).rotationEffect(.degrees(-7)).position(x: w * 0.51, y: h * 0.25)
            }
        }.accessibilityHidden(true)
    }
}

private struct TrustCollectibleSheet: View {
    let collectible: TrustCollectible
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    TrustCollectibleArtwork(collectible: collectible).aspectRatio(1, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 16))
                    Text(collectible.title).font(.system(size: 24, weight: .bold))
                    HStack { Text("Network").foregroundStyle(.secondary); Spacer(); Text("Ethereum") }
                    HStack { Text("Collection").foregroundStyle(.secondary); Spacer(); Text("Color Apes") }
                }.padding(20)
            }.navigationTitle("NFT").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.preferredColorScheme(.light).accessibilityIdentifier("wallet-nft-detail")
    }
}

private struct TrustConnectionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var connections: [String] = []
    @State private var choosing = false
    var body: some View {
        NavigationStack {
            List {
                if connections.isEmpty { ContentUnavailableView("No connections", systemImage: "link", description: Text("Connected apps appear here.")) }
                ForEach(connections, id: \.self) { connection in
                    HStack { Text(connection); Spacer(); Button("Disconnect") { connections.removeAll { $0 == connection } }.font(.caption) }
                }
                Button { choosing = true } label: { Label("Connect app", systemImage: "plus").frame(minHeight: 44) }
            }.navigationTitle("Connections").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .confirmationDialog("Choose app", isPresented: $choosing, titleVisibility: .visible) {
                    ForEach(["Uniswap", "Aave", "OpenSea"], id: \.self) { name in Button(name) { if !connections.contains(name) { connections.append(name) } } }
                    Button("Cancel", role: .cancel) { }
                }
        }.preferredColorScheme(.light).accessibilityIdentifier("wallet-connections-sheet")
    }
}

private struct TrustRewardsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var checkedIn = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    TrustRewardsArtwork().frame(width: 120, height: 135).frame(maxWidth: .infinity)
                    Text("Trust Points").font(.system(size: 28, weight: .bold))
                    Text(checkedIn ? "220" : "210").font(.system(size: 44, weight: .bold)).accessibilityIdentifier("wallet-trust-points")
                    Text("Earn points and unlock future rewards").foregroundStyle(.secondary)
                    Button { checkedIn = true } label: {
                        HStack { Text(checkedIn ? "Checked in" : "Daily check-in"); Spacer(); Text(checkedIn ? "✓" : "+10 points") }
                            .padding(18).background(Color(red: 0.96, green: 0.96, blue: 0.97), in: RoundedRectangle(cornerRadius: 14))
                    }.buttonStyle(.plain).disabled(checkedIn).accessibilityIdentifier("wallet-trust-check-in")
                }.padding(24)
            }.navigationTitle("Rewards").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.preferredColorScheme(.light).accessibilityIdentifier("wallet-trust-rewards-sheet")
    }
}

private struct WalletTokenMark: View {
    let symbol: String
    var theme: WalletTheme? = nil
    var size: CGFloat = 44
    var body: some View {
        ZStack {
            Circle().fill(color)
            if symbol.uppercased() == "ETH", theme == .metamask || theme == .trustWallet {
                EthereumWalletMark().frame(width: size * 0.46, height: size * 0.69)
            } else if let assetName, let image = UIImage(named: assetName) {
                Image(uiImage: image).resizable().scaledToFit()
            } else if symbol.uppercased() == "SOL" {
                VStack(spacing: 3) {
                    ForEach(0..<3) { _ in Capsule().fill(LinearGradient(colors: [.green, .purple], startPoint: .leading, endPoint: .trailing)).frame(width: 23, height: 5).rotationEffect(.degrees(-15)) }
                }
            } else {
                Text(symbol.uppercased() == "BTC" ? "₿" : symbol.uppercased().hasPrefix("USD") ? "$" : String(symbol.prefix(1)))
                    .font(.system(size: 23, weight: .semibold)).foregroundStyle(.white)
            }
        }.frame(width: size, height: size).clipShape(Circle()).accessibilityHidden(true)
    }
    private var assetName: String? {
        switch symbol.uppercased() {
        case "BTC": return "WalletFidelity-Bitcoin"
        case "ETH": return "WalletFidelity-Ethereum"
        case "SOL": return "WalletFidelity-Solana"
        case "USDC": return "WalletFidelity-USDcoin"
        default: return nil
        }
    }
    private var color: Color {
        switch symbol.uppercased() {
        case "BTC": return Color(red: 0.97, green: 0.57, blue: 0.08)
        case "ETH": return theme == .metamask || theme == .trustWallet ? Color(red: 0.43, green: 0.52, blue: 0.91) : Color(red: 0.88, green: 0.9, blue: 0.97)
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
            WalletTokenMark(symbol: holding.symbol, theme: theme, size: 36)
            VStack(alignment: .leading, spacing: 6) {
                Text(holding.name).font(.system(size: theme == .phantom ? 16 : 15, weight: theme == .trustWallet ? .medium : .regular))
                if theme != .trustWallet {
                    Text(walletQuantity(holding.quantity) + " " + holding.symbol).font(.system(size: theme == .phantom ? 13 : 12)).foregroundStyle(palette.secondary)
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
                Text(holding.value.formatted(.currency(code: currency))).font(.system(size: theme == .phantom ? 16 : 15, weight: theme == .phantom ? .regular : .medium))
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
        .foregroundStyle(palette.ink).padding(.vertical, theme == .phantom ? 13 : 15).padding(.horizontal, theme == .phantom ? 16 : 0)
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
                                WalletTokenMark(symbol: holding.symbol, theme: profile.theme)
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
    @State private var assetSearch = ""
    @State private var network: String?
    private var profile: WalletProfile { store.walletProfile(for: sceneID) }
    private var palette: WalletPalette { WalletPalette(theme: profile.theme) }
    private var selectedHolding: WalletHolding? { profile.holdings.first { $0.id == selectedAssetID } }
    private var address: String { selectedHolding?.address ?? profile.address }
    private var selectingTrustAsset: Bool { profile.theme == .trustWallet && selectedAssetID == nil && initialAssetID == nil }
    private var availableHoldings: [WalletHolding] {
        profile.holdings.filter {
            (network == nil || $0.network == network) &&
                (assetSearch.isEmpty || "\($0.name) \($0.symbol) \($0.network)".localizedCaseInsensitiveContains(assetSearch))
        }
    }
    private func nativeNetwork(for holding: WalletHolding) -> Bool {
        let network = holding.network.lowercased()
        switch holding.symbol.uppercased() {
        case "ETH": return network == "ethereum"
        case "BTC": return network == "bitcoin"
        case "SOL": return network == "solana"
        case "BNB": return network.contains("bnb") || network.contains("binance")
        default: return false
        }
    }
    private func networkSymbol(for holding: WalletHolding) -> String? {
        switch holding.network.lowercased() {
        case "ethereum": return "ETH"
        case "solana": return "SOL"
        case "bitcoin": return "BTC"
        default: return nil
        }
    }
    var body: some View {
        NavigationStack {
            Group {
                if selectingTrustAsset { trustAssetSelection }
                else { addressPage }
            }
            .background(palette.background)
            .navigationTitle("Receive").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                if profile.theme == .trustWallet && initialAssetID == nil && selectedAssetID != nil {
                    ToolbarItem(placement: .cancellationAction) { Button("Back") { selectedAssetID = nil } }
                }
            }
            .sheet(isPresented: $recording) { WalletTransferSheet(sceneID: sceneID, initialAssetID: selectedAssetID, incoming: true) }
            .onAppear {
                if selectedAssetID == nil && (profile.theme != .trustWallet || initialAssetID != nil) {
                    selectedAssetID = initialAssetID ?? profile.holdings.first?.id
                }
            }
            .onChange(of: selectedAssetID) { _, _ in copied = false }
        }
        .tint(palette.accent).preferredColorScheme(profile.theme == .trustWallet ? .light : .dark)
        .accessibilityIdentifier("wallet-receive-sheet")
    }
    private var trustAssetSelection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").font(.system(size: 17, weight: .semibold)).foregroundStyle(palette.secondary)
                    TextField("Search", text: $assetSearch).font(.system(size: 15)).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("wallet-receive-search")
                }.padding(.horizontal, 14).frame(height: 34).background(palette.card, in: Capsule())
                Menu {
                    Button("All Networks") { network = nil }
                    ForEach(Array(Set(profile.holdings.map(\.network))).sorted(), id: \.self) { name in Button(name) { network = name } }
                } label: {
                    HStack(spacing: 6) { Text(network ?? "All Networks"); Image(systemName: "chevron.down").font(.system(size: 10)) }
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(palette.secondary)
                        .padding(.horizontal, 12).frame(height: 34).background(palette.card, in: Capsule())
                }.accessibilityIdentifier("wallet-receive-network")
                if availableHoldings.isEmpty { ContentUnavailableView.search(text: assetSearch) }
                ForEach(availableHoldings) { holding in
                    Button { selectedAssetID = holding.id } label: {
                        HStack(spacing: 13) {
                            WalletTokenMark(symbol: holding.symbol, theme: profile.theme, size: 32)
                                .overlay(alignment: .bottomTrailing) {
                                    if !nativeNetwork(for: holding), let symbol = networkSymbol(for: holding) {
                                        WalletTokenMark(symbol: symbol, theme: .phantom, size: 15)
                                            .padding(2).background(.white, in: Circle()).offset(x: 4, y: 3)
                                    }
                                }
                            Text(holding.symbol).font(.system(size: 16, weight: .semibold)).foregroundStyle(palette.ink)
                            if !nativeNetwork(for: holding) {
                                Text(holding.network).font(.system(size: 11)).foregroundStyle(palette.secondary)
                                    .padding(.horizontal, 5).padding(.vertical, 3).background(palette.card, in: RoundedRectangle(cornerRadius: 4))
                            }
                            Spacer()
                        }.frame(minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("wallet-receive-asset-" + holding.symbol.lowercased())
                }
            }.padding(16)
        }
    }
    private var addressPage: some View {
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
            WalletTokenMark(symbol: holding.symbol, theme: profile.theme).padding(.top, 25)
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
                                WalletTokenMark(symbol: holding.symbol, theme: profile.theme).scaleEffect(0.75).frame(width: 35, height: 35)
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
                if let holding = receiving ? to : from { WalletTokenMark(symbol: holding.symbol, theme: profile.theme) }
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
                if let from { WalletTokenMark(symbol: from.symbol, theme: profile.theme) }
                Image(systemName: "arrow.right").font(.title2)
                if let to { WalletTokenMark(symbol: to.symbol, theme: profile.theme) }
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
