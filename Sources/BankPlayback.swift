import SwiftUI

/// Bank-specific playback, informed by the official iPhone screenshots in References/Banks.
/// This view only changes the captured scene; it never connects to a financial institution.
struct BankPlayback: View {
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("cleanPlayback") private var cleanPlayback = false
    let sceneID: UUID
    @State private var tab: BankPlaybackTab = .home
    @State private var showProfile = false
    @State private var showCard = false
    @State private var showThemes = false
    @State private var search = ""

    private var scene: StudioScene? { store.scenes.first { $0.id == sceneID } }
    private var profile: BankProfile { store.bankProfile(for: sceneID) }
    private var holderName: String { profile.holderName ?? scene?.name ?? profile.accountName }
    private var theme: BankTheme { profile.theme }
    private var palette: BankPalette { BankPalette(theme) }
    private var activity: [SceneEvent] {
        store.events.filter { $0.sceneID == sceneID }.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let scene {
                    VStack(spacing: 0) {
                        if cleanPlayback {
                            if theme != .hsbc { cleanHeader }
                        } else { header }
                        if theme == .hsbc { topTabs }
                        switch tab {
                        case .home: home(scene)
                        case .payments: BankPaymentPage(sceneID: sceneID, theme: theme)
                        case .activity: activityPage(scene)
                        case .cards: BankCardPage(sceneID: sceneID, theme: theme)
                        case .more: morePage(scene)
                        case .deposits: BankPaymentPage(sceneID: sceneID, theme: theme, initiallyIncoming: true)
                        case .spaces: BankAccountDetail(sceneID: sceneID, theme: theme, savings: true)
                        case .transfers: BankSavingsTransferPage(sceneID: sceneID, theme: theme)
                        case .statement: BankStatementPage(sceneID: sceneID, theme: theme)
                        }
                        if theme != .hsbc { bottomTabs }
                    }
                    .background(palette.background)
                } else {
                    ContentUnavailableView("Account unavailable", systemImage: "building.columns", description: Text("This scene has been removed."))
                }
            }
            .background(palette.header.ignoresSafeArea(edges: .top))
            .environment(\.colorScheme, theme == .revolut ? .dark : .light)
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(palette.header, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(palette.darkHeader ? .dark : .light, for: .navigationBar)
            .tint(palette.accent)
            .preferredColorScheme(palette.darkHeader ? .dark : .light)
            .sheet(isPresented: $showProfile) { BankProfileEditor(sceneID: sceneID) }
            .sheet(isPresented: $showThemes) {
                NavigationStack {
                    List(BankTheme.allCases) { bank in
                        Button {
                            var updated = profile
                            updated.theme = bank
                            if store.updateBankProfile(updated) { tab = .home; showThemes = false }
                        } label: {
                            HStack {
                                Text(bank.name)
                                Spacer()
                                if bank == theme { Image(systemName: "checkmark").accessibilityHidden(true) }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                    .navigationTitle("Choose bank")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showThemes = false } } }
                }
                .preferredColorScheme(.light)
            }
            .sheet(isPresented: $showCard) {
                NavigationStack {
                    BankCardPage(sceneID: sceneID, theme: theme)
                        .navigationTitle("Cards")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showCard = false } } }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Button { showProfile = true } label: {
                Image(systemName: theme == .bankOfAmerica ? "line.3.horizontal" : "person.crop.circle")
                    .font(.system(size: 20)).frame(width: 44, height: 44)
            }
            .accessibilityLabel("Account profile")
            Spacer(minLength: 8)
            if cleanPlayback {
                BankBrandMark(theme: theme, color: palette.headerInk)
                    .frame(minWidth: 140, minHeight: 44)
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 2) { dismiss() }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(theme.name), hold to return to Studio")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("bank-brand-exit")
                    .accessibilityAction(named: "Return to Studio") { dismiss() }
            } else {
                Button { showThemes = true } label: {
                    BankBrandMark(theme: theme, color: palette.headerInk)
                        .frame(minWidth: 140, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Choose bank, currently \(theme.name)")
                .accessibilityIdentifier("bank-theme-picker")
            }
            Spacer(minLength: 8)
            if cleanPlayback {
                Color.clear.frame(width: 44, height: 44).accessibilityHidden(true)
            } else {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 16, weight: .semibold)).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Close bank playback")
                .accessibilityIdentifier("close-scene")
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(palette.headerInk)
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(palette.header)
    }

    // The live account references use their own toolbar, rather than a repeated brand masthead.
    // The central region retains the long-press return gesture in clean playback.
    private var cleanHeader: some View {
        HStack(spacing: 10) {
            Button { showProfile = true } label: {
                Image(systemName: theme == .bankOfAmerica ? "line.3.horizontal" : (theme == .lloyds ? "envelope" : "person.crop.circle"))
                    .font(.system(size: theme == .lloyds ? 18 : 22))
                    .frame(width: 40, height: 44)
            }.accessibilityLabel("Account profile")
            cleanHeaderCenter
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 2) { dismiss() }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(theme.name), hold to return to Studio")
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("bank-brand-exit")
                .accessibilityAction(named: "Return to Studio") { dismiss() }
            Button {
                if theme == .monzo { tab = .deposits } else { tab = .activity }
            } label: {
                Image(systemName: theme == .monzo ? "plus.circle.fill" : (theme == .revolut ? "creditcard" : "bell"))
                    .font(.system(size: theme == .monzo ? 28 : 19))
                    .frame(width: 40, height: 44)
            }.accessibilityLabel(theme == .monzo ? "Add money" : "Activity")
        }
        .buttonStyle(.plain)
        .foregroundStyle(palette.headerInk)
        .padding(.horizontal, 12)
        .background(palette.header)
    }

    @ViewBuilder private var cleanHeaderCenter: some View {
        switch theme {
        case .lloyds:
            Text("Hi \(holderName)").font(.system(size: 15, weight: .semibold))
        case .monzo:
            HStack {
                Text("Upgrade").font(.system(size: 13, weight: .semibold)).padding(.horizontal, 12).padding(.vertical, 7).background(.white, in: Capsule())
                Spacer()
                Image(systemName: "gift").font(.system(size: 19))
                Image(systemName: "magnifyingglass").font(.system(size: 19)).padding(.leading, 9)
            }
        case .natWest:
            HStack(spacing: 6) {
                Text("Personal").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white).padding(.horizontal, 14).padding(.vertical, 6).background(palette.accent, in: Capsule())
                Image(systemName: "gift").font(.system(size: 13)).foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "magnifyingglass").font(.system(size: 18))
            }
        case .barclays:
            HStack { Text("Home").font(.system(size: 27, weight: .bold)); Spacer() }
        case .starling:
            HStack(spacing: 5) { Image(systemName: "person.fill").font(.system(size: 10)); Text("Personal").font(.system(size: 12, weight: .medium)); Image(systemName: "chevron.down").font(.system(size: 9)) }
                .padding(.horizontal, 12).padding(.vertical, 6).background(.white.opacity(0.09), in: Capsule())
        case .revolut:
            HStack(spacing: 7) { Image(systemName: "magnifyingglass"); Text("Search").font(.system(size: 14)); Spacer() }
                .foregroundStyle(.white.opacity(0.65)).padding(.horizontal, 14).padding(.vertical, 9).background(.white.opacity(0.08), in: Capsule())
        case .bankOfAmerica:
            HStack(spacing: 25) { Spacer(); VStack(spacing: 3) { Image(systemName: "envelope"); Text("Inbox").font(.system(size: 8)) }; VStack(spacing: 3) { Image(systemName: "cart"); Text("Products").font(.system(size: 8)) } }.font(.system(size: 16)).foregroundStyle(.secondary)
        case .citi:
            HStack { Text("Welcome").font(.system(size: 19, weight: .bold)); Spacer() }
        case .hsbc:
            BankBrandMark(theme: theme, color: palette.headerInk).scaleEffect(0.8)
        case .capitalOne:
            BankBrandMark(theme: theme, color: palette.headerInk).scaleEffect(0.8)
        case .wellsFargo:
            BankBrandMark(theme: theme, color: palette.headerInk).scaleEffect(0.8)
        case .chase:
            BankChaseSymbol().fill(.white).frame(width: 22, height: 22)
        }
    }

    @ViewBuilder private func home(_ scene: StudioScene) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                switch theme {
                case .chase: chaseHome(scene)
                case .bankOfAmerica: americaHome(scene)
                case .wellsFargo: wellsHome(scene)
                case .citi: citiHome(scene)
                case .capitalOne: capitalHome(scene)
                case .hsbc: hsbcHome(scene)
                case .barclays: barclaysHome(scene)
                case .lloyds: lloydsHome(scene)
                case .natWest: natWestHome(scene)
                case .monzo: monzoHome(scene)
                case .revolut: revolutHome(scene)
                case .starling: starlingHome(scene)
                }
            }
            .padding(.bottom, 24)
        }
        .accessibilityIdentifier("bank.home")
    }

    private func chaseHome(_ scene: StudioScene) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Good morning, \(holderName)").font(.system(size: 21, weight: .regular))
                    Button("See statements") { tab = .statement }.font(.system(size: 14))
                }
                Spacer()
                Image(systemName: "bubble.left").font(.title3)
            }
            .foregroundStyle(.white)
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.accent)
            VStack(alignment: .leading, spacing: 16) {
                Text("Accounts").font(.system(size: 25, weight: .semibold))
                VStack(spacing: 0) {
                    bankSectionHeader("Bank accounts (2)", color: palette.accent)
                    accountRow(scene, title: "TOTAL CHECKING", balance: scene.balance, suffix: profile.accountSuffix, detail: "Available balance", size: 28)
                    Divider().padding(.horizontal, 16)
                    accountRow(scene, title: "CHASE SAVINGS", balance: profile.savings, suffix: "2202", detail: "Available balance", size: 28, savings: true)
                }.bankSurface(radius: 5)
                actionStrip([("Pay & transfer", "arrow.left.arrow.right"), ("Deposit checks", "doc.text.viewfinder"), ("Manage cards", "creditcard")])
                transactionPanel(scene, title: "Recent activity", limit: 4)
            }.padding(.horizontal, 18)
        }
    }

    private func americaHome(_ scene: StudioScene) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Accounts").fontWeight(.semibold).foregroundStyle(palette.accent)
                Spacer()
                Button("Dashboard") { tab = .activity }.foregroundStyle(.secondary)
            }.padding(.horizontal, 42).padding(.vertical, 14).background(.white)
                .overlay(alignment: .bottom) { Rectangle().fill(palette.accent).frame(height: 2) }
            HStack {
                Image(systemName: "magnifyingglass")
                Button("How can we help?") { tab = .more }
                Spacer()
                Circle().fill(palette.accent).frame(width: 26, height: 26).overlay(Image(systemName: "line.3.horizontal").foregroundStyle(.white).font(.caption))
            }.font(.system(size: 14)).foregroundStyle(.secondary).padding(12).bankSurface(radius: 3)
            VStack(alignment: .leading, spacing: 16) {
                Button { showProfile = true } label: {
                    HStack { VStack(alignment: .leading, spacing: 3) { Text("Hello, \(holderName)").fontWeight(.bold); Text("Preferred Rewards").font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "chevron.right") }
                }.buttonStyle(.plain)
                Divider()
                HStack { Image(systemName: "location.north.circle"); Text("Bank of America Life Plan").fontWeight(.semibold); Spacer(); Image(systemName: "chevron.right") }.font(.system(size: 14))
                Button("My Rewards") { tab = .more }.font(.system(size: 14, weight: .medium))
            }.padding(16).bankSurface(radius: 4)
            VStack(spacing: 0) {
                bankSectionHeader("Banking", color: palette.accent)
                americaAccountRow(scene, title: "Adv Plus Banking", balance: scene.balance, suffix: profile.accountSuffix)
                Divider().padding(.horizontal)
                americaAccountRow(scene, title: "Adv Savings", balance: profile.savings, suffix: "6543", savings: true)
            }.bankSurface(radius: 4)
            transactionPanel(scene, title: "Transactions", limit: 4)
        }.padding(.horizontal, 16)
    }

    private func wellsHome(_ scene: StudioScene) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Good morning, \(holderName)").font(.system(size: 22, weight: .regular)).padding(.top, 15)
            HStack { Image(systemName: "magnifyingglass"); Button("Need help? Ask Fargo") { tab = .more }; Spacer(); Image(systemName: "bubble.left.and.bubble.right.fill").foregroundStyle(Color.purple) }
                .font(.system(size: 14)).foregroundStyle(.secondary).padding(12).bankSurface(radius: 25)
            accountRow(scene, title: "EVERYDAY CHECKING", balance: scene.balance, suffix: profile.accountSuffix, detail: "Available balance", size: 29).bankSurface(radius: 16)
            accountRow(scene, title: "WAY2SAVE SAVINGS", balance: profile.savings, suffix: "6543", detail: "Available balance", size: 29, savings: true).bankSurface(radius: 16)
            actionStrip([("Pay & transfer", "arrow.left.arrow.right"), ("Deposit", "camera"), ("Cards", "creditcard")])
            transactionPanel(scene, title: "Recent transactions", limit: 4)
        }.padding(.horizontal, 20)
    }

    private func citiHome(_ scene: StudioScene) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 20) {
                if !cleanPlayback { HStack { Text("Welcome, \(holderName)").font(.system(size: 20, weight: .bold)); Spacer(); Image(systemName: "magnifyingglass") } }
                HStack(spacing: 13) {
                    Text("My Citi").fontWeight(.bold).underline()
                    Button("Credit Cards") { showCard = true }
                    Text("Banking")
                    Button("Loans") { tab = .more }
                    Button("Invest") { tab = .spaces }
                }.font(.system(size: 11))
                Text("⌃  Checking").font(.system(size: 15, weight: .semibold))
                NavigationLink {
                    BankAccountDetail(sceneID: sceneID, theme: theme, savings: false)
                        .toolbar(.visible, for: .navigationBar)
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { Label("Checking", systemImage: "building.columns"); Spacer(); Text(scene.money(scene.balance)).font(.system(size: 22, weight: .semibold)) }
                        HStack { Text("My Checking · \(profile.accountSuffix)"); Spacer(); Text("Available Now") }.font(.caption)
                    }.padding(16).foregroundStyle(.white).background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 7))
                }
                HStack(spacing: 8) {
                    Button("Pay & transfer") { tab = .payments }
                    Button("Statements") { tab = .statement }
                    Button("Lock Card") { showCard = true }
                }.font(.system(size: 12, weight: .semibold)).buttonStyle(.bordered).tint(.white)
            }.padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 22).foregroundStyle(.white)
                .background(LinearGradient(colors: [Color(bankHex: 0x0F86BA), Color(bankHex: 0x003B66)], startPoint: .topLeading, endPoint: .bottomTrailing))
            transactionPanel(scene, title: "Transactions", limit: 6).padding(.horizontal, 16)
            accountRow(scene, title: "Citi Savings", balance: profile.savings, suffix: "6713", detail: "Available Now", size: 24, savings: true).bankSurface(radius: 10).padding(.horizontal, 16)
        }
    }

    private func capitalHome(_ scene: StudioScene) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("Good morning, \(holderName)!").font(.system(size: 20, weight: .medium))
                Text("Your accounts, all in one place.").font(.system(size: 14)).foregroundStyle(.secondary)
                Button("Pay now") { tab = .payments }.font(.system(size: 15, weight: .semibold))
            }.padding(.vertical, 22)
            capitalAccountTile(scene, title: "360 CHECKING", suffix: profile.accountSuffix, balance: scene.balance, color: Color(bankHex: 0x006DA0))
            capitalAccountTile(scene, title: "360 PERFORMANCE SAVINGS", suffix: "7104", balance: profile.savings, color: Color(bankHex: 0xA66027), savings: true)
            HStack { Image(systemName: "lock.circle"); Text(profile.cardFrozen ? "Your card is locked" : "Manage your debit card"); Spacer(); Image(systemName: "chevron.right") }
                .font(.system(size: 15)).padding(18).bankSurface(radius: 8)
                .onTapGesture { showCard = true }.accessibilityAddTraits(.isButton)
            transactionPanel(scene, title: "Recent transactions", limit: 4)
        }.padding(.horizontal, 16)
    }

    private func hsbcHome(_ scene: StudioScene) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 0) {
                hsbcShortcut("Pay someone\nin the UK", symbol: "person.crop.circle", destination: .payments)
                hsbcShortcut("Transfer between\nyour accounts", symbol: "arrow.left.arrow.right", destination: .transfers)
                hsbcShortcut("Pay a bill or\ncompany", symbol: "doc.text", destination: .payments)
                hsbcShortcut("More", symbol: "plus", destination: .more)
            }.padding(.horizontal, 8).padding(.vertical, 16).background(Color(bankHex: 0xE5E9E6))
            HStack {
                Text("Your products").font(.system(size: 17, weight: .regular))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 2) { if cleanPlayback { dismiss() } }
                    .accessibilityLabel(cleanPlayback ? "HSBC, hold to return to Studio" : "Your products")
                    .accessibilityAddTraits(cleanPlayback ? .isButton : [])
                    .accessibilityIdentifier(cleanPlayback ? "bank-brand-exit" : "bank-products")
                    .accessibilityAction(named: "Return to Studio") { if cleanPlayback { dismiss() } }
                Spacer()
                Image(systemName: "eye")
            }.padding(.horizontal, 18)
            VStack(spacing: 12) {
                hsbcAccount(scene, title: "Current Account", balance: scene.balance, suffix: profile.accountSuffix, savings: false)
                hsbcAccount(scene, title: "Online Bonus Saver", balance: profile.savings, suffix: "3000", savings: true)
            }.padding(.horizontal, 16)
            transactionPanel(scene, title: "Recent transactions", limit: 4).padding(.horizontal, 16)
        }
    }

    private func barclaysHome(_ scene: StudioScene) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                if !cleanPlayback { Text("Home").font(.system(size: 29, weight: .bold)) }
                Text(holderName).font(.system(size: 14)).foregroundStyle(.secondary)
            }.padding(.top, 18)
            Button { tab = .more } label: {
                HStack { Image(systemName: "magnifyingglass"); Text("Search and quick actions"); Spacer() }.font(.system(size: 14)).foregroundStyle(.secondary).padding(12).bankSurface(radius: 5)
            }
            HStack { Text("Your accounts").font(.system(size: 17, weight: .semibold)); Spacer(); Image(systemName: "chevron.right") }
            NavigationLink { BankAccountDetail(sceneID: sceneID, theme: theme, savings: false).toolbar(.visible, for: .navigationBar) } label: {
                HStack(alignment: .top, spacing: 12) {
                    RoundedRectangle(cornerRadius: 4).fill(Color(bankHex: 0x00AEEF)).frame(width: 36, height: 54).overlay(BankBarclaysSymbol().fill(.white).frame(width: 22, height: 24))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Barclays Bank Account").font(.system(size: 14, weight: .semibold))
                        Text(scene.money(scene.balance)).font(.system(size: 25, weight: .bold))
                        Text("20-00-00  ·  ••••\(profile.accountSuffix)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(); Image(systemName: "ellipsis")
                }.foregroundStyle(palette.ink).padding(16)
            }.bankSurface(radius: 8)
            HStack(spacing: 20) { Button { tab = .payments } label: { Label("Pay", systemImage: "arrow.up.right.circle") }; Button { showCard = true } label: { Label("Card", systemImage: "creditcard") }; Spacer() }.font(.system(size: 15, weight: .medium))
            accountRow(scene, title: "Everyday Saver", balance: profile.savings, suffix: "5604", detail: "Available balance", size: 24, savings: true).bankSurface(radius: 8)
            transactionPanel(scene, title: "Recent activity", limit: 4)
        }.padding(.horizontal, 18)
    }

    private func lloydsHome(_ scene: StudioScene) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Summary").foregroundStyle(.secondary); Text("Everyday").foregroundStyle(.white).padding(.horizontal, 20).padding(.vertical, 10).background(.black, in: Capsule()); Text("Save & Invest").foregroundStyle(.secondary) }
                .font(.system(size: 14, weight: .medium)).padding(.top, 14)
            Text("Current accounts").font(.system(size: 20, weight: .semibold))
            VStack(alignment: .leading, spacing: 12) {
                HStack { Text("Personal Current Account").font(.system(size: 16, weight: .semibold)); Spacer(); Image(systemName: "ellipsis") }
                Text("00-00-00 / ••••\(profile.accountSuffix)").font(.caption).foregroundStyle(.secondary)
                NavigationLink { BankAccountDetail(sceneID: sceneID, theme: theme, savings: false).toolbar(.visible, for: .navigationBar) } label: { Text(scene.money(scene.balance)).font(.system(size: 30, weight: .bold)).foregroundStyle(.black) }
                Text("Available balance").font(.system(size: 13)).foregroundStyle(.secondary)
                Divider()
                HStack { Button("Pay & transfer") { tab = .payments }; Spacer(); Button("Regular payments") { tab = .activity } }.font(.system(size: 14, weight: .semibold))
            }.padding(18).bankSurface(radius: 8)
            HStack {
                Image(systemName: "calendar.badge.clock").font(.system(size: 28)).foregroundStyle(palette.accent)
                VStack(alignment: .leading, spacing: 6) { Text("Your upcoming payments").font(.system(size: 16, weight: .semibold)); Text("Keep track of your spending in Everyday.").font(.system(size: 13)).foregroundStyle(.secondary) }
                Spacer()
            }.padding(20).bankSurface(radius: 8)
            accountRow(scene, title: "Easy Saver", balance: profile.savings, suffix: "2088", detail: "Balance", size: 24, savings: true).bankSurface(radius: 8)
            transactionPanel(scene, title: "Latest transactions", limit: 4)
        }.padding(.horizontal, 16)
    }

    private func natWestHome(_ scene: StudioScene) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if !cleanPlayback {
                HStack { Text("Personal").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white).padding(.horizontal, 16).padding(.vertical, 6).background(palette.accent, in: Capsule()); Spacer(); Button { tab = .activity } label: { Image(systemName: "bell.badge") }; Image(systemName: "magnifyingglass") }.padding(.top, 12)
            }
            VStack(alignment: .leading, spacing: 16) {
                HStack { VStack(alignment: .leading, spacing: 6) { Text("Current Account").font(.system(size: 16, weight: .regular)); Text("Current · ••••\(profile.accountSuffix) · 00-00-00").font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "ellipsis").foregroundStyle(palette.accent) }
                NavigationLink { BankAccountDetail(sceneID: sceneID, theme: theme, savings: false).toolbar(.visible, for: .navigationBar) } label: {
                    HStack { Image(systemName: "wallet.bifold").font(.system(size: 30)); Spacer(); VStack(alignment: .trailing, spacing: 4) { Text(scene.money(scene.balance)).font(.system(size: 23, weight: .bold)); Text("Available balance").font(.system(size: 11)).foregroundStyle(.secondary) } }.foregroundStyle(palette.ink)
                }
            }.padding(20).bankSurface(radius: 13)
            compactAccountRow(scene, title: "Savings", balance: profile.savings, suffix: "4000", savings: true).bankSurface(radius: 10)
            actionStrip([("Payments", "arrow.left.arrow.right"), ("Cards", "creditcard"), ("Activity", "list.bullet.rectangle")])
            transactionPanel(scene, title: "Recent transactions", limit: 5)
        }.padding(.horizontal, 18)
    }

    private func monzoHome(_ scene: StudioScene) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if !cleanPlayback { HStack { Button("Upgrade") { tab = .more }.font(.system(size: 13, weight: .semibold)); Spacer(); Image(systemName: "gift"); Button { tab = .activity } label: { Image(systemName: "magnifyingglass") }; Button { tab = .deposits } label: { Image(systemName: "plus.circle.fill").font(.title) } }.padding(.top, 12) }
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) { Text("monzo").font(.system(size: 23, weight: .bold)); Spacer(); VStack(alignment: .trailing, spacing: 2) { Text(scene.money(scene.balance)).font(.system(size: 24, weight: .semibold)); Text("Balance").font(.system(size: 10)) } }
                Text("04-00-04 · ••••\(profile.accountSuffix)").font(.system(size: 10, weight: .medium))
                HStack(spacing: 10) {
                    Button { tab = .deposits } label: { Label("Add money", systemImage: "plus.circle.fill") }
                    Button { showCard = true } label: { Label("Card", systemImage: "creditcard.fill") }
                    Spacer()
                    NavigationLink { BankAccountDetail(sceneID: sceneID, theme: theme, savings: false).toolbar(.visible, for: .navigationBar) } label: { Image(systemName: "ellipsis.circle.fill") }.accessibilityLabel("Account details")
                }.font(.system(size: 11, weight: .semibold)).buttonStyle(.bordered).buttonBorderShape(.capsule).tint(Color(bankHex: 0x8D2929))
            }.padding(14).foregroundStyle(.white).background(Color(bankHex: 0xFF4C43), in: RoundedRectangle(cornerRadius: 12))
            transactionPanel(scene, title: "Activity", limit: 6)
            NavigationLink { BankAccountDetail(sceneID: sceneID, theme: theme, savings: true).toolbar(.visible, for: .navigationBar) } label: {
                HStack { Image(systemName: "archivebox.fill").font(.title2).foregroundStyle(Color(bankHex: 0x00A4A6)); VStack(alignment: .leading, spacing: 4) { Text("Savings Pot").fontWeight(.semibold); Text("Set money aside").font(.caption).foregroundStyle(.secondary) }; Spacer(); Text(scene.money(profile.savings)).fontWeight(.semibold) }.foregroundStyle(palette.ink).padding(18)
            }.bankSurface(radius: 12)
        }.padding(.horizontal, 16)
    }

    private func revolutHome(_ scene: StudioScene) -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 14) {
                HStack { Text("Personal").font(.system(size: 15, weight: .medium)); Image(systemName: "chevron.down").font(.caption) }.foregroundStyle(.white.opacity(0.75))
                Text(scene.money(scene.balance)).font(.system(size: 43, weight: .bold, design: .rounded)).minimumScaleFactor(0.6).lineLimit(1)
                NavigationLink { BankAccountDetail(sceneID: sceneID, theme: theme, savings: false).toolbar(.visible, for: .navigationBar) } label: { Text("Accounts").font(.system(size: 14, weight: .medium)).padding(.horizontal, 17).padding(.vertical, 8).background(.white.opacity(0.18), in: Capsule()) }
                HStack(spacing: 0) {
                    revolutAction("Add money", symbol: "plus", action: { tab = .deposits })
                    revolutAction("Move", symbol: "arrow.left.arrow.right", action: { tab = .transfers })
                    revolutAction("Info", symbol: "info", action: { showProfile = true })
                    revolutAction("More", symbol: "ellipsis", action: { tab = .more })
                }.padding(.top, 10)
            }.foregroundStyle(.white).padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 18)
                .background(LinearGradient(colors: [Color(bankHex: 0x243247), Color(bankHex: 0x080D15)], startPoint: .topLeading, endPoint: .bottomTrailing))
            transactionPanel(scene, title: "Transactions", limit: 5).padding(.horizontal, 16)
            NavigationLink { BankAccountDetail(sceneID: sceneID, theme: theme, savings: true).toolbar(.visible, for: .navigationBar) } label: {
                HStack { Image(systemName: "building.columns.fill").font(.title2); VStack(alignment: .leading, spacing: 5) { Text("Savings").fontWeight(.semibold); Text("Your savings balance").font(.caption).foregroundStyle(.secondary) }; Spacer(); Text(scene.money(profile.savings)).fontWeight(.semibold) }.foregroundStyle(palette.ink).padding(20)
            }.padding(.horizontal, 16).background(Color(bankHex: 0x24262A), in: RoundedRectangle(cornerRadius: 18)).padding(.horizontal, 16)
        }
    }

    private func starlingHome(_ scene: StudioScene) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    HStack { Text("Personal"); Image(systemName: "chevron.down").font(.caption) }.font(.system(size: 13)).foregroundStyle(.white.opacity(0.85))
                    Text(scene.money(scene.balance)).font(.system(size: 35, weight: .semibold)).minimumScaleFactor(0.6).lineLimit(1)
                }.padding(.vertical, 18)
                HStack {
                    VStack(alignment: .leading, spacing: 4) { Text("In Spaces").font(.caption).foregroundStyle(.white.opacity(0.7)); Text(scene.money(profile.savings)).font(.system(size: 17, weight: .semibold)) }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) { Text("Total balance").font(.caption).foregroundStyle(.white.opacity(0.7)); Text(scene.money(scene.balance + profile.savings)).font(.system(size: 17, weight: .semibold)) }
                }
            }.padding(22).foregroundStyle(.white)
                .background(LinearGradient(colors: [Color(bankHex: 0x168F88), Color(bankHex: 0x005752)], startPoint: .top, endPoint: .bottom))
            VStack(spacing: 18) {
                transactionPanel(scene, title: "Transactions", limit: 6)
                NavigationLink { BankAccountDetail(sceneID: sceneID, theme: theme, savings: true).toolbar(.visible, for: .navigationBar) } label: {
                    HStack { Image(systemName: "square.grid.2x2").font(.title2); VStack(alignment: .leading, spacing: 4) { Text("Spaces").fontWeight(.semibold); Text("Portion money into budgets").font(.caption).foregroundStyle(.secondary) }; Spacer(); Text(scene.money(profile.savings)).fontWeight(.semibold) }.foregroundStyle(palette.ink).padding(18)
                }.bankSurface(radius: 12)
            }.padding(16).background(palette.background).clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20)).padding(.top, -10)
        }
    }

    private func americaAccountRow(_ scene: StudioScene, title: String, balance: Double, suffix: String, savings: Bool = false) -> some View {
        NavigationLink { BankAccountDetail(sceneID: sceneID, theme: theme, savings: savings).toolbar(.visible, for: .navigationBar) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 5) { Text("Bank of America").font(.system(size: 11, weight: .semibold)); BankAmericaSymbol().fill(palette.accent).frame(width: 13, height: 10) }
                HStack(spacing: 8) {
                    Text("\(title) - \(suffix)").font(.system(size: 12))
                    Spacer(minLength: 6)
                    Text(scene.money(balance)).font(.system(size: 15, weight: .semibold)).minimumScaleFactor(0.7).lineLimit(1)
                    Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }.foregroundStyle(palette.ink).padding(.horizontal, 14).padding(.vertical, 15)
        }
    }

    private func compactAccountRow(_ scene: StudioScene, title: String, balance: Double, suffix: String, savings: Bool = false) -> some View {
        NavigationLink { BankAccountDetail(sceneID: sceneID, theme: theme, savings: savings).toolbar(.visible, for: .navigationBar) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 5) { Text(title).font(.system(size: 14)); Text("Savings · ••••\(suffix)").font(.system(size: 10)).foregroundStyle(.secondary) }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) { Text(scene.money(balance)).font(.system(size: 16, weight: .semibold)); Text("Available balance").font(.system(size: 9)).foregroundStyle(.secondary) }
            }.foregroundStyle(palette.ink).padding(14)
        }
    }

    private func hsbcShortcut(_ title: String, symbol: String, destination: BankPlaybackTab) -> some View {
        Button { tab = destination } label: {
            VStack(spacing: 7) {
                Image(systemName: symbol).font(.system(size: 17)).foregroundStyle(palette.accent).frame(width: 42, height: 42).background(.white, in: Circle())
                Text(title).font(.system(size: 10)).multilineTextAlignment(.center).lineLimit(2)
            }.foregroundStyle(.black).frame(maxWidth: .infinity)
        }.buttonStyle(.plain)
    }

    private func accountRow(_ scene: StudioScene, title: String, balance: Double, suffix: String, detail: String, size: CGFloat, savings: Bool = false) -> some View {
        NavigationLink { BankAccountDetail(sceneID: sceneID, theme: theme, savings: savings).toolbar(.visible, for: .navigationBar) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack { Text("\(title) · ••••\(suffix)").font(.system(size: 14, weight: .semibold)); Spacer(); Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary) }
                Text(scene.money(balance)).font(.system(size: size, weight: .medium)).minimumScaleFactor(0.7).lineLimit(1)
                Text(detail).font(.system(size: 12)).foregroundStyle(.secondary)
            }.foregroundStyle(palette.ink).padding(18)
        }
    }

    private func hsbcAccount(_ scene: StudioScene, title: String, balance: Double, suffix: String, savings: Bool) -> some View {
        NavigationLink { BankAccountDetail(sceneID: sceneID, theme: theme, savings: savings).toolbar(.visible, for: .navigationBar) } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack { BankHSBCSymbol().fill(palette.accent).frame(width: 24, height: 13); Spacer(); Image(systemName: "star"); Image(systemName: "ellipsis").rotationEffect(.degrees(90)) }
                Text(title).font(.system(size: 14, weight: .regular))
                Text("00-00-00 | ••••\(suffix)").font(.system(size: 12)).foregroundStyle(.secondary)
                HStack { Text("Available balance").font(.caption).foregroundStyle(.secondary); Spacer(); Text(scene.money(balance)).font(.system(size: 20, weight: .regular)) }
            }.foregroundStyle(.black).padding(13)
        }.bankSurface(radius: 2)
    }

    private func capitalAccountTile(_ scene: StudioScene, title: String, suffix: String, balance: Double, color: Color, savings: Bool = false) -> some View {
        NavigationLink { BankAccountDetail(sceneID: sceneID, theme: theme, savings: savings).toolbar(.visible, for: .navigationBar) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack { Text(title).font(.system(size: 16, weight: .medium)); Spacer(); Text("••••\(suffix)").font(.caption) }
                Text(scene.money(balance)).font(.system(size: 35, weight: .light)).minimumScaleFactor(0.6).lineLimit(1)
                Text("Available balance").font(.system(size: 12))
            }.foregroundStyle(.white).padding(22).frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [color, color.opacity(0.84)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 5))
        }
    }

    private func bankSectionHeader(_ title: String, color: Color) -> some View {
        HStack { Text(title).font(.system(size: 15, weight: .semibold)); Spacer(); Image(systemName: "chevron.up").font(.caption) }
            .foregroundStyle(theme == .chase ? .white : palette.ink).padding(.horizontal, 16).padding(.vertical, 11)
            .background(theme == .chase ? color : Color.white)
            .overlay(alignment: .top) { if theme == .bankOfAmerica { Rectangle().fill(LinearGradient(colors: [Color(bankHex: 0xE31837), Color(bankHex: 0xE31837), Color(bankHex: 0x0052A4)], startPoint: .leading, endPoint: .trailing)).frame(height: 4) } }
    }

    private func actionStrip(_ actions: [(String, String)]) -> some View {
        HStack(alignment: .top, spacing: 4) {
            ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
                Button {
                    if action.0.lowercased().contains("card") { showCard = true }
                    else if action.0.lowercased().contains("deposit") || action.0.lowercased().contains("add money") { tab = .deposits }
                    else if action.0 == "Transfer" { tab = .transfers }
                    else if action.0 == "Activity" { tab = .activity }
                    else { tab = .payments }
                } label: {
                    VStack(spacing: 9) { Image(systemName: action.1).font(.system(size: 22)).frame(height: 27); Text(action.0).font(.system(size: 11, weight: .medium)).multilineTextAlignment(.center) }
                        .frame(maxWidth: .infinity).frame(minHeight: 62)
                }
            }
        }.foregroundStyle(palette.accent)
    }

    private func revolutAction(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { VStack(spacing: 8) { Image(systemName: symbol).font(.system(size: 18, weight: .semibold)).frame(width: 43, height: 43).background(.white.opacity(0.16), in: Circle()); Text(title).font(.system(size: 11, weight: .medium)) }.frame(maxWidth: .infinity) }
    }

    private func transactionPanel(_ scene: StudioScene, title: String, limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text(title).font(.system(size: 17, weight: .semibold)); Spacer(); Button(theme == .starling ? "Search & filter" : "See all") { tab = .activity }.font(.system(size: 12, weight: .medium)) }.padding(16)
            if activity.isEmpty {
                VStack(alignment: .leading, spacing: 8) { Text("No transactions yet").font(.system(size: 15, weight: .medium)); Text("Add a payment or deposit to this account.").font(.system(size: 13)).foregroundStyle(.secondary); Button("Add transaction") { tab = .payments }.font(.system(size: 14, weight: .semibold)) }.padding(.horizontal, 16).padding(.bottom, 20)
            } else {
                ForEach(Array(activity.prefix(limit))) { event in
                    NavigationLink { BankTransactionDetail(event: event, scene: scene, theme: theme).toolbar(.visible, for: .navigationBar) } label: { BankTransactionRow(event: event, scene: scene, theme: theme) }
                    if event.id != activity.prefix(limit).last?.id { Divider().padding(.leading, 66) }
                }
            }
        }.background(theme == .revolut ? Color(bankHex: 0x24262A) : .white, in: RoundedRectangle(cornerRadius: theme == .monzo || theme == .revolut ? 15 : 10))
    }

    private func activityPage(_ scene: StudioScene) -> some View {
        List {
            Section {
                if filteredActivity.isEmpty {
                    ContentUnavailableView(search.isEmpty ? "No transactions yet" : "No matching transactions", systemImage: "list.bullet.rectangle", description: Text(search.isEmpty ? "Payments and deposits appear here." : "Try another name or amount."))
                } else {
                    ForEach(filteredActivity) { event in
                        NavigationLink { BankTransactionDetail(event: event, scene: scene, theme: theme).toolbar(.visible, for: .navigationBar) } label: { BankTransactionRow(event: event, scene: scene, theme: theme).padding(.horizontal, -16) }
                    }
                }
            } header: { Text("Transactions") }
        }.listStyle(.plain).searchable(text: $search, prompt: "Search transactions")
    }

    private var filteredActivity: [SceneEvent] {
        guard !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return activity }
        return activity.filter { $0.detail.localizedCaseInsensitiveContains(search) || $0.title.localizedCaseInsensitiveContains(search) || String($0.amount).contains(search) }
    }

    private func morePage(_ scene: StudioScene) -> some View {
        List {
            Section("Your account") {
                Button { showProfile = true } label: { Label("Profile and account details", systemImage: "person.crop.circle") }
                NavigationLink { BankAccountDetail(sceneID: sceneID, theme: theme, savings: false).toolbar(.visible, for: .navigationBar) } label: { Label("Current account", systemImage: "building.columns") }
                NavigationLink { BankAccountDetail(sceneID: sceneID, theme: theme, savings: true).toolbar(.visible, for: .navigationBar) } label: { Label(theme == .starling ? "Spaces" : "Savings", systemImage: "archivebox") }
                Button { showCard = true } label: { Label("Manage cards", systemImage: "creditcard") }
            }
            Section("Statements") {
                NavigationLink { BankStatementPage(sceneID: sceneID, theme: theme).toolbar(.visible, for: .navigationBar) } label: { Label("Account statement", systemImage: "doc.text") }
                Button { tab = .activity } label: { Label("Transaction history", systemImage: "clock.arrow.circlepath") }
            }
            if !cleanPlayback {
                Section("Bank appearance") {
                    ForEach(BankTheme.allCases) { bank in
                        Button { var updated = profile; updated.theme = bank; if store.updateBankProfile(updated) { tab = .home } } label: {
                            HStack { Text(bank.name); Spacer(); Text(bank.country).font(.caption).foregroundStyle(.secondary); if bank == theme { Image(systemName: "checkmark") } }
                        }
                    }
                }
            }
        }.listStyle(.insetGrouped)
    }

    private var topTabs: some View {
        HStack(spacing: 0) {
            hsbcTopTab(.home, title: "Home", symbol: "house.fill")
            hsbcTopTab(.payments, title: "Pay", symbol: nil)
            hsbcTopTab(.cards, title: "Cards", symbol: nil)
            hsbcTopTab(.spaces, title: "Invest", symbol: nil)
            hsbcTopTab(.more, title: "More", symbol: "line.3.horizontal")
        }
            .padding(.vertical, 5).background(.white).overlay(alignment: .bottom) { Divider() }
    }

    private func hsbcTopTab(_ value: BankPlaybackTab, title: String, symbol: String?) -> some View {
        Button { tab = value } label: {
            Group {
                if let symbol { Image(systemName: symbol).font(.system(size: 19)) }
                else { Text(title).font(.system(size: 13)) }
            }.frame(maxWidth: .infinity).frame(height: 44)
                .overlay(alignment: .bottom) { if tab == value { Rectangle().fill(palette.accent).frame(width: 20, height: 2) } }
        }
        .foregroundStyle(.black)
        .accessibilityLabel(title)
        .accessibilityAddTraits(tab == value ? .isSelected : [])
        .accessibilityIdentifier("bank-tab-\(value.rawValue)")
    }

    private var bottomTabs: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(bankNavigation.enumerated()), id: \.offset) { _, item in
                tabButton(item.0, title: item.1, symbol: item.2)
            }
        }.padding(.top, 10).padding(.bottom, 6).background(theme == .revolut ? Color(bankHex: 0x080D15) : .white).overlay(alignment: .top) { Divider() }
    }

    private var bankNavigation: [(BankPlaybackTab, String, String)] {
        switch theme {
        case .chase:
            return [(.home,"Accounts","building.columns"),(.payments,"Pay & transfer","arrow.left.arrow.right"),(.activity,"Plan & track","chart.bar"),(.cards,"Cards","creditcard"),(.more,"More","square.grid.2x2")]
        case .bankOfAmerica:
            return [(.home,"Accounts","building.columns"),(.payments,"Pay & transfer","arrow.left.arrow.right"),(.deposits,"Deposit checks","doc.text.viewfinder"),(.spaces,"Invest","chart.pie")]
        case .citi:
            return [(.home,"Accounts","building.columns"),(.payments,"Payments","arrow.left.arrow.right"),(.cards,"Services","creditcard"),(.more,"Profile","person.crop.circle")]
        case .monzo:
            return [(.home,"Home","house.fill"),(.activity,"Trends","chart.bar"),(.payments,"Payments","arrow.left.arrow.right"),(.more,"Help","questionmark")]
        case .starling:
            return [(.payments,"Payments","arrow.left.arrow.right"),(.activity,"Spending","chart.bar"),(.home,"Home","house.fill"),(.cards,"Cards","creditcard"),(.spaces,"Spaces","square.grid.2x2")]
        case .barclays:
            return [(.home,"Home","house.fill"),(.payments,"Pay","arrow.left.arrow.right"),(.cards,"Cards","creditcard"),(.more,"Products","square.grid.2x2"),(.activity,"Activity","list.bullet.rectangle")]
        case .wellsFargo:
            return [(.home,"Accounts","building.columns"),(.deposits,"Deposit","doc.text.viewfinder"),(.payments,"Pay & transfer","arrow.left.arrow.right"),(.cards,"Cards","creditcard"),(.more,"Menu","line.3.horizontal")]
        case .capitalOne:
            return [(.home,"Accounts","building.columns"),(.payments,"Payments","arrow.left.arrow.right"),(.cards,"Cards","creditcard"),(.more,"Profile","person.crop.circle")]
        case .natWest:
            return [(.home,"Home","house.fill"),(.payments,"Payments","arrow.left.arrow.right"),(.activity,"Spending","chart.bar"),(.cards,"Cards","creditcard"),(.more,"Help","questionmark.circle")]
        case .lloyds:
            return [(.home,"Home","house.fill"),(.payments,"Pay & transfer","arrow.left.arrow.right"),(.activity,"Spending","chart.bar"),(.cards,"Cards","creditcard"),(.more,"Profile","person.crop.circle")]
        case .revolut:
            return [(.home,"Home","house.fill"),(.spaces,"Accounts","building.columns"),(.payments,"Payments","arrow.left.arrow.right"),(.cards,"Cards","creditcard"),(.more,"More","square.grid.2x2")]
        case .hsbc:
            return []
        }
    }

    private func tabButton(_ value: BankPlaybackTab, title: String, symbol: String) -> some View {
        Button { tab = value } label: { VStack(spacing: 5) { Image(systemName: symbol).font(.system(size: 19, weight: tab == value ? .semibold : .regular)).frame(height: 23); Text(title).font(.system(size: 10, weight: tab == value ? .semibold : .regular)).lineLimit(1).minimumScaleFactor(0.75) }.frame(maxWidth: .infinity).frame(minHeight: 44) }
            .foregroundStyle(tab == value ? palette.accent : Color.secondary)
            .accessibilityAddTraits(tab == value ? .isSelected : [])
            .accessibilityIdentifier("bank-tab-\(value.rawValue)")
    }
}

