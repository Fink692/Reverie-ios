import SwiftUI
import Charts

/// A local prediction-market scene. Quotes, positions, and trades use the saved session.
struct PredictionPlayback: View {
    let sceneID: UUID
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("cleanPlayback") private var cleanPlayback = false
    @State private var tab: PredictionTab = .home
    @State private var category = "All"
    @State private var league = "Home"
    @State private var query = ""
    @State private var sheet: PredictionSheet?
    @State private var showProfileMenu = false
    @State private var community = PredictionCommunitySession()
    @FocusState private var searching: Bool

    private var scene: StudioScene? { store.scenes.first { $0.id == sceneID } }
    private var profile: PredictionProfile { store.predictionProfile(for: sceneID) }
    private var games: [PredictionGame] { profile.games ?? [] }
    private var leagues: [String] {
        let standard = ["Home", "MLB", "Pro", "CFB", "NHL", "Tennis"]
        return standard + Set(games.map(\.league)).subtracting(standard).sorted()
    }
    private var visibleGames: [PredictionGame] { games.filter { league == "Home" || $0.league == league } }
    private var categories: [String] { ["All"] + Set(profile.markets.map(\.category)).sorted() }
    private var markets: [PredictionMarket] {
        profile.markets.filter {
            (category == "All" || $0.category == category)
                && (query.isEmpty || "\($0.question) \($0.category)".localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let scene {
                    VStack(spacing: 0) {
                        if tab == .squads { squadsHeader } else { header(scene) }
                        switch tab {
                        case .home: sportsHome(scene, liveOnly: false)
                        case .live: sportsHome(scene, liveOnly: true)
                        case .squads: squads(scene)
                        case .search: discovery(scene)
                        case .portfolio: portfolio(scene)
                        case .activity: history(scene)
                        case .profile: profilePage(scene)
                        }
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) { bottomTabs }
                } else {
                    ContentUnavailableView("Market scene unavailable", systemImage: "chart.line.uptrend.xyaxis")
                        .overlay(alignment: .topTrailing) { Button("Close") { dismiss() }.padding() }
                }
            }
            .background(PredictionColors.background)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { searching = false }.accessibilityIdentifier("prediction-search-done")
                }
            }
            .confirmationDialog("Account", isPresented: $showProfileMenu, titleVisibility: .visible) {
                Button("Account settings") { sheet = .profile }
                Button("Manage markets") { sheet = .markets }
                Button("Trade history") { tab = .activity }
                Button("Close scene") { dismiss() }
                Button("Cancel", role: .cancel) { }
            }
            .preferredColorScheme(.light)
            .tint(PredictionColors.blue)
            .sheet(item: $sheet) { destination in
                switch destination {
                case .market(let id): PredictionMarketDetail(sceneID: sceneID, marketID: id)
                case .trade(let id, let outcome, let side): PredictionTradeTicket(sceneID: sceneID, marketID: id, initialOutcome: outcome, side: side)
                case .markets: PredictionMarketManager(sceneID: sceneID)
                case .profile: PredictionProfileEditor(sceneID: sceneID)
                case .liveMatch(let id): PredictionLiveMatch(sceneID: sceneID, marketID: id, community: $community)
                case .squad(let id): PredictionSquadChat(sceneID: sceneID, squadID: id, community: $community)
                case .invite: PredictionSquadInvite(sceneID: sceneID)
                case .combo: PredictionComboTicket(sceneID: sceneID)
                case .comboPosition(let id): PredictionComboPositionDetail(sceneID: sceneID, positionID: id)
                }
            }
            .alert("Unable to update market", isPresented: Binding(get: { store.error != nil && sheet?.id == nil }, set: { if !$0 { store.error = nil } })) {
                Button("OK") { store.error = nil }
            } message: { Text(store.error ?? "") }
            .onChange(of: categories) { _, values in if !values.contains(category) { category = "All" } }
            .onChange(of: scene?.kind) { _, kind in if kind != .prediction { dismiss() } }
        }
        .accessibilityIdentifier("prediction-playback")
    }

    private func header(_ scene: StudioScene) -> some View {
        HStack(spacing: 8) {
            Button { searching = false; showProfileMenu = true } label: {
                HStack(spacing: 6) {
                    PredictionWordmark().stroke(.primary, lineWidth: 1.8).frame(width: 20, height: 20).accessibilityHidden(true)
                    Text("Polymarket").font(.headline).lineLimit(1).minimumScaleFactor(0.85)
                }.foregroundStyle(.primary).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
            }
            .accessibilityLabel("Market profile and close scene")
            .accessibilityIdentifier("prediction-profile-menu")
            Spacer(minLength: 8)
            Button { sheet = .profile } label: {
                Text("Deposit").font(.caption.weight(.semibold))
                    .padding(.horizontal, 15).frame(minHeight: 44)
                    .foregroundStyle(.white).background(PredictionColors.blue, in: RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityLabel("Cash settings, balance \(scene.money(scene.balance))")
            .accessibilityIdentifier("prediction-cash")
            Button { tab = .activity } label: {
                Image(systemName: "bell").font(.body.weight(.medium)).frame(width: 44, height: 44)
                    .foregroundStyle(.primary).background(.white, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(PredictionColors.fill))
            }
            .accessibilityLabel("Trade activity")
            if !cleanPlayback {
                Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                    .accessibilityLabel("Close prediction playback").accessibilityIdentifier("close-scene")
            }
        }
        .buttonStyle(.plain).padding(.horizontal, 16).padding(.vertical, 4).background(.white)
    }

    private func sportsHome(_ scene: StudioScene, liveOnly: Bool) -> some View {
        let selected = visibleGames.filter { !liveOnly || $0.isLive }
        let trending = selected.sorted { first, second in
            if first.league == "Pro" { return false }
            if second.league == "Pro" { return true }
            return first.league < second.league
        }
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                leagueNavigation
                if !liveOnly { seasonBanner }
                if !liveOnly && !trending.isEmpty {
                    Text("Trending").font(.headline).accessibilityAddTraits(.isHeader)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(trending) { game in
                                Button { sheet = .liveMatch(game.marketID) } label: { PredictionScoreCard(game: game) }
                                    .buttonStyle(.plain).accessibilityIdentifier("prediction-trending-\(game.id.uuidString)")
                            }
                        }
                    }
                }
                HStack {
                    Text(liveOnly ? "Live markets" : "Live").font(.headline).accessibilityAddTraits(.isHeader)
                    Spacer()
                    if !liveOnly { Button("See all") { tab = .live }.font(.subheadline.weight(.medium)) }
                }
                if selected.isEmpty {
                    ContentUnavailableView("No games in this league", systemImage: "sportscourt", description: Text("Choose another league or add match details from Manage markets."))
                }
                ForEach(selected) { game in
                    if let market = profile.market(for: game.marketID) {
                        PredictionGameCard(game: game, market: market, onOpen: { sheet = .liveMatch(market.id) }) { outcome in
                            sheet = .trade(market.id, outcome, .buy)
                        }
                    }
                }
                Button {
                    query = ""
                    category = "All"
                    tab = .search
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Markets on everything").font(.headline)
                            Text("Explore crypto, economy, culture, and more").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.right").accessibilityHidden(true)
                    }
                    .padding(16).frame(minHeight: 70).predictionSurface()
                }
                .buttonStyle(.plain).foregroundStyle(.primary)
                .accessibilityIdentifier("prediction-explore-all-markets")
            }
            .frame(maxWidth: 720, alignment: .leading).padding(16).padding(.bottom, 52).frame(maxWidth: .infinity)
        }
        .background(.white)
        .overlay(alignment: .bottom) {
            Button { sheet = .combo } label: {
                Label("Build a Combo", systemImage: "square.stack.3d.up.fill").font(.caption.weight(.semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 18).frame(minHeight: 40).background(PredictionComboStyle.gradient, in: Capsule())
                    .shadow(color: .black.opacity(0.10), radius: 5, y: 2)
            }.buttonStyle(.plain).padding(.bottom, 10).accessibilityIdentifier("prediction-build-combo")
        }
        .accessibilityIdentifier(liveOnly ? "prediction-live" : "prediction-home")
    }

    private var leagueNavigation: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(leagues, id: \.self) { value in
                    Button { league = value } label: {
                        VStack(spacing: 7) {
                            PredictionLeagueArtwork(league: value)
                                .frame(width: 42, height: 42)
                                .background(league == value ? PredictionColors.fill : .clear, in: RoundedRectangle(cornerRadius: 12))
                            Text(value).font(.caption.weight(league == value ? .semibold : .regular))
                                .foregroundStyle(league == value ? .primary : .secondary)
                        }
                        .frame(minWidth: 54, minHeight: 72)
                    }
                    .buttonStyle(.plain).accessibilityLabel(value == "Home" ? "All leagues" : "\(value) league")
                    .accessibilityAddTraits(league == value ? [.isSelected] : [])
                    .accessibilityIdentifier("prediction-league-\(value.lowercased())")
                }
            }
        }
    }

    private var seasonBanner: some View {
        Button { league = "Pro"; tab = .live } label: {
            ZStack(alignment: .leading) {
                LinearGradient(colors: [Color(red: 0.10, green: 0.13, blue: 0.23), Color(red: 0.21, green: 0.30, blue: 0.48)], startPoint: .topLeading, endPoint: .bottomTrailing)
                GeometryReader { geometry in
                    Path { path in
                        path.move(to: CGPoint(x: geometry.size.width * 0.46, y: 0))
                        path.addLine(to: CGPoint(x: geometry.size.width * 0.75, y: 0))
                        path.addLine(to: CGPoint(x: geometry.size.width * 0.56, y: geometry.size.height))
                        path.addLine(to: CGPoint(x: geometry.size.width * 0.28, y: geometry.size.height))
                        path.closeSubpath()
                    }.fill(.white.opacity(0.035))
                    Ellipse().fill(.white.opacity(0.065)).frame(width: geometry.size.width * 0.64, height: 260)
                        .rotationEffect(.degrees(24)).offset(x: geometry.size.width * 0.56, y: -40)
                    Image("PredictionFidelity-SeasonHelmet").resizable().scaledToFit()
                        .frame(width: 165, height: 150).rotationEffect(.degrees(-8))
                        .position(x: geometry.size.width - 69, y: 88)
                        .shadow(color: .black.opacity(0.25), radius: 8, y: 5)
                }
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 5) {
                        Text("PRO")
                        Image("PredictionFidelity-SeasonFootball").resizable().scaledToFit().frame(width: 31, height: 24).accessibilityHidden(true)
                        Text("FOOTBALL")
                    }.font(.system(size: 20, weight: .heavy)).foregroundStyle(.white)
                    Text("Regular Season").font(.subheadline).foregroundStyle(.white.opacity(0.8))
                    Spacer(minLength: 12)
                    Text("Week 3 of 18").font(.subheadline).foregroundStyle(.white.opacity(0.8))
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.2)).frame(width: 125, height: 4)
                        Capsule().fill(.white).frame(width: 24, height: 4)
                        Circle().fill(.white).frame(width: 13, height: 13).offset(x: 18)
                    }.frame(height: 13).accessibilityHidden(true)
                }
                .padding(18).frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 146).clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain).accessibilityLabel("Pro Football regular season, view markets")
        .accessibilityIdentifier("prediction-season-banner")
    }

    private var squadsHeader: some View {
        HStack {
            Button { showProfileMenu = true } label: { PredictionCommunityAvatar(name: "You", asset: nil, color: .green).frame(width: 32, height: 32).frame(width: 44, height: 44) }
                .accessibilityLabel("Market profile and close scene").accessibilityIdentifier("prediction-profile-menu")
            Spacer()
            Text("Squads").font(.headline)
            Spacer()
            Button { if let first = PredictionSquad.samples.first { sheet = .squad(first.id) } } label: { Image(systemName: "tray.fill").font(.title3).frame(width: 44, height: 44) }
                .accessibilityLabel("Squad inbox").accessibilityIdentifier("prediction-squads-inbox")
        }.foregroundStyle(.primary).buttonStyle(.plain).padding(.horizontal, 16).padding(.vertical, 5).background(.white)
    }

    private func squads(_ scene: StudioScene) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 13) {
                    Text("SQUADS").font(.system(size: 43, weight: .black, design: .rounded)).italic()
                        .foregroundStyle(LinearGradient(colors: [.gray, .black, .gray, .black], startPoint: .top, endPoint: .bottom))
                        .shadow(color: .black.opacity(0.15), radius: 0, y: 2).accessibilityAddTraits(.isHeader)
                    Text("Trade and chat with your friends or join\nour public communities")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button { sheet = .invite } label: {
                        HStack(spacing: 9) {
                            HStack(spacing: -7) {
                                PredictionCommunityAvatar(name: "Friends", asset: "PredictionFidelity-TeamRams", color: PredictionColors.blue).frame(width: 22, height: 22)
                                PredictionCommunityAvatar(name: "Team", asset: "PredictionFidelity-TeamDodgers", color: .green).frame(width: 22, height: 22)
                                Image(systemName: "plus").font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(width: 25, height: 25).background(PredictionColors.fill, in: Circle())
                            }
                            Text("Invite your friends").font(.subheadline).foregroundStyle(.secondary)
                        }.padding(.horizontal, 14).padding(.vertical, 10).background(.white, in: Capsule()).overlay(Capsule().stroke(.gray.opacity(0.17)))
                    }.buttonStyle(.plain).accessibilityIdentifier("prediction-squad-invite")
                }.frame(maxWidth: .infinity).padding(.top, 28).padding(.bottom, 5)
                VStack(spacing: 12) {
                    ForEach(PredictionSquad.samples) { squad in
                        VStack(spacing: 0) {
                            HStack(spacing: 13) {
                                PredictionCommunityAvatar(name: squad.name, asset: squad.asset, color: squad.color).frame(width: 49, height: 49)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(squad.name).font(.headline).foregroundStyle(.primary)
                                    Text("\((squad.members + (community.joined.contains(squad.id) ? 1 : 0)).formatted()) members").font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 5)
                                Button(community.joined.contains(squad.id) ? "Open" : "Join") {
                                    community.joined.insert(squad.id)
                                    sheet = .squad(squad.id)
                                }.font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                    .padding(.horizontal, 18).frame(minHeight: 44).background(.white, in: RoundedRectangle(cornerRadius: 15))
                                    .overlay(RoundedRectangle(cornerRadius: 15).stroke(.gray.opacity(0.2)))
                                    .accessibilityIdentifier("prediction-squad-\(squad.league.lowercased())")
                            }.padding(14)
                            HStack(spacing: 0) {
                                squadTeamPanel(squad.firstTeam, asset: squad.firstAsset, color: squad.color)
                                squadTeamPanel(squad.secondTeam, asset: squad.secondAsset, color: squad.secondColor)
                            }.frame(height: 76).clipped()
                        }.background(PredictionColors.fill, in: RoundedRectangle(cornerRadius: 22)).clipShape(RoundedRectangle(cornerRadius: 22))
                    }
                }
            }.frame(maxWidth: 720).padding(16).frame(maxWidth: .infinity)
        }.background(.white)
    }

    private func squadTeamPanel(_ name: String, asset: String, color: Color) -> some View {
        HStack(spacing: 7) {
            Image(asset).resizable().scaledToFit().frame(width: 52, height: 65).accessibilityHidden(true)
            Text(name.uppercased()).font(.system(size: 17, weight: .black, design: .rounded)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(color)
    }

    private func discovery(_ scene: StudioScene) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                searchField
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(categories, id: \.self) { value in
                            Button { category = value } label: {
                                VStack(spacing: 7) {
                                    Image(systemName: predictionCategorySymbol(value)).font(.title3)
                                        .frame(width: 46, height: 46)
                                        .background(category == value ? PredictionColors.blue.opacity(0.1) : PredictionColors.fill, in: Circle())
                                    Text(value).font(.caption.weight(category == value ? .semibold : .regular))
                                }
                                .foregroundStyle(category == value ? PredictionColors.blue : .secondary)
                                .frame(minWidth: 64, minHeight: 68)
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(category == value ? [.isSelected] : [])
                        }
                    }
                }
                HStack {
                    Text(tab == .search ? "Search markets" : category == "All" ? "Trending markets" : category)
                        .font(.title2.bold()).accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text(markets.count.formatted()).font(.subheadline).foregroundStyle(.secondary)
                }
                if markets.isEmpty {
                    ContentUnavailableView("No matching markets", systemImage: "magnifyingglass", description: Text("Try another question or category, or add a market from your profile."))
                }
                ForEach(markets) { market in
                    PredictionMarketCard(market: market, scene: scene, onOpen: { sheet = .market(market.id) }) { outcome in
                        searching = false
                        sheet = .trade(market.id, outcome, .buy)
                    }
                }
            }
            .frame(maxWidth: 720, alignment: .leading).padding(16).frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary).accessibilityHidden(true)
            TextField("Search markets", text: $query)
                .focused($searching).submitLabel(.search).onSubmit { searching = false }
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .accessibilityIdentifier("prediction-search")
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary).frame(width: 44, height: 44) }
                    .accessibilityLabel("Clear market search")
            }
        }
        .padding(.horizontal, 12).frame(minHeight: 48)
        .background(PredictionColors.fill, in: RoundedRectangle(cornerRadius: 12))
    }

    private func portfolio(_ scene: StudioScene) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Portfolio").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                        Spacer()
                        Button { tab = .activity } label: { Image(systemName: "clock").frame(width: 44, height: 44) }
                            .accessibilityLabel("Trade history").accessibilityIdentifier("prediction-tab-activity")
                    }
                    Text(scene.money(profile.total(cash: scene.balance)))
                        .font(.system(.largeTitle, design: .rounded).bold()).monospacedDigit().minimumScaleFactor(0.65).lineLimit(1)
                        .accessibilityIdentifier("prediction-portfolio-value")
                    HStack {
                        VStack(alignment: .leading, spacing: 5) { Text("Positions").font(.caption).foregroundStyle(.secondary); Text(scene.money(profile.positionsValue)).font(.headline) }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 5) { Text("Cash").font(.caption).foregroundStyle(.secondary); Text(scene.money(scene.balance)).font(.headline) }
                    }
                }
                .padding(20).predictionSurface()
                Text("Your positions").font(.headline).accessibilityAddTraits(.isHeader)
                if profile.positions.filter({ $0.shares > 0 }).isEmpty && (profile.comboPositions ?? []).isEmpty {
                    ContentUnavailableView("No positions yet", systemImage: "chart.pie", description: Text("Buy Yes or No shares in a market to start your portfolio."))
                }
                ForEach(profile.positions.filter { $0.shares > 0 }) { position in
                    if let market = profile.market(for: position.marketID) {
                        VStack(alignment: .leading, spacing: 12) {
                            Button { sheet = .market(market.id) } label: {
                                Text(market.question).font(.headline).foregroundStyle(.primary).frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain).frame(minHeight: 44)
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("\(position.outcome.title) · \(predictionQuantity(position.shares)) shares")
                                        .font(.subheadline.weight(.semibold)).foregroundStyle(predictionOutcomeColor(position.outcome))
                                    Text("Average \(predictionPrice(position.averagePrice))").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 5) {
                                    Text(scene.money(profile.value(of: position))).font(.headline).monospacedDigit()
                                    Text(predictionSignedMoney(profile.value(of: position) - position.costBasis, scene: scene))
                                        .font(.caption).foregroundStyle(profile.value(of: position) >= position.costBasis ? PredictionColors.green : PredictionColors.red)
                                }
                            }
                            Button("Sell \(position.outcome.title)") { sheet = .trade(market.id, position.outcome, .sell) }
                                .buttonStyle(.bordered).controlSize(.large).disabled(!market.isOpen)
                                .accessibilityIdentifier("prediction-sell-\(position.id.uuidString)")
                        }
                        .padding(16).predictionSurface()
                    }
                }
                ForEach(profile.comboPositions ?? []) { combo in
                    Button { sheet = .comboPosition(combo.id) } label: {
                        VStack(alignment: .leading, spacing: 11) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.stack.3d.up.fill").foregroundStyle(PredictionComboStyle.gradient)
                                Text("Combo · \(combo.legs.count) Markets").font(.headline)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }
                            Text(combo.questions.joined(separator: " · ")).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                            HStack {
                                VStack(alignment: .leading, spacing: 4) { Text("Current value").font(.caption).foregroundStyle(.secondary); Text(scene.money(profile.value(of: combo))).font(.headline).monospacedDigit() }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) { Text("Potential payout").font(.caption).foregroundStyle(.secondary); Text(scene.money(combo.potentialPayout)).font(.headline).foregroundStyle(PredictionComboStyle.gradient).monospacedDigit() }
                            }
                        }.foregroundStyle(.primary).padding(16).predictionSurface()
                    }.buttonStyle(.plain).accessibilityIdentifier("prediction-combo-position-\(combo.id.uuidString)")
                }
            }
            .frame(maxWidth: 720, alignment: .leading).padding(16).frame(maxWidth: .infinity)
        }
    }

    private func history(_ scene: StudioScene) -> some View {
        List {
            if profile.transactions.isEmpty && (profile.comboTransactions ?? []).isEmpty {
                ContentUnavailableView("No trades yet", systemImage: "clock", description: Text("Confirmed purchases and sales appear here."))
            }
            ForEach((profile.comboTransactions ?? []).sorted { $0.date > $1.date }) { trade in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Bought \(trade.legs.count)-market combo", systemImage: "square.stack.3d.up.fill").font(.headline)
                        Spacer()
                        Text("−" + scene.money(trade.totalCost)).font(.subheadline.weight(.semibold)).monospacedDigit()
                    }
                    Text(trade.questions.joined(separator: " · ")).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                    Text(trade.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                }.padding(.vertical, 7).accessibilityElement(children: .combine).accessibilityIdentifier("prediction-combo-trade-\(trade.id.uuidString)")
            }
            ForEach(profile.transactions.sorted { $0.date > $1.date }) { trade in
                VStack(alignment: .leading, spacing: 8) {
                    Text(trade.question).font(.headline)
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(trade.side == .buy ? "Bought" : "Sold") \(predictionQuantity(trade.shares)) \(trade.outcome.title) shares")
                                .font(.subheadline).foregroundStyle(predictionOutcomeColor(trade.outcome))
                            Text(trade.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text((trade.side == .buy ? "−" : "+") + scene.money(trade.total)).font(.subheadline.weight(.semibold)).monospacedDigit()
                    }
                }
                .padding(.vertical, 7).accessibilityElement(children: .combine)
                .accessibilityIdentifier("prediction-trade-\(trade.id.uuidString)")
            }
        }
        .listStyle(.insetGrouped).accessibilityIdentifier("prediction-history")
    }

    private func profilePage(_ scene: StudioScene) -> some View {
        List {
            Section {
                Label(scene.name, systemImage: "person.crop.circle").font(.headline)
                LabeledContent("Cash", value: scene.money(scene.balance))
                LabeledContent("Position value", value: scene.money(profile.positionsValue))
            }
            Section {
                Button { sheet = .profile } label: { Label("Account settings", systemImage: "slider.horizontal.3") }
                Button { sheet = .markets } label: { Label("Manage markets", systemImage: "chart.xyaxis.line") }
            }
            Section {
                Button { dismiss() } label: { Label("Close scene", systemImage: "xmark.circle") }
                    .accessibilityIdentifier("close-prediction-playback")
            }
        }
        .listStyle(.insetGrouped)
    }

    private var bottomTabs: some View {
        HStack(spacing: 0) {
            ForEach(PredictionTab.navigation) { value in
                Button {
                    searching = false
                    tab = value
                    if value == .search { category = "All"; query = "" }
                } label: {
                    VStack(spacing: 5) {
                        if value == .portfolio, let scene {
                            Text(profile.total(cash: scene.balance).formatted(.currency(code: scene.currency).precision(.fractionLength(0))))
                                .font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.6).frame(height: 23)
                        } else if value == .home {
                            PredictionHomeMark(selected: tab == .home).frame(width: 26, height: 23)
                        } else { Image(systemName: value.symbol).font(.title3).frame(height: 23) }
                        Text(value.title).font(.caption2.weight(tab == value ? .semibold : .regular))
                    }
                    .foregroundStyle(tab == value ? PredictionColors.blue : .secondary)
                    .frame(maxWidth: .infinity).frame(minHeight: 54).contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityLabel(value.title)
                .accessibilityAddTraits(tab == value ? [.isSelected] : [])
                .accessibilityIdentifier("prediction-tab-\(value.rawValue)")
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 5).background(.white)
        .overlay(alignment: .top) { Divider() }
    }
}