private enum BankPlaybackTab: String { case home, payments, activity, cards, more, deposits, spaces, transfers, statement }

private struct BankAccountDetail: View {
    @EnvironmentObject private var store: StudioStore
    let sceneID: UUID
    let theme: BankTheme
    let savings: Bool
    private var scene: StudioScene? { store.scenes.first { $0.id == sceneID } }
    private var profile: BankProfile { store.bankProfile(for: sceneID) }
    var body: some View {
        Group {
            if let scene {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(savings ? "Savings" : profile.accountName).font(.system(size: 18, weight: .medium))
                            Text(scene.money(savings ? profile.savings : scene.balance)).font(.system(size: 35, weight: .semibold)).minimumScaleFactor(0.6).lineLimit(1)
                            Text("Available balance").font(.system(size: 13)).foregroundStyle(.secondary)
                        }.padding(.vertical, 14)
                        LabeledContent("Account ending", value: savings ? theme.playbackSavingsSuffix : profile.accountSuffix)
                        LabeledContent("Account holder", value: profile.holderName ?? scene.name)
                        LabeledContent("Currency", value: scene.currency)
                    }
                    Section {
                        NavigationLink { BankSavingsTransferPage(sceneID: sceneID, theme: theme, initiallyToSavings: !savings).toolbar(.visible, for: .navigationBar) } label: { Label("Transfer between my accounts", systemImage: "arrow.left.arrow.right") }
                        if !savings {
                            NavigationLink { BankPaymentPage(sceneID: sceneID, theme: theme).toolbar(.visible, for: .navigationBar) } label: { Label("Pay & transfer", systemImage: "arrow.left.arrow.right") }
                        }
                        NavigationLink { BankStatementPage(sceneID: sceneID, theme: theme, savings: savings).toolbar(.visible, for: .navigationBar) } label: { Label("Statement", systemImage: "doc.text") }
                    }
                    Section("Transactions") {
                            let events = store.events.filter { $0.sceneID == sceneID && (!savings || $0.savingsTransfer == true) }.sorted { $0.date > $1.date }
                            if events.isEmpty { Text("No transactions yet").foregroundStyle(.secondary) }
                            ForEach(events) { event in
                                NavigationLink { BankTransactionDetail(event: event, scene: scene, theme: theme, savings: savings).toolbar(.visible, for: .navigationBar) } label: { BankTransactionRow(event: event, scene: scene, theme: theme, savings: savings).padding(.horizontal, -16) }
                            }
                    }
                }.listStyle(.insetGrouped)
            } else { ContentUnavailableView("Account unavailable", systemImage: "building.columns") }
        }.navigationTitle(savings ? "Savings" : "Account details").navigationBarTitleDisplayMode(.inline).tint(BankPalette(theme).accent)
    }
}

private struct BankTransactionRow: View {
    let event: SceneEvent
    let scene: StudioScene
    let theme: BankTheme
    var savings = false
    private var outflow: Bool { savings && event.savingsTransfer == true ? !event.kind.isOutflow : event.kind.isOutflow }
    private var detail: String { savings && event.savingsTransfer == true ? (event.kind.isOutflow ? "Transfer from checking" : "Transfer to checking") : (event.detail.isEmpty ? event.title : event.detail) }
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.savingsTransfer == true ? (outflow ? "arrow.up.right" : "arrow.down.left") : event.kind.symbol).font(.system(size: 18, weight: .medium))
                .foregroundStyle(BankPalette(theme).accent).frame(width: 38, height: 38)
                .background(BankPalette(theme).accent.opacity(0.08), in: RoundedRectangle(cornerRadius: theme == .monzo ? 9 : 20))
            VStack(alignment: .leading, spacing: 5) {
                Text(detail).font(.system(size: 14, weight: .medium)).lineLimit(2)
                Text(event.date.formatted(date: .abbreviated, time: .omitted)).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text((outflow ? "−" : "+") + scene.money(event.amount)).font(.system(size: 14, weight: .semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                .foregroundStyle(outflow ? BankPalette(theme).ink : Color(bankHex: 0x168067))
        }.foregroundStyle(BankPalette(theme).ink).padding(.horizontal, 16).padding(.vertical, 12)
    }
}