private struct PredictionScoreCard: View {
    let game: PredictionGame
    @ScaledMetric(relativeTo: .caption) private var statusHeight: CGFloat = 16
    private var dividerOffset: CGFloat { 12 + statusHeight + 8 }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if game.isLive { Circle().fill(PredictionColors.red).frame(width: 5, height: 5).accessibilityHidden(true) }
                else { Image(systemName: "clock").font(.caption2).foregroundStyle(.secondary).accessibilityHidden(true) }
                Text(game.status)
                    .font(.caption.weight(.semibold)).foregroundStyle(game.isLive ? PredictionColors.red : .secondary)
                Spacer(minLength: 8)
                Text(game.league).font(.caption).foregroundStyle(.secondary)
            }
            .frame(height: statusHeight)
            PredictionDashedLine().stroke(Color.secondary.opacity(0.13), style: StrokeStyle(lineWidth: 1, dash: [4, 4])).frame(height: 1)
            scoreRow(game.homeTeam, score: game.homeScore, color: PredictionColors.blue)
            scoreRow(game.awayTeam, score: game.awayScore, color: Color(red: 0.76, green: 0.35, blue: 0.18))
        }
        .padding(.horizontal, 13).padding(.vertical, 12).frame(width: 190, alignment: .leading)
        .background(PredictionScoreTicket(divider: dividerOffset).fill(.white)
            .shadow(color: .black.opacity(0.035), radius: 6, y: 3))
        .overlay(PredictionScoreTicket(divider: dividerOffset).stroke(Color.secondary.opacity(0.11)))
        .accessibilityElement(children: .combine)
    }
    private func scoreRow(_ team: String, score: Int, color: Color) -> some View {
        HStack(spacing: 9) {
            PredictionTeamArtwork(team: team, league: game.league, color: color).frame(width: 23, height: 23)
            Text(team).font(.subheadline).foregroundStyle(.primary).lineLimit(1)
            Spacer(minLength: 4)
            Text(score.formatted()).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
        }
    }
}