private struct BankTransactionDetail: View {
    let event: SceneEvent
    let scene: StudioScene
    let theme: BankTheme
    var savings = false
    private var outflow: Bool { savings && event.savingsTransfer == true ? !event.kind.isOutflow : event.kind.isOutflow }
    private var detail: String { savings && event.savingsTransfer == true ? (event.kind.isOutflow ? "Transfer from checking" : "Transfer to checking") : (event.detail.isEmpty ? event.title : event.detail) }
    var body: some View {
        List {
            Section {
                VStack(spacing: 14) {
                    Image(systemName: event.savingsTransfer == true ? (outflow ? "arrow.up.right" : "arrow.down.left") : event.kind.symbol).font(.system(size: 30)).foregroundStyle(BankPalette(theme).accent).frame(width: 70, height: 70).background(BankPalette(theme).accent.opacity(0.09), in: Circle())
                    Text(detail).font(.system(size: 22, weight: .semibold)).multilineTextAlignment(.center)
                    Text((outflow ? "−" : "+") + scene.money(event.amount)).font(.system(size: 33, weight: .semibold)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
                    Label("Completed", systemImage: "checkmark.circle.fill").font(.system(size: 14)).foregroundStyle(Color(bankHex: 0x168067))
                }.frame(maxWidth: .infinity).padding(.vertical, 22)
            }
            Section("Details") {
                LabeledContent("Type", value: event.savingsTransfer == true ? "Own account transfer" : event.title)
                LabeledContent("Date", value: event.date.formatted(date: .long, time: .shortened))
                LabeledContent("Account", value: savings ? "Savings" : scene.name)
                LabeledContent("Currency", value: scene.currency)
                LabeledContent("Reference", value: String(event.id.uuidString.prefix(12)))
            }
        }.listStyle(.insetGrouped).navigationTitle("Transaction").navigationBarTitleDisplayMode(.inline)
    }
}

private struct BankPaymentPage: View {
    @EnvironmentObject private var store: StudioStore
    let sceneID: UUID
    let theme: BankTheme
    @State private var recipient = ""
    @State private var amount = ""
    @State private var reference = ""
    @State private var incoming = false
    @State private var confirmation = false
    @State private var completed: SceneEvent?
    init(sceneID: UUID, theme: BankTheme, initiallyIncoming: Bool = false) {
        self.sceneID = sceneID
        self.theme = theme
        _incoming = State(initialValue: initiallyIncoming)
    }
    private var scene: StudioScene? { store.scenes.first { $0.id == sceneID } }
    private var parsedAmount: Double? { Simulation.parseAmount(amount) }
    private var valid: Bool {
        guard let value = parsedAmount, let scene else { return false }
        let name = recipient.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && name.count <= 100 && reference.count <= 100 && Simulation.validAmount(value) && (incoming ? scene.balance + value <= 1_000_000_000 && scene.sales + value <= 1_000_000_000 : value <= scene.balance)
    }
    var body: some View {
        Group {
            if let scene {
                Group {
                    if theme == .chase && !incoming && completed == nil {
                        chasePayment(scene)
                    } else {
                        paymentForm(scene)
                    }
                }
                .confirmationDialog(incoming ? "Add money?" : "Send payment?", isPresented: $confirmation, titleVisibility: .visible) {
                    Button(incoming ? "Confirm deposit" : "Confirm payment") { commit() }
                } message: { Text("\(scene.money(parsedAmount ?? 0)) \(incoming ? "from" : "to") \(recipient.trimmingCharacters(in: .whitespacesAndNewlines))") }
            } else { ContentUnavailableView("Account unavailable", systemImage: "building.columns") }
        }.tint(BankPalette(theme).accent).navigationTitle(theme == .chase && !incoming ? "Enter Amount" : "Payments").navigationBarTitleDisplayMode(.inline).accessibilityIdentifier("bank.payments")
    }

    private func paymentForm(_ scene: StudioScene) -> some View {
        Form {
                    if let completed {
                        Section {
                            VStack(spacing: 14) {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 50)).foregroundStyle(Color(bankHex: 0x168067))
                                Text(completed.kind.isOutflow ? "Payment sent" : "Money added").font(.system(size: 25, weight: .semibold))
                                Text(scene.money(completed.amount)).font(.system(size: 30, weight: .semibold))
                                Text(completed.detail).font(.system(size: 15)).multilineTextAlignment(.center)
                                Button("Make another payment") { self.completed = nil; amount = ""; reference = "" }
                            }.frame(maxWidth: .infinity).padding(.vertical, 24)
                        }
                    } else {
                        Section {
                            Picker("Payment type", selection: $incoming) { Text("Send money").tag(false); Text("Add money").tag(true) }.pickerStyle(.segmented)
                            LabeledContent(incoming ? "To account" : "From account", value: store.bankProfile(for: sceneID).accountName)
                            LabeledContent("Available", value: scene.money(scene.balance))
                            NavigationLink { BankSavingsTransferPage(sceneID: sceneID, theme: theme).toolbar(.visible, for: .navigationBar) } label: { Label("Between my accounts", systemImage: "arrow.left.arrow.right") }
                        }
                        Section(incoming ? "Sender" : "Payee") {
                            TextField(incoming ? "Sender name" : "Payee name", text: $recipient).textContentType(.name).autocorrectionDisabled()
                            TextField("Amount (\(scene.currency))", text: $amount).keyboardType(.decimalPad).accessibilityIdentifier("bank.payment.amount")
                            TextField("Reference (optional)", text: $reference).autocorrectionDisabled()
                        }
                        Section {
                            Button(incoming ? "Review deposit" : "Review payment") { confirmation = true }.disabled(!valid).frame(maxWidth: .infinity).fontWeight(.semibold).accessibilityIdentifier("bank.payment.review")
                        } footer: {
                            if let value = parsedAmount, !incoming, value > scene.balance { Text("The payment exceeds this account's available balance.") }
                        }
                        if let error = store.error { Section { Text(error).font(.footnote).foregroundStyle(.red) } }
                    }
        }
    }

    private func chasePayment(_ scene: StudioScene) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill").font(.system(size: 40)).foregroundStyle(.gray.opacity(0.45))
                    VStack(alignment: .leading, spacing: 5) {
                        TextField("Recipient name", text: $recipient).textContentType(.name).autocorrectionDisabled()
                        Text("Send money").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Image(systemName: "list.bullet.rectangle").foregroundStyle(BankPalette(theme).accent)
                }.padding(.top, 8)
                VStack(spacing: 9) {
                    Text("Amount").font(.system(size: 12)).foregroundStyle(.secondary)
                    TextField("0.00", text: $amount).keyboardType(.decimalPad)
                        .font(.system(size: 39, weight: .light)).multilineTextAlignment(.center)
                        .accessibilityIdentifier("bank.payment.amount")
                    Divider()
                }
                VStack(alignment: .leading, spacing: 7) {
                    Text("Memo (optional)").font(.system(size: 12)).foregroundStyle(.secondary)
                    TextField("Add a memo", text: $reference).font(.system(size: 17)).autocorrectionDisabled()
                    Divider()
                }
                VStack(alignment: .leading, spacing: 7) {
                    Text("Pay from").font(.system(size: 12)).foregroundStyle(.secondary)
                    HStack {
                        Text("CHECKING (...\(store.bankProfile(for: sceneID).accountSuffix)) \(scene.money(scene.balance))")
                            .font(.system(size: 14)).foregroundStyle(BankPalette(theme).accent)
                        Spacer()
                        NavigationLink { BankSavingsTransferPage(sceneID: sceneID, theme: theme).toolbar(.visible, for: .navigationBar) } label: { Image(systemName: "chevron.down") }
                            .accessibilityLabel("Transfer between accounts")
                    }
                    Divider()
                }
                HStack {
                    VStack(alignment: .leading, spacing: 7) { Text("Send on").font(.system(size: 12)).foregroundStyle(.secondary); Text("Today").font(.system(size: 14)) }
                    Spacer()
                    Image(systemName: "calendar").foregroundStyle(BankPalette(theme).accent)
                }
                if let value = parsedAmount, value > scene.balance {
                    Text("The payment exceeds this account's available balance.").font(.system(size: 13)).foregroundStyle(.red)
                }
                if let error = store.error { Text(error).font(.footnote).foregroundStyle(.red) }
                Button("Review & send") { confirmation = true }
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(BankPalette(theme).accent, in: RoundedRectangle(cornerRadius: 3))
                    .disabled(!valid).opacity(valid ? 1 : 0.45)
                    .accessibilityIdentifier("bank.payment.review")
                    .padding(.top, 32)
            }.padding(22)
        }.background(.white)
    }
    private func commit() {
        guard valid, let value = parsedAmount else { return }
        let name = recipient.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        completed = store.emit(kind: incoming ? .deposit : .payment, amount: value, detail: note.isEmpty ? name : "\(name) · \(note)", sceneID: sceneID)
    }
}