private struct PredictionGameCard: View {
    let game: PredictionGame
    let market: PredictionMarket
    var onOpen: () -> Void
    var onBuy: (PredictionOutcome) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(game.homeTeam) vs \(game.awayTeam)").font(.headline).foregroundStyle(.primary)
                    HStack(spacing: 6) {
                        if game.isLive { Circle().fill(PredictionColors.red).frame(width: 5, height: 5).accessibilityHidden(true) }
                        Text(game.status).foregroundStyle(game.isLive ? PredictionColors.red : .secondary)
                        Text("· \(game.league == "Pro" ? "Pro Football" : game.league)").foregroundStyle(.secondary)
                    }.font(.caption.weight(.medium))
                }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain).accessibilityIdentifier("market-\(market.id.uuidString)")
            choice(.yes, team: game.homeTeam, color: PredictionColors.blue)
            choice(.no, team: game.awayTeam, color: Color(red: 0.88, green: 0.36, blue: 0.18))
            Button(action: onOpen) {
                HStack(spacing: 6) {
                    Image(systemName: "square.stack.3d.up").foregroundStyle(PredictionColors.blue)
                    Text("2 outcomes")
                    Spacer()
                    Text("View market")
                    Image(systemName: "chevron.right").font(.caption2)
                }.font(.caption).foregroundStyle(.secondary).frame(minHeight: 44)
            }.buttonStyle(.plain)
        }
        .padding(.vertical, 5)
        .overlay(alignment: .bottom) { Divider().offset(y: 9) }
    }
    private func choice(_ outcome: PredictionOutcome, team: String, color: Color) -> some View {
        let price = market.price(for: outcome)
        return Button { onBuy(outcome) } label: {
            HStack(spacing: 12) {
                PredictionTeamArtwork(team: team, league: game.league, color: color).frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 7) {
                    Text(team).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                    Capsule().fill(color).frame(width: max(22, price * 115), height: 3)
                }
                Spacer()
                Text(price > 0 ? (1 / price).formatted(.number.precision(.fractionLength(1))) + "x" : "Closed")
                    .font(.subheadline).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.plain).disabled(!market.isOpen)
        .accessibilityLabel("\(team), buy \(outcome.title), \(predictionPrice(price)) per share")
        .accessibilityIdentifier("prediction-game-\(game.id.uuidString)-\(outcome.rawValue)")
    }
}

private struct PredictionWordmark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.05, y: rect.height * 0.24))
        path.addLine(to: CGPoint(x: rect.width * 0.95, y: rect.height * 0.05))
        path.addLine(to: CGPoint(x: rect.width * 0.95, y: rect.height * 0.95))
        path.addLine(to: CGPoint(x: rect.width * 0.05, y: rect.height * 0.76))
        path.closeSubpath()
        path.move(to: CGPoint(x: rect.width * 0.05, y: rect.height * 0.24))
        path.addLine(to: CGPoint(x: rect.width * 0.95, y: rect.height * 0.5))
        path.addLine(to: CGPoint(x: rect.width * 0.05, y: rect.height * 0.76))
        return path
    }
}

/// Public artwork is bundled so playback never needs a network request.
private struct PredictionLeagueArtwork: View {
    let league: String
    private var asset: String? {
        switch league {
        case "MLB": return "PredictionFidelity-LeagueMLB"
        case "Pro": return "PredictionFidelity-LeaguePro"
        case "CFB": return "PredictionFidelity-LeagueCFB"
        case "NHL": return "PredictionFidelity-LeagueNHL"
        default: return nil
        }
    }
    var body: some View {
        Group {
            if let asset { Image(asset).resizable().scaledToFit().padding(3) }
            else { Text(predictionLeagueGlyph(league)).font(.system(size: 28)) }
        }.accessibilityHidden(true)
    }
}

private struct PredictionTeamArtwork: View {
    let team: String
    let league: String
    let color: Color
    private var asset: String? {
        switch (league, team.lowercased()) {
        case ("Pro", "los angeles"), ("Pro", "los angeles rams"), ("Pro", "rams"): return "PredictionFidelity-TeamRams"
        case ("Pro", "denver"), ("Pro", "denver broncos"), ("Pro", "broncos"): return "PredictionFidelity-TeamBroncos"
        case ("MLB", "dodgers"), ("MLB", "los angeles dodgers"): return "PredictionFidelity-TeamDodgers"
        case ("MLB", "rangers"), ("MLB", "texas rangers"): return "PredictionFidelity-TeamTexasRangers"
        case ("NHL", "rangers"), ("NHL", "new york rangers"): return "PredictionFidelity-TeamNewYorkRangers"
        case ("NHL", "bruins"), ("NHL", "boston bruins"): return "PredictionFidelity-TeamBruins"
        default: return nil
        }
    }
    var body: some View {
        Group {
            if let asset { Image(asset).resizable().scaledToFit() }
            else {
                Text(predictionTeamInitials(team)).font(.caption.weight(.heavy)).foregroundStyle(color)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: 9))
            }
        }.accessibilityHidden(true)
    }
}

private struct PredictionHomeMark: View {
    let selected: Bool
    var body: some View {
        Circle().fill(selected ? PredictionColors.blue : Color.secondary.opacity(0.75))
            .overlay {
                PredictionHomeTile().fill(.white).frame(width: 12, height: 12)
            }.accessibilityHidden(true)
    }
}

/// The Home glyph is a skewed tile rather than a rotated square.
private struct PredictionHomeTile: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.width * x, y: rect.height * y) }
        return Path { path in
            path.move(to: point(0.31, 0.16))
            path.addLine(to: point(0.78, 0.06))
            path.addQuadCurve(to: point(0.94, 0.21), control: point(0.97, 0.01))
            path.addLine(to: point(0.79, 0.80))
            path.addQuadCurve(to: point(0.65, 0.94), control: point(0.76, 0.91))
            path.addLine(to: point(0.20, 0.99))
            path.addQuadCurve(to: point(0.06, 0.83), control: point(0.01, 1))
            path.addLine(to: point(0.18, 0.31))
            path.addQuadCurve(to: point(0.31, 0.16), control: point(0.21, 0.20))
            path.closeSubpath()
        }
    }
}

private struct PredictionDashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in path.move(to: CGPoint(x: 0, y: rect.midY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)) }
    }
}

private struct PredictionScoreTicket: Shape {
    let divider: CGFloat
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 16
        let notch: CGFloat = 6
        let divider = min(rect.height - radius - notch, max(radius + notch, self.divider))
        return Path { path in
            path.move(to: CGPoint(x: radius, y: 0))
            path.addLine(to: CGPoint(x: rect.width - radius, y: 0))
            path.addQuadCurve(to: CGPoint(x: rect.width, y: radius), control: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: divider - notch))
            path.addQuadCurve(to: CGPoint(x: rect.width, y: divider + notch), control: CGPoint(x: rect.width - notch * 2, y: divider))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height - radius))
            path.addQuadCurve(to: CGPoint(x: rect.width - radius, y: rect.height), control: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: radius, y: rect.height))
            path.addQuadCurve(to: CGPoint(x: 0, y: rect.height - radius), control: CGPoint(x: 0, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: divider + notch))
            path.addQuadCurve(to: CGPoint(x: 0, y: divider - notch), control: CGPoint(x: notch * 2, y: divider))
            path.addLine(to: CGPoint(x: 0, y: radius))
            path.addQuadCurve(to: CGPoint(x: radius, y: 0), control: .zero)
            path.closeSubpath()
        }
    }
}

private func predictionLeagueGlyph(_ league: String) -> String {
    switch league {
    case "Home": return "🧭"
    case "MLB": return "⚾"
    case "Pro", "CFB": return "🏈"
    case "NHL": return "🏒"
    case "Tennis": return "🎾"
    default: return "🏆"
    }
}
private func predictionTeamInitials(_ name: String) -> String {
    name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined()
}

private struct PredictionMarketCard: View {
    let market: PredictionMarket
    let scene: StudioScene
    var onOpen: () -> Void
    var onBuy: (PredictionOutcome) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onOpen) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: predictionCategorySymbol(market.category))
                        .font(.title2).foregroundStyle(PredictionColors.blue)
                        .frame(width: 48, height: 48).background(PredictionColors.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(market.category).font(.caption).foregroundStyle(.secondary)
                        Text(market.question).font(.headline).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    VStack(spacing: 3) {
                        Text((market.yesPrice * 100).formatted(.number.precision(.fractionLength(0))) + "%").font(.title2.bold()).foregroundStyle(.primary)
                        Text("chance").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain).accessibilityIdentifier("market-\(market.id.uuidString)")
            HStack(spacing: 10) {
                outcomeButton(.yes)
                outcomeButton(.no)
            }
            HStack {
                Text("\(scene.money(market.volume)) Vol.")
                Spacer()
                Text(market.isOpen ? "Ends \(market.closeDate.formatted(.dateTime.month(.abbreviated).day()))" : "Closed")
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16).predictionSurface()
    }
    private func outcomeButton(_ outcome: PredictionOutcome) -> some View {
        Button { onBuy(outcome) } label: {
            HStack { Text(outcome.title); Spacer(minLength: 4); Text(predictionPrice(market.price(for: outcome))) }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(predictionOutcomeColor(outcome))
                .padding(.horizontal, 14).frame(maxWidth: .infinity).frame(minHeight: 44)
                .background(predictionOutcomeColor(outcome).opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain).disabled(!market.isOpen)
        .accessibilityLabel("Buy \(outcome.title), \(predictionPrice(market.price(for: outcome)))")
        .accessibilityIdentifier("prediction-\(outcome.rawValue)-\(market.id.uuidString)")
    }
}

/// Chat stays inside this playback session; no messages are sent to an external service.
private struct PredictionCommunitySession {
    var joined: Set<String> = []
    var messages: [String: [PredictionChatMessage]] = [:]
    var reacted: Set<UUID> = []
    mutating func post(_ text: String, room: String, author: String) {
        let text = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(240))
        guard !text.isEmpty else { return }
        messages[room, default: []].append(PredictionChatMessage(author: author, text: text, outcome: nil, reactions: 0))
    }
}

private struct PredictionChatMessage: Identifiable {
    var id = UUID()
    var author: String
    var text: String
    var outcome: PredictionOutcome?
    var reactions: Int
}

private struct PredictionSquad: Identifiable {
    let id: String
    let name: String
    let members: Int
    let league: String
    let asset: String
    let firstTeam: String
    let secondTeam: String
    let firstAsset: String
    let secondAsset: String
    let color: Color
    let secondColor: Color
    static let samples = [
        PredictionSquad(id: "logan", name: "Logan and friends", members: 121_234, league: "Pro", asset: "PredictionFidelity-SquadReference", firstTeam: "Buffalo", secondTeam: "Kansas", firstAsset: "PredictionFidelity-TeamBuffaloBills", secondAsset: "PredictionFidelity-TeamKansasCityChiefs", color: Color(red: 0.11, green: 0.13, blue: 0.44), secondColor: Color(red: 0.57, green: 0.06, blue: 0.14)),
        PredictionSquad(id: "mlb", name: "Baseball clubhouse", members: 38_526, league: "MLB", asset: "PredictionFidelity-LeagueMLB", firstTeam: "Dodgers", secondTeam: "Rangers", firstAsset: "PredictionFidelity-TeamDodgers", secondAsset: "PredictionFidelity-TeamTexasRangers", color: Color(red: 0.03, green: 0.27, blue: 0.61), secondColor: Color(red: 0.64, green: 0.08, blue: 0.15)),
        PredictionSquad(id: "nhl", name: "Hockey fans", members: 16_740, league: "NHL", asset: "PredictionFidelity-LeagueNHL", firstTeam: "Rangers", secondTeam: "Bruins", firstAsset: "PredictionFidelity-TeamNewYorkRangers", secondAsset: "PredictionFidelity-TeamBruins", color: Color(red: 0.03, green: 0.22, blue: 0.61), secondColor: Color(red: 0.34, green: 0.27, blue: 0.05))
    ]
}