private struct BankSavingsTransferPage: View {
    @EnvironmentObject private var store: StudioStore
    let sceneID: UUID
    let theme: BankTheme
    @State private var amount = ""
    @State private var toSavings = true
    @State private var review = false
    @State private var completed = false
    init(sceneID: UUID, theme: BankTheme, initiallyToSavings: Bool = true) {
        self.sceneID = sceneID
        self.theme = theme
        _toSavings = State(initialValue: initiallyToSavings)
    }
    private var scene: StudioScene? { store.scenes.first { $0.id == sceneID } }
    private var profile: BankProfile { store.bankProfile(for: sceneID) }
    private var parsedAmount: Double? { Simulation.parseAmount(amount) }
    private var valid: Bool {
        guard let value = parsedAmount, Simulation.validAmount(value), let scene, scene.kind == .banking else { return false }
        return toSavings ? value <= scene.balance && profile.savings + value <= 1_000_000_000 : value <= profile.savings && scene.balance + value <= 1_000_000_000
    }
    var body: some View {
        Group {
            if let scene {
                Form {
                    if completed {
                        Section {
                            VStack(spacing: 14) {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 50)).foregroundStyle(Color(bankHex: 0x168067))
                                Text("Transfer complete").font(.system(size: 25, weight: .semibold))
                                Text(scene.money(parsedAmount ?? 0)).font(.system(size: 30, weight: .semibold))
                                Text(toSavings ? "Checking → Savings" : "Savings → Checking").font(.system(size: 15))
                                Button("Make another transfer") { completed = false; amount = "" }
                            }.frame(maxWidth: .infinity).padding(.vertical, 24)
                        }
                        Section("Updated balances") {
                            LabeledContent(profile.accountName, value: scene.money(scene.balance))
                            LabeledContent("Savings", value: scene.money(profile.savings))
                        }
                    } else {
                        Section("Transfer between my accounts") {
                            Picker("Direction", selection: $toSavings) { Text("To savings").tag(true); Text("From savings").tag(false) }.pickerStyle(.segmented)
                            LabeledContent("From", value: toSavings ? profile.accountName : "Savings")
                            LabeledContent("To", value: toSavings ? "Savings" : profile.accountName)
                            LabeledContent("Available", value: scene.money(toSavings ? scene.balance : profile.savings))
                            TextField("Amount (\(scene.currency))", text: $amount).keyboardType(.decimalPad).accessibilityIdentifier("bank-transfer-amount")
                        }
                        Section {
                            Button("Review transfer") { review = true }.disabled(!valid).fontWeight(.semibold).frame(maxWidth: .infinity).accessibilityIdentifier("bank-transfer-review")
                        } footer: {
                            if let value = parsedAmount, value > (toSavings ? scene.balance : profile.savings) { Text("The amount exceeds the selected account's available balance.") }
                        }
                        if let error = store.error { Section { Text(error).font(.footnote).foregroundStyle(.red) } }
                    }
                }
                .confirmationDialog("Confirm transfer", isPresented: $review, titleVisibility: .visible) {
                    Button("Confirm transfer") {
                        guard valid, let value = parsedAmount else { return }
                        completed = store.transferSavings(sceneID: sceneID, amount: value, toSavings: toSavings)
                    }
                } message: { Text("\(scene.money(parsedAmount ?? 0)) \(toSavings ? "from checking to savings" : "from savings to checking")") }
            } else { ContentUnavailableView("Account unavailable", systemImage: "building.columns") }
        }.navigationTitle("Transfer").navigationBarTitleDisplayMode(.inline).tint(BankPalette(theme).accent)
    }
}

private struct BankCardPage: View {
    @EnvironmentObject private var store: StudioStore
    let sceneID: UUID
    let theme: BankTheme
    private var profile: BankProfile { store.bankProfile(for: sceneID) }
    private var holderName: String { profile.holderName ?? store.scenes.first(where: { $0.id == sceneID })?.name ?? profile.accountName }
    private var palette: BankPalette { BankPalette(theme) }
    var body: some View {
        Group {
            if theme == .chase { chaseCardLock }
            else { cardOverview }
        }
        .background(palette.background).tint(palette.accent).accessibilityIdentifier("bank.cards")
    }

    private var cardOverview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Your debit card").font(.system(size: 27, weight: .bold))
                VStack(alignment: .leading, spacing: 34) {
                    HStack { BankBrandMark(theme: theme, color: .white); Spacer(); Image(systemName: "wave.3.right").font(.title2) }
                    HStack { RoundedRectangle(cornerRadius: 4).fill(Color(bankHex: 0xD7BC86)).frame(width: 38, height: 29); Spacer(); if profile.cardFrozen { Label("Frozen", systemImage: "snowflake").font(.system(size: 14, weight: .semibold)) } }
                    VStack(alignment: .leading, spacing: 10) { Text("••••  ••••  ••••  \(profile.accountSuffix)").font(.system(size: 20, weight: .medium, design: .monospaced)); HStack { Text(holderName.uppercased()).font(.system(size: 12, weight: .medium)); Spacer(); Text("VISA").font(.system(size: 22, weight: .bold)).italic() } }
                }.foregroundStyle(.white).padding(24).frame(maxWidth: .infinity)
                    .background(LinearGradient(colors: [cardColors.0, cardColors.1], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18))
                    .opacity(profile.cardFrozen ? 0.65 : 1)
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(isOn: Binding(get: { profile.cardFrozen }, set: { value in var updated = profile; updated.cardFrozen = value; _ = store.updateBankProfile(updated) })) {
                        Label(theme == .capitalOne || theme == .citi ? "Lock card" : "Freeze card", systemImage: profile.cardFrozen ? "lock.fill" : "snowflake")
                    }.font(.system(size: 17, weight: .medium)).accessibilityIdentifier("bank.card.freeze")
                    Text(profile.cardFrozen ? "Your card is frozen. Unfreeze it whenever you're ready." : "Temporarily freeze your card. Unfreeze it at any time.").font(.system(size: 14)).foregroundStyle(.secondary)
                }.padding(20).background(theme == .revolut ? Color(bankHex: 0x24262A) : .white, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 14) {
                    LabeledContent("Card holder", value: holderName)
                    Divider()
                    LabeledContent("Account ending", value: profile.accountSuffix)
                    Divider()
                    LabeledContent("Card status", value: profile.cardFrozen ? "Frozen" : "Active")
                }.font(.system(size: 15)).padding(20).background(theme == .revolut ? Color(bankHex: 0x24262A) : .white, in: RoundedRectangle(cornerRadius: 12))
            }.padding(22)
        }
    }

    private var cardColors: (Color, Color) {
        switch theme {
        case .monzo: return (Color(bankHex: 0xFF4C43), Color(bankHex: 0xFF4C43))
        case .starling: return (Color(bankHex: 0xF291EF), Color(bankHex: 0xF8AAF1))
        case .barclays: return (Color(bankHex: 0x00AEEF), Color(bankHex: 0x007CB3))
        case .natWest: return (Color(bankHex: 0x8647A9), Color(bankHex: 0x54256F))
        case .revolut: return (Color(bankHex: 0x6941CF), Color(bankHex: 0x193B81))
        default: return (palette.accent, palette.accent.opacity(0.8))
        }
    }

    private var chaseCardLock: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                Text("Lock & Unlock Your Card").font(.system(size: 20, weight: .medium))
                    .frame(maxWidth: .infinity).padding(.vertical, 17).foregroundStyle(.white).background(palette.accent)
                VStack(alignment: .leading, spacing: 13) {
                    Text("DEBIT/ATM CARD (...\(profile.accountSuffix))").font(.system(size: 14))
                    HStack {
                        Toggle(profile.cardFrozen ? "Locked" : "Unlocked", isOn: Binding(get: { profile.cardFrozen }, set: { value in var updated = profile; updated.cardFrozen = value; _ = store.updateBankProfile(updated) }))
                            .toggleStyle(.switch).tint(palette.accent)
                            .accessibilityIdentifier("bank.card.freeze")
                        Image(systemName: profile.cardFrozen ? "lock.fill" : "lock.open.fill").foregroundStyle(profile.cardFrozen ? palette.accent : .secondary)
                    }
                    if profile.cardFrozen {
                        Label("You've locked your card.", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 13)).foregroundStyle(Color(bankHex: 0x168067))
                    }
                    Divider().padding(.top, 9)
                }.padding(.horizontal, 20)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Misplaced your card?").font(.system(size: 20, weight: .regular))
                    Text("Lock your card to stop new purchases and ATM withdrawals. Unlock it when you're ready to use it again.")
                        .font(.system(size: 14)).foregroundStyle(.secondary)
                    Text("Account ending: \(profile.accountSuffix)").font(.system(size: 13)).foregroundStyle(.secondary)
                }.padding(.horizontal, 20)
            }.padding(.bottom, 24)
        }.background(.white)
    }
}

private struct BankProfileEditor: View {
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    let sceneID: UUID
    @State private var name = ""
    @State private var accountHolder = ""
    @State private var suffix = ""
    @State private var savings = ""
    private var profile: BankProfile { store.bankProfile(for: sceneID) }
    private var valid: Bool {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = suffix.utf8.allSatisfy { (48...57).contains($0) }
        guard let value = Simulation.parseAmount(savings) else { return false }
        return !clean.isEmpty && clean.count <= 80 && accountHolder.trimmingCharacters(in: .whitespacesAndNewlines).count <= 80 && suffix.count == 4 && digits && (0...1_000_000_000).contains(value)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("Account name", text: $name)
                    TextField("Account holder", text: $accountHolder).textContentType(.name)
                    TextField("Account ending (4 digits)", text: $suffix).keyboardType(.numberPad)
                    TextField("Savings balance", text: $savings).keyboardType(.decimalPad)
                }
                Section("Appearance") {
                    LabeledContent("Bank", value: profile.theme.name)
                    Text("Choose a bank from the header or More tab.").font(.footnote).foregroundStyle(.secondary)
                }
                if let error = store.error { Section { Text(error).foregroundStyle(.red).font(.footnote) } }
            }
            .navigationTitle("Account profile").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") {
                    guard valid, let value = Simulation.parseAmount(savings) else { return }
                    var updated = profile
                    updated.accountName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    let holder = accountHolder.trimmingCharacters(in: .whitespacesAndNewlines)
                    updated.holderName = holder.isEmpty ? nil : holder
                    updated.accountSuffix = suffix
                    updated.savings = value
                    if store.updateBankProfile(updated) { dismiss() }
                }.disabled(!valid) }
            }
            .onAppear { name = profile.accountName; accountHolder = profile.holderName ?? store.scenes.first(where: { $0.id == sceneID })?.name ?? ""; suffix = profile.accountSuffix; savings = profile.savings.formatted(.number.grouping(.never)) }
        }
    }
}

private struct BankStatementPage: View {
    @EnvironmentObject private var store: StudioStore
    let sceneID: UUID
    let theme: BankTheme
    var savings = false
    var body: some View {
        Group {
            if let scene = store.scenes.first(where: { $0.id == sceneID }) {
                List {
                    Section {
                        BankBrandMark(theme: theme, color: BankPalette(theme).accent).padding(.vertical, 8)
                        LabeledContent("Account", value: savings ? "Savings" : store.bankProfile(for: sceneID).accountName)
                        LabeledContent("Account holder", value: store.bankProfile(for: sceneID).holderName ?? scene.name)
                        LabeledContent("Account ending", value: savings ? theme.playbackSavingsSuffix : store.bankProfile(for: sceneID).accountSuffix)
                        LabeledContent("Date", value: Date().formatted(date: .long, time: .omitted))
                        LabeledContent("Closing balance", value: scene.money(savings ? store.bankProfile(for: sceneID).savings : scene.balance))
                    }
                    Section("Transactions") {
                        let events = store.events.filter { $0.sceneID == sceneID && (!savings || $0.savingsTransfer == true) }.sorted { $0.date > $1.date }
                        if events.isEmpty { Text("No transactions in this statement").foregroundStyle(.secondary) }
                        ForEach(events) { event in BankTransactionRow(event: event, scene: scene, theme: theme, savings: savings).padding(.horizontal, -16) }
                    }
                }.listStyle(.insetGrouped)
            } else { ContentUnavailableView("Account unavailable", systemImage: "doc.text") }
        }.navigationTitle("Account statement").navigationBarTitleDisplayMode(.inline)
    }
}