private struct PredictionCommunityAvatar: View {
    let name: String
    let asset: String?
    let color: Color
    var body: some View {
        Circle().fill(color.opacity(0.13)).overlay {
            if asset == "PredictionFidelity-SquadReference" {
                GeometryReader { geometry in
                    Image("PredictionFidelity-SquadReference").resizable()
                        .frame(width: geometry.size.width * 946 / 112, height: geometry.size.width * 2048 / 112)
                        .offset(x: -geometry.size.width * 75 / 112, y: -geometry.size.width * 1826 / 112)
                }.clipShape(Circle())
            }
            else if let asset { Image(asset).resizable().scaledToFit().padding(4) }
            else { Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().foregroundStyle(color).padding(1) }
        }.overlay(Circle().stroke(.white, lineWidth: 2)).accessibilityHidden(true)
    }
}

private struct PredictionSquadInvite: View {
    let sceneID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var ready = false
    private var code: String { "SQUAD-" + sceneID.uuidString.prefix(6).uppercased() }
    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Image(systemName: "person.2.wave.2.fill").font(.system(size: 48)).foregroundStyle(PredictionColors.blue).accessibilityHidden(true)
                Text("Better with your squad").font(.title2.bold())
                Text("Bring your friends into your match chat.").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Text(code).font(.title3.monospaced().bold()).textSelection(.enabled).padding(18).frame(maxWidth: .infinity).background(PredictionColors.fill, in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityIdentifier("prediction-squad-invite-code")
                Button(ready ? "Invite ready" : "Create invite") { ready = true }
                    .buttonStyle(.borderedProminent).controlSize(.large).accessibilityIdentifier("prediction-squad-create-invite")
                if ready { Text("Your invite code is ready to use in this local scene.").font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center) }
                Spacer()
            }.padding(28).padding(.top, 35).navigationTitle("Invite friends").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .tint(PredictionColors.blue)
        }
    }
}

private struct PredictionSquadChat: View {
    let sceneID: UUID
    let squadID: String
    @Binding var community: PredictionCommunitySession
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var ticket: PredictionTicketRoute?
    private var squad: PredictionSquad { PredictionSquad.samples.first { $0.id == squadID } ?? PredictionSquad.samples[0] }
    private var room: String { "squad-" + squadID }
    private var profile: PredictionProfile { store.predictionProfile(for: sceneID) }
    private var game: PredictionGame? { profile.games?.first { $0.league == squad.league } }
    private var market: PredictionMarket? { game.flatMap { profile.market(for: $0.marketID) } }
    private var ownName: String { store.scenes.first { $0.id == sceneID }?.name ?? "You" }
    private var starterMessages: [PredictionChatMessage] {
        [PredictionChatMessage(id: UUID(uuidString: "CA710000-0000-4000-8000-000000000001")!, author: "gbls.bndk", text: "What a finish! Who are you backing?", outcome: .yes, reactions: 12),
         PredictionChatMessage(id: UUID(uuidString: "CA710000-0000-4000-8000-000000000002")!, author: "dthomas", text: "There's still plenty of time left.", outcome: .no, reactions: 4)]
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let game { PredictionMatchHeader(game: game).padding(.horizontal, 20).background(PredictionColors.fill.opacity(0.5)) }
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: 10) {
                            Image(systemName: "sportscourt").font(.title3).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(game?.status ?? "Squad chat").font(.headline)
                                Text(game.map { "\($0.homeTeam) \($0.homeScore):\($0.awayScore) \($0.awayTeam)" } ?? "Follow the match with your squad.").font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }.padding(14).frame(maxWidth: .infinity).background(PredictionColors.fill, in: RoundedRectangle(cornerRadius: 16))
                        ForEach(starterMessages + (community.messages[room] ?? [])) { item in
                            PredictionChatRow(message: item, game: game, isReacted: community.reacted.contains(item.id)) {
                                if community.reacted.contains(item.id) { community.reacted.remove(item.id) } else { community.reacted.insert(item.id) }
                            }
                        }
                    }.padding(16).frame(maxWidth: 720).frame(maxWidth: .infinity)
                }.scrollDismissesKeyboard(.interactively)
                PredictionChatComposer(text: $message, onSend: send).padding(.horizontal, 12).padding(.vertical, 8)
                if let game, let market {
                    PredictionMatchTradeButtons(game: game, market: market) { outcome in
                        ticket = PredictionTicketRoute(outcome: outcome, side: .buy)
                    }.padding(.horizontal, 16).padding(.bottom, 12)
                }
            }.background(.white).navigationTitle(squad.name).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(community.joined.contains(squadID) ? "Joined" : "Join") { community.joined.insert(squadID) }
                            .disabled(community.joined.contains(squadID)).accessibilityIdentifier("prediction-squad-chat-join")
                    }
                }
                .sheet(item: $ticket) { route in
                    if let market { PredictionTradeTicket(sceneID: sceneID, marketID: market.id, initialOutcome: route.outcome, side: route.side) }
                }.tint(PredictionColors.blue)
        }
    }
    private func send() { community.post(message, room: room, author: ownName); message = "" }
}

private struct PredictionChatRow: View {
    let message: PredictionChatMessage
    let game: PredictionGame?
    let isReacted: Bool
    var onReact: () -> Void
    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            PredictionCommunityAvatar(name: message.author, asset: message.outcome == .yes ? "PredictionFidelity-TeamRams" : message.outcome == .no ? "PredictionFidelity-TeamBroncos" : nil, color: message.outcome == .no ? PredictionColors.red : PredictionColors.blue).frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text(message.author).font(.subheadline.weight(.semibold)).lineLimit(1)
                    if let outcome = message.outcome, let game {
                        Text(outcome == .yes ? game.homeTeam : game.awayTeam).font(.caption.weight(.semibold))
                            .foregroundStyle(outcome == .yes ? PredictionColors.blue : PredictionColors.red)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background((outcome == .yes ? PredictionColors.blue : PredictionColors.red).opacity(0.09), in: RoundedRectangle(cornerRadius: 6))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                Text(message.text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                Button(action: onReact) {
                    HStack(spacing: 5) { Image(systemName: isReacted ? "hands.clap.fill" : "hands.clap"); Text((message.reactions + (isReacted ? 1 : 0)).formatted()) }
                        .font(.caption.weight(.medium)).padding(.horizontal, 10).frame(minHeight: 32)
                        .foregroundStyle(isReacted ? PredictionColors.blue : .secondary)
                        .background(PredictionColors.fill, in: Capsule())
                }.buttonStyle(.plain).accessibilityLabel("React to \(message.author)'s message")
                    .accessibilityAddTraits(isReacted ? [.isSelected] : []).accessibilityIdentifier("prediction-chat-react-\(message.id.uuidString)")
            }
        }
    }
}

private struct PredictionChatComposer: View {
    @Binding var text: String
    var onSend: () -> Void
    @FocusState private var editing: Bool
    var body: some View {
        HStack(spacing: 8) {
            Button { text += "🙌" } label: { Image(systemName: "plus").font(.title3).foregroundStyle(.secondary).frame(width: 36, height: 36).background(.gray.opacity(0.12), in: Circle()) }
                .accessibilityLabel("Add cheering reaction").accessibilityIdentifier("prediction-chat-add")
            TextField("Say something", text: $text, axis: .vertical).font(.subheadline).lineLimit(1...3).focused($editing).submitLabel(.send).onSubmit(send)
                .accessibilityIdentifier("prediction-chat-input")
                .onChange(of: text) { _, value in if value.count > 240 { text = String(value.prefix(240)) } }
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button { text = "🎉"; send() } label: { Text("🎉").font(.title3).frame(width: 32, height: 36) }.accessibilityLabel("Send celebration")
                Button { text = "❤️"; send() } label: { Image(systemName: "heart.fill").foregroundStyle(PredictionColors.red).font(.title3).frame(width: 32, height: 36) }.accessibilityLabel("Send heart")
            } else {
                Button(action: send) { Image(systemName: "arrow.up.circle.fill").font(.title2).foregroundStyle(PredictionColors.blue).frame(width: 36, height: 36) }
                    .accessibilityLabel("Send message").accessibilityIdentifier("prediction-chat-send")
            }
        }.buttonStyle(.plain).padding(.horizontal, 10).padding(.vertical, 8).background(PredictionColors.fill, in: RoundedRectangle(cornerRadius: 25))
    }
    private func send() { editing = false; onSend() }
}

private struct PredictionMatchTradeButtons: View {
    let game: PredictionGame
    let market: PredictionMarket
    var onBuy: (PredictionOutcome) -> Void
    var body: some View {
        HStack(spacing: 12) {
            ForEach(PredictionOutcome.allCases) { outcome in
                Button { onBuy(outcome) } label: {
                    HStack(spacing: 5) {
                        Text(outcome == .yes ? game.homeTeam : game.awayTeam).lineLimit(1).minimumScaleFactor(0.6)
                        Text((market.price(for: outcome) * 100).formatted(.number.precision(.fractionLength(0))) + "%").fontWeight(.semibold).monospacedDigit()
                    }.font(.subheadline).foregroundStyle(.white).padding(.horizontal, 12).frame(maxWidth: .infinity).frame(minHeight: 48)
                        .background(outcome == .yes ? Color(red: 0.02, green: 0.35, blue: 0.65) : Color(red: 0.62, green: 0.01, blue: 0.25), in: RoundedRectangle(cornerRadius: 15))
                        .shadow(color: (outcome == .yes ? Color.blue : Color.red).opacity(0.2), radius: 0, y: 3)
                }.buttonStyle(.plain).disabled(!market.isOpen)
                    .accessibilityLabel("Buy \(outcome.title), \(outcome == .yes ? game.homeTeam : game.awayTeam), \(predictionPrice(market.price(for: outcome)))")
                    .accessibilityIdentifier("prediction-live-buy-\(outcome.rawValue)")
            }
        }
    }
}

private struct PredictionLiveMatch: View {
    let sceneID: UUID
    let marketID: UUID
    @Binding var community: PredictionCommunitySession
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @State private var range = "Game"
    @State private var showChat = false
    @State private var streamVisible = true
    @State private var ticket: PredictionTicketRoute?
    @State private var message = ""
    private var profile: PredictionProfile { store.predictionProfile(for: sceneID) }
    private var market: PredictionMarket? { profile.market(for: marketID) }
    private var game: PredictionGame? { profile.games?.first { $0.marketID == marketID } }
    private var room: String { "match-" + marketID.uuidString }
    var body: some View {
        NavigationStack {
            Group {
                if let market, let game {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 19) {
                            if game.league == "Tennis" && streamVisible {
                                PredictionStreamArtwork().aspectRatio(884.0 / 370.0, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 22))
                                    .overlay(alignment: .topTrailing) {
                                        Button { streamVisible = false } label: { Image(systemName: "xmark").font(.subheadline.weight(.semibold)).foregroundStyle(.white).frame(width: 36, height: 36).background(.black.opacity(0.35), in: Circle()) }.padding(10)
                                            .accessibilityLabel("Hide match reference footage").accessibilityIdentifier("prediction-stream-hide")
                                    }.overlay(alignment: .bottomTrailing) {
                                        Label("Paused", systemImage: "pause.fill").font(.caption2.weight(.semibold)).foregroundStyle(.white).padding(.horizontal, 9).padding(.vertical, 5).background(.black.opacity(0.45), in: Capsule()).padding(10)
                                    }.accessibilityLabel("Paused public tennis match reference footage")
                            }
                            HStack(spacing: 6) {
                                if game.isLive { Circle().fill(PredictionColors.red).frame(width: 6, height: 6).accessibilityHidden(true) }
                                Text(game.status).foregroundStyle(game.isLive ? PredictionColors.red : .secondary)
                                Text("· \(game.league == "Tennis" ? "ExxonMobil Open · ATP Mens" : game.league == "Pro" ? "Pro Football" : game.league)").foregroundStyle(.secondary)
                            }.font(.caption.weight(.medium))
                            Text("\(game.homeTeam) vs \(game.awayTeam)".uppercased()).font(.system(size: 24, weight: .heavy, design: .rounded)).fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                            VStack(spacing: 13) {
                                scoreRow(game.homeTeam, score: game.homeScore, first: true, game: game)
                                scoreRow(game.awayTeam, score: game.awayScore, first: false, game: game)
                            }
                            PredictionDualProbabilityChart(market: market, game: game, range: range).frame(height: 230)
                            HStack {
                                HStack(spacing: 5) { PredictionWordmark().stroke(.gray.opacity(0.4), lineWidth: 1.5).frame(width: 20, height: 20); Text("Polymarket").font(.headline).foregroundStyle(.gray.opacity(0.5)) }
                                Spacer()
                                ForEach(["All", "Game", "Live"], id: \.self) { value in
                                    Button(value) { range = value }.font(.subheadline.weight(range == value ? .semibold : .regular)).foregroundStyle(range == value ? .primary : .secondary).frame(minWidth: 44, minHeight: 44)
                                        .accessibilityAddTraits(range == value ? [.isSelected] : []).accessibilityIdentifier("prediction-live-chart-\(value.lowercased())")
                                }
                            }.buttonStyle(.plain)
                            Button { showChat.toggle() } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack { Text("\((37_854 + (community.messages[room]?.count ?? 0)).formatted()) chatting").font(.subheadline); Spacer(); Image(systemName: "bubble").foregroundStyle(.secondary) }
                                    HStack(spacing: 8) {
                                        PredictionCommunityAvatar(name: "jsmth", asset: nil, color: PredictionColors.blue).frame(width: 24, height: 24)
                                        Text(community.messages[room]?.last?.author ?? "jsmth").font(.subheadline.weight(.semibold))
                                        Text(community.messages[room]?.last?.text ?? "Can't wait for the next point").font(.subheadline).lineLimit(1)
                                    }
                                }.foregroundStyle(.primary).padding(13).background(PredictionColors.fill, in: RoundedRectangle(cornerRadius: 17))
                            }.buttonStyle(.plain).accessibilityLabel(showChat ? "Collapse match chat" : "Open match chat").accessibilityIdentifier("prediction-live-chat")
                            if showChat {
                                ForEach(community.messages[room] ?? []) { item in
                                    PredictionChatRow(message: item, game: game, isReacted: community.reacted.contains(item.id)) {
                                        if community.reacted.contains(item.id) { community.reacted.remove(item.id) } else { community.reacted.insert(item.id) }
                                    }
                                }
                                PredictionChatComposer(text: $message) {
                                    community.post(message, room: room, author: store.scenes.first { $0.id == sceneID }?.name ?? "You")
                                    message = ""
                                }
                            }
                            if game.league == "Tennis" && !streamVisible {
                                Button { streamVisible = true } label: { Label("Show match footage", systemImage: "video") }.font(.subheadline).accessibilityIdentifier("prediction-stream-show")
                            }
                        }.frame(maxWidth: 720, alignment: .leading).padding(18).frame(maxWidth: .infinity)
                    }.scrollDismissesKeyboard(.interactively)
                        .safeAreaInset(edge: .bottom) { PredictionMatchTradeButtons(game: game, market: market) { ticket = PredictionTicketRoute(outcome: $0, side: .buy) }.padding(16).background(.white) }
                } else { ContentUnavailableView("Match unavailable", systemImage: "sportscourt") }
            }.background(.white).navigationTitle("Live match").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
                .sheet(item: $ticket) { route in PredictionTradeTicket(sceneID: sceneID, marketID: marketID, initialOutcome: route.outcome, side: route.side) }
                .tint(PredictionColors.blue)
        }
    }
    private func scoreRow(_ name: String, score: Int, first: Bool, game: PredictionGame) -> some View {
        let rank = first ? game.homeRank : game.awayRank
        let sets = first ? game.homeSetScores : game.awaySetScores
        let point = first ? game.homePoint : game.awayPoint
        return HStack(spacing: 13) {
            if game.league == "Tennis" { Text(first ? "🇪🇸" : "🇫🇷").font(.title2).accessibilityHidden(true) }
            else { PredictionTeamArtwork(team: name, league: game.league, color: first ? PredictionColors.red : PredictionColors.blue).frame(width: 30, height: 30) }
            if let rank { Text(rank.formatted()).font(.caption).foregroundStyle(.secondary).frame(width: 18) }
            Text(name).font(.subheadline).lineLimit(1)
            Spacer()
            if first { Image(systemName: game.league == "Tennis" ? "tennisball.fill" : "circle.fill").font(.caption).foregroundStyle(.secondary).accessibilityLabel("Possession") }
            if let sets {
                ForEach(Array(sets.enumerated()), id: \.offset) { item in
                    Text(item.element.formatted()).font(.subheadline.weight(item.offset == sets.count - 1 ? .semibold : .regular)).foregroundStyle(item.offset == sets.count - 1 ? .primary : .secondary).monospacedDigit().frame(minWidth: 16)
                }
            } else { Text(score.formatted()).font(.headline).monospacedDigit() }
            if let point { Text(point).font(.headline).monospacedDigit().frame(width: 34, height: 32).background(PredictionColors.fill, in: RoundedRectangle(cornerRadius: 9)) }
        }.frame(minHeight: 34)
    }
}

/// Original screenshot bytes remain unchanged; layout exposes only the court footage.
private struct PredictionStreamArtwork: View {
    var body: some View {
        GeometryReader { geometry in
            Image("PredictionFidelity-LivestreamReference").resizable()
                .frame(width: geometry.size.width * 946 / 884, height: geometry.size.width * 2048 / 884)
                .offset(x: -geometry.size.width * 31 / 884, y: -geometry.size.width * 660 / 884)
        }.clipped().accessibilityHidden(true)
    }
}

private struct PredictionDualProbabilityChart: View {
    let market: PredictionMarket
    let game: PredictionGame
    let range: String
    private var probabilities: [Double] {
        let count = range == "Live" ? 6 : range == "Game" ? 12 : market.chart.count
        let source = Array(market.chart.suffix(count))
        guard let ending = source.last, ending > 0 else { return [market.yesPrice, market.yesPrice] }
        return source.map { min(0.99, max(0.01, $0 / ending * market.yesPrice)) }
    }
    var body: some View {
        HStack(alignment: .center, spacing: 9) {
            Chart {
                ForEach(Array(probabilities.enumerated()), id: \.offset) { point in
                    LineMark(x: .value("Time", point.offset), y: .value("Probability", point.element * 100), series: .value("Outcome", "Home"))
                        .foregroundStyle(PredictionColors.red).lineStyle(StrokeStyle(lineWidth: 2.5))
                    LineMark(x: .value("Time", point.offset), y: .value("Probability", (1 - point.element) * 100), series: .value("Outcome", "Away"))
                        .foregroundStyle(Color(red: 0.08, green: 0.16, blue: 0.65)).lineStyle(StrokeStyle(lineWidth: 2.5))
                }
                if let last = probabilities.last {
                    PointMark(x: .value("Time", probabilities.count - 1), y: .value("Probability", last * 100)).foregroundStyle(PredictionColors.red).symbolSize(70)
                    PointMark(x: .value("Time", probabilities.count - 1), y: .value("Probability", (1 - last) * 100)).foregroundStyle(Color(red: 0.08, green: 0.16, blue: 0.65)).symbolSize(70)
                }
            }.chartYScale(domain: 0...100).chartXAxis(.hidden).chartYAxis(.hidden)
            VStack(alignment: .leading) {
                outcome(game.homeTeam, probability: market.yesPrice, color: PredictionColors.red)
                Spacer()
                outcome(game.awayTeam, probability: market.noPrice, color: Color(red: 0.08, green: 0.16, blue: 0.65))
            }.frame(width: 92).padding(.vertical, 20)
        }.accessibilityElement(children: .ignore).accessibilityLabel("Match probability chart")
            .accessibilityValue("\(range): \(game.homeTeam), \(Int(market.yesPrice * 100)) percent; \(game.awayTeam), \(Int(market.noPrice * 100)) percent")
    }
    private func outcome(_ name: String, probability: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(name).font(.caption.weight(.semibold)).lineLimit(2)
            Text((probability * 100).formatted(.number.precision(.fractionLength(0))) + "%").font(.system(size: 34, weight: .heavy, design: .rounded)).minimumScaleFactor(0.6).lineLimit(1)
        }.foregroundStyle(color)
    }
}

private enum PredictionComboStyle {
    static var gradient: LinearGradient {
        LinearGradient(colors: [Color(red: 0.40, green: 0.74, blue: 0.59), Color(red: 0.45, green: 0.49, blue: 0.84), Color(red: 0.72, green: 0.29, blue: 0.86)], startPoint: .leading, endPoint: .trailing)
    }
}