private struct BankPalette {
    let accent: Color
    let header: Color
    let headerInk: Color
    let background: Color
    let ink: Color
    let darkHeader: Bool
    init(_ theme: BankTheme) {
        ink = theme == .revolut ? .white : Color(bankHex: 0x151D28)
        switch theme {
        case .chase: accent = Color(bankHex: 0x0069AA); header = accent; background = Color(bankHex: 0xF3F4F6); darkHeader = true
        case .bankOfAmerica: accent = Color(bankHex: 0xE31837); header = .white; background = Color(bankHex: 0xF2F2F2); darkHeader = false
        case .wellsFargo: accent = Color(bankHex: 0xD71E28); header = Color(bankHex: 0xFAF8F3); background = header; darkHeader = false
        case .citi: accent = Color(bankHex: 0x056DAE); header = Color(bankHex: 0x087BAC); background = Color(bankHex: 0xF1F4F5); darkHeader = true
        case .capitalOne: accent = Color(bankHex: 0x004A6F); header = .white; background = Color(bankHex: 0xF5F5F5); darkHeader = false
        case .hsbc: accent = Color(bankHex: 0xDB0011); header = .white; background = Color(bankHex: 0xF1F2F3); darkHeader = false
        case .barclays: accent = Color(bankHex: 0x007EB6); header = .white; background = Color(bankHex: 0xF5F7F8); darkHeader = false
        case .lloyds: accent = Color(bankHex: 0x007B44); header = .white; background = Color(bankHex: 0xF1F3F3); darkHeader = false
        case .natWest: accent = Color(bankHex: 0x5A287D); header = .white; background = Color(bankHex: 0xF7F4FA); darkHeader = false
        case .monzo: accent = Color(bankHex: 0x007D8A); header = .white; background = Color(bankHex: 0xF3F7F6); darkHeader = false
        case .revolut: accent = Color(bankHex: 0x1A66F3); header = Color(bankHex: 0x243247); background = Color(bankHex: 0x080D15); darkHeader = true
        case .starling: accent = Color(bankHex: 0x007C79); header = Color(bankHex: 0x168F88); background = Color(bankHex: 0xF6F7F7); darkHeader = true
        }
        headerInk = darkHeader ? .white : ink
    }
}

private struct BankBrandMark: View {
    let theme: BankTheme
    let color: Color
    var body: some View {
        HStack(spacing: 6) {
            switch theme {
            case .chase:
                Text("CHASE").font(.system(size: 20, weight: .bold)).tracking(1)
                BankChaseSymbol().fill(color).frame(width: 24, height: 24)
            case .bankOfAmerica:
                Text("Bank of America").font(.system(size: 17, weight: .semibold))
                BankAmericaSymbol().fill(Color(bankHex: 0xE31837)).frame(width: 22, height: 17)
            case .wellsFargo:
                Text("WELLS FARGO").font(.system(size: 18, weight: .bold, design: .serif))
            case .citi:
                Text("citi").font(.system(size: 28, weight: .bold)).overlay(alignment: .top) { BankCitiArc().stroke(Color(bankHex: 0xE31B54), lineWidth: 2.4).frame(width: 24, height: 8).offset(y: 1) }
            case .capitalOne:
                Text("CapitalOne").font(.system(size: 20, weight: .bold)).italic().overlay(alignment: .topTrailing) { BankCitiArc().stroke(Color(bankHex: 0xD51E35), lineWidth: 3).frame(width: 50, height: 7).offset(y: -4) }
            case .hsbc:
                BankHSBCSymbol().fill(Color(bankHex: 0xDB0011)).frame(width: 32, height: 18)
                Text("HSBC UK").font(.system(size: 18, weight: .semibold))
            case .barclays: Text("BARCLAYS").font(.system(size: 19, weight: .bold)).tracking(0.6)
            case .lloyds: Text("LLOYDS").font(.system(size: 19, weight: .bold)).tracking(1)
            case .natWest: Text("NatWest").font(.system(size: 21, weight: .bold))
            case .monzo: Text("monzo").font(.system(size: 25, weight: .bold))
            case .revolut: Text("Revolut").font(.system(size: 24, weight: .bold))
            case .starling: Text("starling").font(.system(size: 23, weight: .medium))
            }
        }.foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.75)
    }
}

private struct BankHSBCSymbol: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let points: [[CGPoint]] = [
            [CGPoint(x: 0, y: 0.5), CGPoint(x: 0.25, y: 0), CGPoint(x: 0.25, y: 1)],
            [CGPoint(x: 0.25, y: 0), CGPoint(x: 0.75, y: 0), CGPoint(x: 0.5, y: 0.5)],
            [CGPoint(x: 0.25, y: 1), CGPoint(x: 0.75, y: 1), CGPoint(x: 0.5, y: 0.5)],
            [CGPoint(x: 1, y: 0.5), CGPoint(x: 0.75, y: 0), CGPoint(x: 0.75, y: 1)]
        ]
        for triangle in points { p.move(to: CGPoint(x: rect.minX + triangle[0].x * rect.width, y: rect.minY + triangle[0].y * rect.height)); for point in triangle.dropFirst() { p.addLine(to: CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height)) }; p.closeSubpath() }
        return p
    }
}

private struct BankChaseSymbol: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points: [[CGPoint]] = [
            [.init(x: 0.3, y: 0), .init(x: 0.7, y: 0), .init(x: 0.7, y: 0.3), .init(x: 0.3, y: 0.3)],
            [.init(x: 0.7, y: 0), .init(x: 1, y: 0.3), .init(x: 1, y: 0.7), .init(x: 0.7, y: 0.7)],
            [.init(x: 1, y: 0.7), .init(x: 0.7, y: 1), .init(x: 0.3, y: 1), .init(x: 0.3, y: 0.7)],
            [.init(x: 0.3, y: 1), .init(x: 0, y: 0.7), .init(x: 0, y: 0.3), .init(x: 0.3, y: 0.3)]
        ]
        for segment in points { path.move(to: .init(x: rect.minX + segment[0].x * rect.width, y: rect.minY + segment[0].y * rect.height)); for point in segment.dropFirst() { path.addLine(to: .init(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height)) }; path.closeSubpath() }
        return path
    }
}

private struct BankBarclaysSymbol: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height) }
        p.move(to: point(0.49, 0.07))
        p.addCurve(to: point(0.63, 0.22), control1: point(0.60, 0.01), control2: point(0.65, 0.07))
        p.addCurve(to: point(0.74, 0.32), control1: point(0.60, 0.31), control2: point(0.64, 0.34))
        p.addCurve(to: point(0.93, 0.27), control1: point(0.79, 0.12), control2: point(0.91, 0.16))
        p.addCurve(to: point(0.92, 0.62), control1: point(1.03, 0.38), control2: point(0.97, 0.52))
        p.addLine(to: point(0.82, 0.54))
        p.addCurve(to: point(0.72, 0.73), control1: point(0.87, 0.62), control2: point(0.83, 0.70))
        p.addLine(to: point(0.68, 0.65))
        p.addCurve(to: point(0.72, 0.85), control1: point(0.67, 0.76), control2: point(0.69, 0.79))
        p.addLine(to: point(0.50, 0.99))
        p.addLine(to: point(0.28, 0.85))
        p.addCurve(to: point(0.32, 0.65), control1: point(0.31, 0.79), control2: point(0.33, 0.76))
        p.addLine(to: point(0.28, 0.73))
        p.addCurve(to: point(0.18, 0.54), control1: point(0.17, 0.70), control2: point(0.13, 0.62))
        p.addLine(to: point(0.08, 0.62))
        p.addCurve(to: point(0.07, 0.27), control1: point(0.03, 0.52), control2: point(-0.03, 0.38))
        p.addCurve(to: point(0.26, 0.32), control1: point(0.09, 0.16), control2: point(0.21, 0.12))
        p.addCurve(to: point(0.39, 0.22), control1: point(0.34, 0.35), control2: point(0.47, 0.26))
        p.addCurve(to: point(0.38, 0.12), control1: point(0.42, 0.17), control2: point(0.39, 0.11))
        p.addLine(to: point(0.33, 0.13))
        p.addCurve(to: point(0.49, 0.07), control1: point(0.32, 0.06), control2: point(0.42, 0.04))
        p.closeSubpath()
        return p
    }
}

private struct BankAmericaSymbol: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        for row in 0..<3 { for column in 0..<2 {
            let x = CGFloat(column) * 0.47 + CGFloat(row) * 0.07
            let y = CGFloat(row) * 0.29
            p.move(to: .init(x: rect.minX + x * rect.width, y: rect.minY + (y + 0.18) * rect.height))
            p.addLine(to: .init(x: rect.minX + (x + 0.36) * rect.width, y: rect.minY + y * rect.height))
            p.addLine(to: .init(x: rect.minX + (x + 0.46) * rect.width, y: rect.minY + (y + 0.12) * rect.height))
            p.addLine(to: .init(x: rect.minX + (x + 0.1) * rect.width, y: rect.minY + (y + 0.3) * rect.height)); p.closeSubpath()
        } }
        return p
    }
}

private struct BankCitiArc: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path(); p.move(to: .init(x: rect.minX, y: rect.maxY)); p.addQuadCurve(to: .init(x: rect.maxX, y: rect.maxY), control: .init(x: rect.midX, y: rect.minY - rect.height)); return p
    }
}

private extension Color {
    init(bankHex: UInt32) { self.init(red: Double((bankHex >> 16) & 255) / 255, green: Double((bankHex >> 8) & 255) / 255, blue: Double(bankHex & 255) / 255) }
}

private extension BankTheme {
    var playbackSavingsSuffix: String {
        switch self {
        case .chase: return "2202"
        case .citi: return "6713"
        case .capitalOne: return "7104"
        case .hsbc: return "3000"
        case .barclays: return "5604"
        case .lloyds: return "2088"
        case .natWest: return "4000"
        default: return "6543"
        }
    }
}

private extension View {
    func bankSurface(radius: CGFloat) -> some View { background(Color.white, in: RoundedRectangle(cornerRadius: radius)).overlay(RoundedRectangle(cornerRadius: radius).stroke(Color.black.opacity(0.035), lineWidth: 1)) }
}