private struct PredictionComboTicket: View {
    let sceneID: UUID
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @State private var legs: [PredictionComboLeg] = []
    @State private var costText = "5.00"
    @State private var selecting = false
    @State private var review: PredictionComboQuote?
    @State private var currentQuote: PredictionComboQuote?
    @State private var completed: PredictionComboTrade?
    @State private var loaded = false
    @FocusState private var editingCost: Bool
    private var scene: StudioScene? { store.scenes.first { $0.id == sceneID } }
    private var profile: PredictionProfile { store.predictionProfile(for: sceneID) }
    private var cost: Double { Simulation.parseAmount(costText) ?? 0 }
    private var quote: PredictionComboQuote? { currentQuote }
    private var shownQuote: PredictionComboQuote? { review ?? quote }
    var body: some View {
        NavigationStack {
            Group {
                if let scene {
                    if let completed { confirmation(completed, scene: scene) }
                    else { ticket(scene) }
                } else { ContentUnavailableView("Combo unavailable", systemImage: "square.stack.3d.up") }
            }.background(.white).toolbar(.hidden, for: .navigationBar)
                .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { editingCost = false } } }
                .sheet(isPresented: $selecting) { PredictionComboSelection(profile: profile, legs: $legs) }
                .onAppear {
                    guard !loaded else { return }
                    loaded = true
                    let fixtures = (profile.games ?? []).compactMap { profile.market(for: $0.marketID) }.filter(\.isOpen)
                    let initial = fixtures.count >= 2 ? fixtures : profile.markets.filter(\.isOpen)
                    legs = initial.prefix(2).map { PredictionComboLeg(marketID: $0.id, outcome: .yes) }
                    refreshQuote()
                }
                .onChange(of: legs) { _, _ in refreshQuote() }
                .onChange(of: costText) { _, _ in refreshQuote() }
                .onChange(of: profile) { _, _ in if completed == nil { refreshQuote() } }
                .onChange(of: scene?.balance) { _, _ in if completed == nil { refreshQuote() } }
                .tint(PredictionColors.blue)
        }.presentationDetents([.large]).presentationDragIndicator(.visible).presentationCornerRadius(28)
    }
    private func refreshQuote() {
        store.error = nil
        currentQuote = store.quotePredictionCombo(sceneID: sceneID, legs: legs, cost: cost)
    }
    private func ticket(_ scene: StudioScene) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "square.stack.3d.up.fill").font(.title3).foregroundStyle(PredictionComboStyle.gradient).accessibilityHidden(true)
                Text("Combo · \(legs.count) Markets").font(.headline)
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(width: 36, height: 36).background(PredictionColors.fill, in: Circle()) }
                    .accessibilityLabel("Close combo").accessibilityIdentifier("prediction-combo-close")
            }.padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 14)
            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Cost").font(.subheadline).foregroundStyle(.secondary)
                    if review != nil { Text(scene.money(shownQuote?.totalCost ?? cost)).font(.system(size: 30, weight: .bold)).foregroundStyle(.secondary).monospacedDigit() }
                    else {
                        HStack(spacing: 1) {
                            Text(scene.currency == "GBP" ? "£" : scene.currency == "EUR" ? "€" : "$")
                            TextField("5.00", text: $costText).keyboardType(.decimalPad).focused($editingCost).accessibilityIdentifier("prediction-combo-cost")
                        }.font(.system(size: 30, weight: .bold)).foregroundStyle(.secondary).monospacedDigit()
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 6) {
                    Text(shownQuote.map { "To Win \($0.multiplier.formatted(.number.precision(.fractionLength(1))))x" } ?? "To Win").font(.subheadline).foregroundStyle(.secondary)
                    Text(shownQuote.map { scene.money($0.potentialPayout) } ?? "—").font(.system(size: 30, weight: .bold)).foregroundStyle(PredictionComboStyle.gradient).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                        .accessibilityIdentifier("prediction-combo-payout")
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.padding(.horizontal, 20).padding(.bottom, 19)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if review != nil { Text("Review your combo").font(.subheadline.weight(.semibold)).foregroundStyle(PredictionColors.blue) }
                    ForEach(Array(legs.enumerated()), id: \.element.marketID) { item in
                        if let market = profile.market(for: item.element.marketID) {
                            let game = profile.games?.first { $0.marketID == market.id }
                            VStack(alignment: .leading, spacing: 12) {
                                Text(game.map { "\($0.homeTeam) vs. \($0.awayTeam) · \($0.league)" } ?? market.category)
                                    .font(.caption).foregroundStyle(.secondary)
                                HStack(alignment: .top, spacing: 11) {
                                    Image(systemName: "circle").font(.body).foregroundStyle(.gray.opacity(0.25)).padding(.top, 2).accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(reviewQuestion(at: item.offset) ?? game.map { "\(item.element.outcome == .yes ? $0.homeTeam : $0.awayTeam), To win" } ?? market.question)
                                            .font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                        Text(item.element.outcome.title).font(.subheadline.weight(.semibold)).foregroundStyle(predictionOutcomeColor(item.element.outcome))
                                    }
                                    Spacer(minLength: 4)
                                    Text((reviewPrice(at: item.offset, current: market.price(for: item.element.outcome)) * 100).formatted(.number.precision(.fractionLength(0))) + "%")
                                        .font(.subheadline.weight(.medium)).foregroundStyle(.secondary).monospacedDigit()
                                }
                            }.accessibilityElement(children: .combine).accessibilityIdentifier("prediction-combo-leg-\(market.id.uuidString)")
                        }
                    }
                    if review == nil {
                        Button { editingCost = false; selecting = true } label: { Label("Edit markets", systemImage: "plus.circle") }.font(.subheadline.weight(.medium)).frame(minHeight: 44).accessibilityIdentifier("prediction-combo-edit-markets")
                    }
                    Text("Cash available · \(scene.money(scene.balance))").font(.caption).foregroundStyle(.secondary)
                    if legs.count < 2 { Text("Choose at least two markets.").font(.footnote).foregroundStyle(.secondary) }
                    else if cost <= 0 { Text("Enter a cost greater than zero.").font(.footnote).foregroundStyle(.secondary) }
                    else if cost > scene.balance { Text("Enter a cost within your cash balance.").font(.footnote).foregroundStyle(PredictionColors.red) }
                    else if quote == nil && review == nil { Text("Choose open markets and a valid cost to continue.").font(.footnote).foregroundStyle(.secondary) }
                    if let error = store.error { Text(error).font(.footnote).foregroundStyle(PredictionColors.red).accessibilityIdentifier("prediction-combo-error") }
                }.padding(20)
            }.scrollDismissesKeyboard(.interactively)
            VStack(spacing: 8) {
                if review != nil {
                    Text("Your cost buys one position across all selected outcomes.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Edit combo") { review = nil; store.error = nil }.font(.subheadline).frame(minHeight: 36).accessibilityIdentifier("prediction-combo-edit")
                }
                Button(review == nil ? "Buy" : "Confirm Buy") {
                    editingCost = false
                    store.error = nil
                    if let review {
                        if let trade = store.tradePredictionCombo(sceneID: sceneID, legs: review.legs, cost: review.totalCost, expectedQuote: review) { completed = trade; self.review = nil }
                        else { self.review = nil }
                    } else { review = quote }
                }.font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).frame(minHeight: 50)
                    .background(PredictionComboStyle.gradient, in: RoundedRectangle(cornerRadius: 17))
                    .opacity(shownQuote == nil ? 0.45 : 1).disabled(shownQuote == nil)
                    .accessibilityIdentifier(review == nil ? "prediction-combo-review" : "prediction-combo-confirm")
            }.padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 18).background(.white)
        }
    }
    private func reviewQuestion(at index: Int) -> String? {
        guard let review, review.questions.indices.contains(index) else { return nil }
        return review.questions[index]
    }
    private func reviewPrice(at index: Int, current: Double) -> Double {
        guard let review, review.legPrices.indices.contains(index) else { return current }
        return review.legPrices[index]
    }
    private func confirmation(_ trade: PredictionComboTrade, scene: StudioScene) -> some View {
        VStack(spacing: 21) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 58)).foregroundStyle(PredictionComboStyle.gradient).accessibilityHidden(true)
            Text("Combo bought").font(.title.bold())
            Text("\(trade.legs.count) markets · \(scene.money(trade.totalCost)) cost").font(.headline)
            Text("To win \(scene.money(trade.potentialPayout))").font(.title2.bold()).foregroundStyle(PredictionComboStyle.gradient)
            Text("Your combo is in your portfolio and trade history.").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Done") { dismiss() }.buttonStyle(.borderedProminent).controlSize(.large).accessibilityIdentifier("prediction-combo-done")
        }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PredictionComboPositionDetail: View {
    let sceneID: UUID
    let positionID: UUID
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    private var profile: PredictionProfile { store.predictionProfile(for: sceneID) }
    private var scene: StudioScene? { store.scenes.first { $0.id == sceneID } }
    private var position: PredictionComboPosition? { profile.comboPositions?.first { $0.id == positionID } }
    var body: some View {
        NavigationStack {
            Group {
                if let position, let scene {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Label("Combo · \(position.legs.count) Markets", systemImage: "square.stack.3d.up.fill").font(.title2.bold()).foregroundStyle(PredictionComboStyle.gradient)
                            HStack {
                                VStack(alignment: .leading, spacing: 6) { Text("Current value").font(.caption).foregroundStyle(.secondary); Text(scene.money(profile.value(of: position))).font(.title2.bold()).monospacedDigit() }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 6) { Text("Potential payout").font(.caption).foregroundStyle(.secondary); Text(scene.money(position.potentialPayout)).font(.title2.bold()).foregroundStyle(PredictionComboStyle.gradient).monospacedDigit() }
                            }
                            LabeledContent("Cost", value: scene.money(position.entryCost))
                            LabeledContent("Bought", value: position.date.formatted(date: .abbreviated, time: .shortened))
                            Divider()
                            ForEach(Array(position.legs.enumerated()), id: \.offset) { item in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(position.questions[item.offset]).font(.headline)
                                    HStack {
                                        Text(item.element.outcome.title).foregroundStyle(predictionOutcomeColor(item.element.outcome))
                                        Spacer()
                                        Text("Bought at \(predictionPrice(position.legPrices[item.offset]))").foregroundStyle(.secondary)
                                    }.font(.subheadline)
                                    if let market = profile.market(for: item.element.marketID) {
                                        Text("Now \(predictionPrice(market.price(for: item.element.outcome)))").font(.caption).foregroundStyle(.secondary)
                                    }
                                }.padding(14).predictionSurface()
                            }
                            Text("The potential payout applies if every selected outcome wins. Current value uses the saved prices of all legs.").font(.footnote).foregroundStyle(.secondary)
                        }.padding(20).frame(maxWidth: 720, alignment: .leading).frame(maxWidth: .infinity)
                    }
                } else { ContentUnavailableView("Combo unavailable", systemImage: "square.stack.3d.up") }
            }.navigationTitle("Your combo").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }.tint(PredictionColors.blue)
        }
    }
}

private struct PredictionComboSelection: View {
    let profile: PredictionProfile
    @Binding var legs: [PredictionComboLeg]
    @Environment(\.dismiss) private var dismiss
    @State private var originalLegs: [PredictionComboLeg] = []
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Choose 2 to 8 different markets. Each selected outcome becomes one leg in your combo.").font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(profile.markets.filter(\.isOpen)) { market in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(market.question).font(.headline)
                        HStack(spacing: 10) {
                            ForEach(PredictionOutcome.allCases) { outcome in
                                let selected = legs.contains { $0.marketID == market.id && $0.outcome == outcome }
                                Button {
                                    if selected { legs.removeAll { $0.marketID == market.id } }
                                    else if let index = legs.firstIndex(where: { $0.marketID == market.id }) { legs[index] = PredictionComboLeg(marketID: market.id, outcome: outcome) }
                                    else if legs.count < 8 { legs.append(PredictionComboLeg(marketID: market.id, outcome: outcome)) }
                                } label: {
                                    HStack { Image(systemName: selected ? "checkmark.circle.fill" : "circle"); Text("\(outcome.title) \(predictionPrice(market.price(for: outcome)))") }
                                        .font(.subheadline.weight(.medium)).frame(maxWidth: .infinity).frame(minHeight: 44)
                                        .foregroundStyle(selected ? .white : predictionOutcomeColor(outcome))
                                        .background(selected ? predictionOutcomeColor(outcome) : predictionOutcomeColor(outcome).opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                                }.buttonStyle(.plain).disabled(!selected && !legs.contains { $0.marketID == market.id } && legs.count >= 8)
                                    .accessibilityAddTraits(selected ? [.isSelected] : []).accessibilityIdentifier("prediction-combo-select-\(market.id.uuidString)-\(outcome.rawValue)")
                            }
                        }
                    }.padding(.vertical, 6)
                }
            }.navigationTitle("Combo markets").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { legs = originalLegs; dismiss() }.accessibilityIdentifier("prediction-combo-selection-cancel") }
                    ToolbarItem(placement: .confirmationAction) { Button("Done · \(legs.count)") { dismiss() }.disabled(legs.count < 2).accessibilityIdentifier("prediction-combo-selection-done") }
                }
                .tint(PredictionColors.blue)
                .onAppear { originalLegs = legs }
        }
    }
}

private struct PredictionMarketDetail: View {
    let sceneID: UUID
    let marketID: UUID
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @State private var outcome: PredictionOutcome = .yes
    @State private var range = "1W"
    @State private var ticket: PredictionTicketRoute?
    private var scene: StudioScene? { store.scenes.first { $0.id == sceneID } }
    private var profile: PredictionProfile { store.predictionProfile(for: sceneID) }
    private var market: PredictionMarket? { profile.market(for: marketID) }
    private var game: PredictionGame? { profile.games?.first { $0.marketID == marketID } }
    private var owned: Double { profile.positions.first { $0.marketID == marketID && $0.outcome == outcome }?.shares ?? 0 }

    var body: some View {
        NavigationStack {
            Group {
                if let market, let scene {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            if let game { PredictionMatchHeader(game: game) }
                            else { Text(market.category).font(.subheadline.weight(.semibold)).foregroundStyle(PredictionColors.blue) }
                            Text(market.question).font(.title2.bold()).fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                            VStack(alignment: .leading, spacing: 12) {
                                Text((market.yesPrice * 100).formatted(.number.precision(.fractionLength(0...1))) + "% chance")
                                    .font(.largeTitle.bold()).monospacedDigit()
                                PredictionProbabilityChart(values: market.chart, currentProbability: market.yesPrice, range: range).frame(height: 190)
                                Picker("Chart period", selection: $range) {
                                    ForEach(["1D", "1W", "1M", "ALL"], id: \.self) { Text($0).tag($0) }
                                }.pickerStyle(.segmented)
                            }
                            HStack { Label("\(scene.money(market.volume)) volume", systemImage: "chart.bar"); Spacer() }
                                .font(.subheadline).foregroundStyle(.secondary)
                            LabeledContent("Market closes", value: market.closeDate.formatted(date: .abbreviated, time: .shortened))
                            Divider()
                            Picker("Outcome", selection: $outcome) {
                                ForEach(PredictionOutcome.allCases) { Text("\($0.title) · \(predictionPrice(market.price(for: $0)))").tag($0) }
                            }.pickerStyle(.segmented).accessibilityIdentifier("prediction-outcome")
                            if owned > 0 { LabeledContent("Your \(outcome.title) shares", value: predictionQuantity(owned)) }
                            if !market.isOpen { Text("This market is closed for trading.").font(.subheadline).foregroundStyle(.secondary) }
                            HStack(spacing: 12) {
                                Button("Buy \(outcome.title)") { ticket = PredictionTicketRoute(outcome: outcome, side: .buy) }
                                    .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity)
                                    .accessibilityIdentifier("prediction-buy").disabled(!market.isOpen)
                                Button("Sell \(outcome.title)") { ticket = PredictionTicketRoute(outcome: outcome, side: .sell) }
                                    .buttonStyle(.bordered).controlSize(.large).frame(maxWidth: .infinity)
                                    .accessibilityIdentifier("prediction-sell").disabled(!market.isOpen || owned <= 0)
                            }
                        }
                        .frame(maxWidth: 720, alignment: .leading).padding(20).frame(maxWidth: .infinity)
                    }
                } else { ContentUnavailableView("Market unavailable", systemImage: "chart.xyaxis.line") }
            }
            .navigationTitle("Market").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $ticket) { route in PredictionTradeTicket(sceneID: sceneID, marketID: marketID, initialOutcome: route.outcome, side: route.side) }
            .tint(PredictionColors.blue).preferredColorScheme(.light)
        }
        .accessibilityIdentifier("prediction-market-detail")
    }
}

private struct PredictionMatchHeader: View {
    let game: PredictionGame
    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 5) {
                if game.isLive { Circle().fill(PredictionColors.red).frame(width: 5, height: 5).accessibilityHidden(true) }
                Text(game.status).foregroundStyle(game.isLive ? PredictionColors.red : .secondary)
                Text("· \(game.league == "Pro" ? "Pro Football" : game.league)").foregroundStyle(.secondary)
            }.font(.caption.weight(.medium))
            HStack(alignment: .center, spacing: 16) {
                team(game.homeTeam, score: game.homeScore, color: PredictionColors.blue)
                Text("vs").font(.subheadline).foregroundStyle(.secondary)
                team(game.awayTeam, score: game.awayScore, color: Color(red: 0.88, green: 0.36, blue: 0.18))
            }
        }.frame(maxWidth: .infinity).padding(.vertical, 10)
    }
    private func team(_ name: String, score: Int, color: Color) -> some View {
        VStack(spacing: 8) {
            PredictionTeamArtwork(team: name, league: game.league, color: color).frame(width: 60, height: 60)
            Text(name).font(.subheadline.weight(.semibold)).lineLimit(2).multilineTextAlignment(.center)
            if game.isLive { Text(score.formatted()).font(.title3.weight(.semibold)).monospacedDigit() }
        }.frame(maxWidth: .infinity)
    }
}

private struct PredictionTradeTicket: View {
    let sceneID: UUID
    let marketID: UUID
    let initialOutcome: PredictionOutcome
    let side: MarketTradeSide
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @State private var outcome: PredictionOutcome = .yes
    @State private var sharesText = ""
    @State private var review: PredictionReview?
    @State private var completed: PredictionTrade?
    @State private var quoteError: String?
    @State private var didLoad = false
    @FocusState private var editing: Bool
    private var scene: StudioScene? { store.scenes.first { $0.id == sceneID } }
    private var profile: PredictionProfile { store.predictionProfile(for: sceneID) }
    private var market: PredictionMarket? { profile.market(for: marketID) }
    private var shares: Double { Simulation.parseAmount(sharesText) ?? 0 }
    private var price: Double { market?.price(for: outcome) ?? 0 }
    private var total: Double { shares * price }
    private var owned: Double { profile.positions.first { $0.marketID == marketID && $0.outcome == outcome }?.shares ?? 0 }
    private var valid: Bool {
        market?.isOpen == true && shares.isFinite && shares > 0 && shares <= 1_000_000_000
            && total.isFinite && total > 0 && total <= 1_000_000_000
            && (side == .buy ? total <= (scene?.balance ?? 0) : shares <= owned)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let scene, let market {
                    if let completed { confirmation(completed, scene: scene) }
                    else if let review { reviewPage(review, scene: scene, market: market) }
                    else { orderForm(scene, market: market) }
                } else { ContentUnavailableView("Market unavailable", systemImage: "chart.xyaxis.line") }
            }
            .navigationTitle(completed != nil ? "Trade complete" : review != nil ? "Review trade" : "\(side.title) shares")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(completed == nil ? "Cancel" : "Done") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { editing = false } }
            }
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                outcome = initialOutcome
                sharesText = side == .sell ? predictionEntry(owned) : "100"
            }
            .tint(PredictionColors.blue).preferredColorScheme(.light)
        }
        .accessibilityIdentifier("prediction-order-ticket")
    }

    private func orderForm(_ scene: StudioScene, market: PredictionMarket) -> some View {
        Form {
            Section { Text(market.question).font(.headline) }
            Section {
                Picker("Outcome", selection: $outcome) {
                    ForEach(PredictionOutcome.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented).accessibilityIdentifier("prediction-ticket-outcome")
                LabeledContent("Price per share", value: predictionPrice(price))
                TextField("Shares", text: $sharesText).keyboardType(.decimalPad).focused($editing)
                    .accessibilityIdentifier("prediction-shares")
                LabeledContent(side == .buy ? "Available cash" : "Shares available", value: side == .buy ? scene.money(scene.balance) : predictionQuantity(owned))
                LabeledContent(side == .buy ? "Total cost" : "You receive", value: scene.money(total))
            } header: { Text(side.title) } footer: {
                if !market.isOpen { Text("This market is closed for trading.") }
                else if side == .buy && total > scene.balance { Text("Enter fewer shares to stay within your cash balance.") }
                else if side == .sell && shares > owned { Text("You can sell up to \(predictionQuantity(owned)) \(outcome.title) shares.") }
            }
            Section {
                Button("Review trade") {
                    editing = false
                    quoteError = nil
                    review = PredictionReview(outcome: outcome, shares: shares, price: price)
                }
                .disabled(!valid).accessibilityIdentifier("prediction-review")
            }
            errorSection
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func reviewPage(_ quote: PredictionReview, scene: StudioScene, market: PredictionMarket) -> some View {
        Form {
            Section { Text(market.question).font(.headline) }
            Section("Order summary") {
                LabeledContent("Action", value: "\(side.title) \(quote.outcome.title)")
                LabeledContent("Shares", value: predictionQuantity(quote.shares))
                LabeledContent("Price per share", value: predictionPrice(quote.price))
                LabeledContent(side == .buy ? "Total cost" : "You receive", value: scene.money(quote.shares * quote.price))
                LabeledContent("Cash after trade", value: scene.money(scene.balance + (side == .buy ? -1 : 1) * quote.shares * quote.price))
            }
            Section {
                Button("Confirm \(side.title.lowercased())") { confirm(quote) }
                    .accessibilityIdentifier("prediction-confirm")
                    .disabled(!market.isOpen)
                Button("Edit order") { review = nil }
            } footer: { Text("Your cash balance and position update when you confirm.") }
            errorSection
        }
    }

    private var errorSection: some View {
        Group {
            if let message = quoteError ?? store.error { Section { Text(message).foregroundStyle(.red) } }
        }
    }
    private func confirm(_ quote: PredictionReview) {
        guard let market, market.isOpen, market.price(for: quote.outcome) == quote.price else {
            quoteError = "The price changed or the market closed. Review your order again."
            review = nil
            return
        }
        if let trade = store.tradePrediction(sceneID: sceneID, marketID: marketID, outcome: quote.outcome, side: side, shares: quote.shares) {
            completed = trade
            review = nil
        }
    }
    private func confirmation(_ trade: PredictionTrade, scene: StudioScene) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundStyle(PredictionColors.green).accessibilityHidden(true)
                Text("\(trade.side == .buy ? "Bought" : "Sold") \(trade.outcome.title)").font(.largeTitle.bold())
                Text("\(predictionQuantity(trade.shares)) shares at \(predictionPrice(trade.price))").font(.title3)
                Text(scene.money(trade.total)).font(.title.bold()).monospacedDigit()
                Text(trade.question).font(.headline).multilineTextAlignment(.center)
                Text("Your portfolio and trade history are updated.").foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Done") { dismiss() }.buttonStyle(.borderedProminent).controlSize(.large)
                    .accessibilityIdentifier("prediction-trade-done")
            }
            .frame(maxWidth: 600).padding(28).padding(.top, 30).frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("prediction-confirmation")
    }
}

private struct PredictionMarketManager: View {
    let sceneID: UUID
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @State private var editing: PredictionMarket?
    private var profile: PredictionProfile { store.predictionProfile(for: sceneID) }
    private func canDelete(_ market: PredictionMarket) -> Bool {
        !profile.positions.contains { $0.marketID == market.id } && !profile.transactions.contains { $0.marketID == market.id }
        && !(profile.comboPositions ?? []).contains { $0.legs.contains { $0.marketID == market.id } }
        && !(profile.comboTransactions ?? []).contains { $0.legs.contains { $0.marketID == market.id } }
    }
    var body: some View {
        NavigationStack {
            List {
                if profile.markets.isEmpty { ContentUnavailableView("No markets", systemImage: "chart.xyaxis.line", description: Text("Add a question, probability, and chart to create a market.")) }
                ForEach(profile.markets) { market in
                    Button { editing = market } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(market.question).font(.headline).foregroundStyle(.primary)
                            Text("\(market.category) · \((market.yesPrice * 100).formatted(.number.precision(.fractionLength(0...1))))% Yes")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }.padding(.vertical, 6)
                    }
                    .swipeActions {
                        if canDelete(market) {
                            Button("Delete", role: .destructive) {
                                var value = profile
                                value.markets.removeAll { $0.id == market.id }
                                value.games?.removeAll { $0.marketID == market.id }
                                _ = store.updatePredictionProfile(value)
                            }
                        }
                    }
                }
                if let error = store.error { Section { Text(error).foregroundStyle(.red) } }
                Section { Text("Markets with positions or trade history are kept so your records stay complete.").font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle("Manage markets").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        editing = PredictionMarket(question: "Will the next milestone happen?", category: "Culture", yesPrice: 0.5, volume: 0,
                                                   closeDate: Date().addingTimeInterval(30 * 86_400), chart: [0.45, 0.48, 0.46, 0.5])
                    } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add market").disabled(profile.markets.count >= 100)
                }
            }
            .sheet(item: $editing) { PredictionMarketEditor(sceneID: sceneID, market: $0) }
            .tint(PredictionColors.blue).preferredColorScheme(.light)
        }
    }
}

private struct PredictionMarketEditor: View {
    let sceneID: UUID
    @State var market: PredictionMarket
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @State private var chance = ""
    @State private var volume = ""
    @State private var chart = ""
    @State private var didLoad = false
    @State private var hasGame = false
    @State private var gameID = UUID()
    @State private var gameLeague = "Pro"
    @State private var homeTeam = "Home team"
    @State private var awayTeam = "Away team"
    @State private var homeScore = "0"
    @State private var awayScore = "0"
    @State private var gameStatus = "Scheduled"
    @State private var liveGame = false
    @State private var homeSetScores = ""
    @State private var awaySetScores = ""
    @State private var homePoint = ""
    @State private var awayPoint = ""
    @State private var homeRank = ""
    @State private var awayRank = ""
    private enum Field: Hashable { case question, category, chance, volume, chart, league, homeTeam, awayTeam, homeScore, awayScore, status, homeSets, awaySets, homeRank, awayRank }
    @FocusState private var focused: Field?
    private var prepared: PredictionMarket? {
        guard let probability = Simulation.parseAmount(chance), (0...100).contains(probability),
              let volumeValue = Simulation.parseAmount(volume), let points = predictionParseChart(chart) else { return nil }
        var value = market
        value.question = market.question.trimmingCharacters(in: .whitespacesAndNewlines)
        value.category = market.category.trimmingCharacters(in: .whitespacesAndNewlines)
        value.yesPrice = probability / 100
        value.volume = volumeValue
        value.chart = points
        return value.isValid ? value : nil
    }
    private var preparedGame: PredictionGame? {
        guard let firstScore = integerScore(homeScore), let secondScore = integerScore(awayScore) else { return nil }
        guard homeSetScores.trimmingCharacters(in: .whitespaces).isEmpty || tennisSets(homeSetScores) != nil,
              awaySetScores.trimmingCharacters(in: .whitespaces).isEmpty || tennisSets(awaySetScores) != nil,
              homeRank.trimmingCharacters(in: .whitespaces).isEmpty || tennisRank(homeRank) != nil,
              awayRank.trimmingCharacters(in: .whitespaces).isEmpty || tennisRank(awayRank) != nil else { return nil }
        var value = PredictionGame(id: gameID, marketID: market.id,
            league: gameLeague.trimmingCharacters(in: .whitespacesAndNewlines),
            homeTeam: homeTeam.trimmingCharacters(in: .whitespacesAndNewlines), awayTeam: awayTeam.trimmingCharacters(in: .whitespacesAndNewlines),
            homeScore: firstScore, awayScore: secondScore, status: gameStatus.trimmingCharacters(in: .whitespacesAndNewlines), isLive: liveGame)
        value.homeSetScores = tennisSets(homeSetScores)
        value.awaySetScores = tennisSets(awaySetScores)
        value.homePoint = homePoint.isEmpty ? nil : homePoint
        value.awayPoint = awayPoint.isEmpty ? nil : awayPoint
        value.homeRank = tennisRank(homeRank)
        value.awayRank = tennisRank(awayRank)
        return value.isValid ? value : nil
    }
    private var valid: Bool { prepared != nil && (!hasGame || preparedGame != nil) }
    var body: some View {
        NavigationStack {
            Form {
                Section("Question") {
                    TextField("Market question", text: $market.question, axis: .vertical).lineLimit(2...5).focused($focused, equals: .question)
                        .accessibilityIdentifier("prediction-market-question")
                    TextField("Category", text: $market.category).focused($focused, equals: .category)
                }
                if hasGame || market.category.lowercased() == "sports" { sportsSettings }
                if hasGame && (gameLeague.lowercased() == "tennis" || !homeSetScores.isEmpty || !awaySetScores.isEmpty || !homePoint.isEmpty || !awayPoint.isEmpty || !homeRank.isEmpty || !awayRank.isEmpty) { tennisSettings }
                Section("Market") {
                    numberField("Yes probability · %", placeholder: "Probability from 0 to 100", text: $chance, field: .chance)
                    numberField("Trading volume", placeholder: "Volume", text: $volume, field: .volume)
                    DatePicker("Closes", selection: $market.closeDate)
                }
                Section {
                    TextField("Chart values", text: $chart, axis: .vertical).lineLimit(3...7)
                        .keyboardType(.numbersAndPunctuation).focused($focused, equals: .chart)
                } header: { Text("Probability chart") } footer: {
                    Text("Enter 2–120 chart shape values from 0 to 1, separated by commas. Use a period for decimals. The chart ends at the current Yes probability. Questions can have up to 180 characters; categories up to 40.")
                }
                if let error = store.error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("Edit market").navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(!valid) }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focused = nil } }
            }
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                chance = predictionEntry(market.yesPrice * 100)
                volume = predictionEntry(market.volume)
                chart = market.chart.map { String($0) }.joined(separator: ", ")
                if let game = store.predictionProfile(for: sceneID).games?.first(where: { $0.marketID == market.id }) {
                    hasGame = true; gameID = game.id; gameLeague = game.league
                    homeTeam = game.homeTeam; awayTeam = game.awayTeam
                    homeScore = String(game.homeScore); awayScore = String(game.awayScore)
                    gameStatus = game.status; liveGame = game.isLive
                    homeSetScores = (game.homeSetScores ?? []).map(String.init).joined(separator: ", ")
                    awaySetScores = (game.awaySetScores ?? []).map(String.init).joined(separator: ", ")
                    homePoint = game.homePoint ?? ""; awayPoint = game.awayPoint ?? ""
                    homeRank = game.homeRank.map(String.init) ?? ""; awayRank = game.awayRank.map(String.init) ?? ""
                }
            }
            .tint(PredictionColors.blue)
        }
    }
    private var sportsSettings: some View {
        Section {
            Toggle("Show as sports match", isOn: $hasGame)
                .accessibilityIdentifier("prediction-sports-match")
            if hasGame {
                TextField("League", text: $gameLeague).focused($focused, equals: .league)
                TextField("Home team", text: $homeTeam).focused($focused, equals: .homeTeam)
                    .accessibilityIdentifier("prediction-home-team")
                TextField("Away team", text: $awayTeam).focused($focused, equals: .awayTeam)
                    .accessibilityIdentifier("prediction-away-team")
                numberField("Home score", placeholder: "Home score", text: $homeScore, field: .homeScore)
                numberField("Away score", placeholder: "Away score", text: $awayScore, field: .awayScore)
                TextField("Game status or clock", text: $gameStatus).focused($focused, equals: .status)
                    .accessibilityIdentifier("prediction-game-status")
                Toggle("Show in Live", isOn: $liveGame)
            }
        } header: { Text("Match details") } footer: {
            Text("Set the team names, scores, and displayed status for this scene. Home team uses Yes shares; away team uses No shares. Status text stays as entered.")
        }
    }
    private func integerScore(_ text: String) -> Int? {
        guard let value = Simulation.parseAmount(text), (0...999).contains(value), value.rounded(.down) == value else { return nil }
        return Int(value)
    }
    private var tennisSettings: some View {
        Section {
            TextField("Home set scores, e.g. 6, 4", text: $homeSetScores).keyboardType(.numbersAndPunctuation).focused($focused, equals: .homeSets).accessibilityIdentifier("prediction-tennis-home-sets")
            TextField("Away set scores, e.g. 2, 1", text: $awaySetScores).keyboardType(.numbersAndPunctuation).focused($focused, equals: .awaySets).accessibilityIdentifier("prediction-tennis-away-sets")
            Picker("Home point", selection: $homePoint) { ForEach(["", "0", "15", "30", "40", "AD"], id: \.self) { Text($0.isEmpty ? "None" : $0).tag($0) } }.accessibilityIdentifier("prediction-tennis-home-point")
            Picker("Away point", selection: $awayPoint) { ForEach(["", "0", "15", "30", "40", "AD"], id: \.self) { Text($0.isEmpty ? "None" : $0).tag($0) } }.accessibilityIdentifier("prediction-tennis-away-point")
            TextField("Home rank (optional)", text: $homeRank).keyboardType(.numberPad).focused($focused, equals: .homeRank).accessibilityIdentifier("prediction-tennis-home-rank")
            TextField("Away rank (optional)", text: $awayRank).keyboardType(.numberPad).focused($focused, equals: .awayRank).accessibilityIdentifier("prediction-tennis-away-rank")
        } header: { Text("Tennis scoreboard") } footer: {
            Text("Enter 1–5 set scores for both players, separated by commas. Scores range from 0 to 99; optional rankings from 1 to 9,999. Clear these fields to use the main score only.")
        }
    }
    private func tennisSets(_ text: String) -> [Int]? {
        let pieces = text.split(separator: ",", omittingEmptySubsequences: false)
        guard (1...5).contains(pieces.count) else { return nil }
        let values = pieces.compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        return values.count == pieces.count && values.allSatisfy { (0...99).contains($0) } ? values : nil
    }
    private func tennisRank(_ text: String) -> Int? {
        guard let value = Int(text.trimmingCharacters(in: .whitespaces)), (1...9999).contains(value) else { return nil }
        return value
    }
    private func numberField(_ title: String, placeholder: String, text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(placeholder, text: text).keyboardType(.decimalPad).focused($focused, equals: field)
        }
    }
    private func save() {
        guard valid, let market = prepared else { return }
        var profile = store.predictionProfile(for: sceneID)
        if let index = profile.markets.firstIndex(where: { $0.id == market.id }) { profile.markets[index] = market }
        else { profile.markets.append(market) }
        var games = profile.games ?? []
        games.removeAll { $0.marketID == market.id }
        if hasGame, let game = preparedGame { games.append(game) }
        profile.games = games
        if store.updatePredictionProfile(profile) { dismiss() }
    }
}

private struct PredictionProfileEditor: View {
    let sceneID: UUID
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @State private var cash = ""
    @FocusState private var editing: Bool
    private var balance: Double? {
        Simulation.parseAmount(cash).flatMap {
            (0...1_000_000_000).contains($0) && MarketValidation.nonnegative(store.predictionProfile(for: sceneID).total(cash: $0)) ? $0 : nil
        }
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    if let scene = store.scenes.first(where: { $0.id == sceneID }) {
                        LabeledContent("Name", value: scene.name)
                        LabeledContent("Currency", value: scene.currency)
                    }
                    TextField("Cash balance", text: $cash).keyboardType(.decimalPad).focused($editing)
                        .accessibilityIdentifier("prediction-cash-editor")
                }
                Section { Text("Changes to cash leave your market positions and trade history intact.").font(.footnote).foregroundStyle(.secondary) }
                if let error = store.error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("Account settings").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let balance else { return }
                        if store.updatePredictionProfile(store.predictionProfile(for: sceneID), cashBalance: balance) { dismiss() }
                    }.disabled(balance == nil)
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { editing = false } }
            }
            .onAppear { cash = predictionEntry(store.scenes.first { $0.id == sceneID }?.balance ?? 0) }
            .tint(PredictionColors.blue)
        }
    }
}

private struct PredictionProbabilityChart: View {
    let values: [Double]
    let currentProbability: Double
    let range: String
    private var probabilities: [Double] {
        guard let ending = values.last, ending > 0 else {
            return values.enumerated().map { $0.offset == values.count - 1 ? currentProbability : $0.element }
        }
        return values.map { min(1, max(0, $0 / ending * currentProbability)) }
    }
    private var duration: Double { range == "1D" ? 86_400 : range == "1W" ? 7 * 86_400 : range == "1M" ? 30 * 86_400 : 90 * 86_400 }
    var body: some View {
        Chart(Array(probabilities.enumerated()), id: \.offset) { point in
            LineMark(x: .value("Date", Date().addingTimeInterval(-duration + duration * Double(point.offset) / Double(max(values.count - 1, 1)))),
                     y: .value("Yes probability", point.element * 100))
                .foregroundStyle(PredictionColors.blue).lineStyle(StrokeStyle(lineWidth: 2)).interpolationMethod(.monotone)
        }
        .chartYScale(domain: 0...100)
        .chartYAxis { AxisMarks(position: .trailing, values: [0, 50, 100]) { value in
            AxisGridLine().foregroundStyle(Color.secondary.opacity(0.15))
            AxisValueLabel { if let percent = value.as(Double.self) { Text(percent.formatted(.number.precision(.fractionLength(0))) + "%").font(.caption2).foregroundStyle(.secondary) } }
        } }
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) { _ in AxisValueLabel(format: range == "1D" ? .dateTime.hour() : .dateTime.month(.abbreviated).day()) } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Yes probability chart")
        .accessibilityValue("\(range) period, from \(((probabilities.first ?? 0) * 100).formatted(.number.precision(.fractionLength(0)))) to \(((probabilities.last ?? 0) * 100).formatted(.number.precision(.fractionLength(0)))) percent")
    }
}

private enum PredictionTab: String, CaseIterable, Identifiable {
    case home, live, portfolio, squads, search, activity, profile
    static let navigation: [PredictionTab] = [.home, .live, .portfolio, .squads, .search]
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .live: return "dot.radiowaves.left.and.right"
        case .portfolio: return "chart.pie"
        case .squads: return "bubble.left.and.bubble.right"
        case .search: return "magnifyingglass"
        case .activity: return "clock"
        case .profile: return "person.crop.circle"
        }
    }
}
private enum PredictionSheet: Identifiable {
    case market(UUID), trade(UUID, PredictionOutcome, MarketTradeSide), liveMatch(UUID), squad(String), invite, combo, comboPosition(UUID), markets, profile
    var id: String {
        switch self {
        case .market(let id): return "market-\(id)"
        case .trade(let id, let outcome, let side): return "trade-\(id)-\(outcome.rawValue)-\(side.rawValue)"
        case .liveMatch(let id): return "live-match-\(id)"
        case .squad(let id): return "squad-\(id)"
        case .invite: return "squad-invite"
        case .combo: return "combo-ticket"
        case .comboPosition(let id): return "combo-position-\(id)"
        case .markets: return "market-editor"
        case .profile: return "profile"
        }
    }
}
private struct PredictionTicketRoute: Identifiable {
    let id = UUID()
    let outcome: PredictionOutcome
    let side: MarketTradeSide
}
private struct PredictionReview {
    let outcome: PredictionOutcome
    let shares: Double
    let price: Double
}
private enum PredictionColors {
    static let blue = Color(red: 47 / 255.0, green: 92 / 255.0, blue: 1)
    static let green = Color(red: 0.12, green: 0.51, blue: 0.34)
    static let red = Color(red: 0.84, green: 0.06, blue: 0.08)
    static let fill = Color(red: 0.95, green: 0.96, blue: 0.97)
    static let background = Color(red: 0.98, green: 0.98, blue: 0.99)
}
private extension View {
    func predictionSurface() -> some View {
        background(.white, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.secondary.opacity(0.13)))
    }
}
private func predictionCategorySymbol(_ category: String) -> String {
    switch category.lowercased() {
    case "all": return "globe"
    case "sports": return "soccerball"
    case "crypto": return "bitcoinsign"
    case "politics": return "building.columns"
    case "economy", "finance": return "chart.line.uptrend.xyaxis"
    case "tech", "technology": return "cpu"
    default: return "sparkles"
    }
}
private func predictionOutcomeColor(_ outcome: PredictionOutcome) -> Color { outcome == .yes ? PredictionColors.green : PredictionColors.red }
private func predictionPrice(_ value: Double) -> String { (value * 100).formatted(.number.precision(.fractionLength(0...2))) + "¢" }
private func predictionQuantity(_ value: Double) -> String { value.formatted(.number.precision(.significantDigits(1...10))) }
private func predictionSignedMoney(_ value: Double, scene: StudioScene) -> String { (value > 0 ? "+" : "") + scene.money(value) }
private func predictionEntry(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.locale = .current
    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = false
    formatter.maximumFractionDigits = 12
    return formatter.string(from: NSNumber(value: value)) ?? String(value)
}
private func predictionParseChart(_ text: String) -> [Double]? {
    let pieces = text.split(separator: ",", omittingEmptySubsequences: false)
    guard (2...120).contains(pieces.count) else { return nil }
    let values = pieces.compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    return values.count == pieces.count && values.allSatisfy { $0.isFinite && (0...1).contains($0) } ? values : nil
}
