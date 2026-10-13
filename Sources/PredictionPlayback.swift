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
                        header(scene)
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
            LazyVStack(alignment: .leading, spacing: 20) {
                leagueNavigation
                if !liveOnly { seasonBanner }
                if !liveOnly && !trending.isEmpty {
                    Text("Trending").font(.headline).accessibilityAddTraits(.isHeader)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(trending) { game in
                                Button { sheet = .market(game.marketID) } label: { PredictionScoreCard(game: game) }
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
                        PredictionGameCard(game: game, market: market, onOpen: { sheet = .market(market.id) }) { outcome in
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
            .frame(maxWidth: 720, alignment: .leading).padding(16).frame(maxWidth: .infinity)
        }
        .background(.white)
        .accessibilityIdentifier(liveOnly ? "prediction-live" : "prediction-home")
    }

    private var leagueNavigation: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(leagues, id: \.self) { value in
                    Button { league = value } label: {
                        VStack(spacing: 7) {
                            Text(predictionLeagueGlyph(value)).font(.system(size: 25))
                                .frame(width: 46, height: 46)
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
                    Circle().fill(.white.opacity(0.06)).frame(width: geometry.size.width * 0.9).offset(x: geometry.size.width * 0.42, y: -40)
                    PredictionHelmet().frame(width: 150, height: 142).rotationEffect(.degrees(-9)).position(x: geometry.size.width - 72, y: 98)
                }
                VStack(alignment: .leading, spacing: 7) {
                    Text("PRO  FOOTBALL").font(.title2.weight(.heavy)).foregroundStyle(.white)
                    Text("Regular Season").font(.subheadline).foregroundStyle(.white.opacity(0.8))
                    Spacer(minLength: 15)
                    Text("Week 3 of 18").font(.subheadline).foregroundStyle(.white.opacity(0.8))
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.2)).frame(width: 125, height: 4)
                        Capsule().fill(.white).frame(width: 24, height: 4)
                        Circle().fill(.white).frame(width: 13, height: 13).offset(x: 18)
                    }.frame(height: 13).accessibilityHidden(true)
                }
                .padding(20).frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 172).clipShape(RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain).accessibilityLabel("Pro Football regular season, view markets")
        .accessibilityIdentifier("prediction-season-banner")
    }

    private func squads(_ scene: StudioScene) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                Text("Squads").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                Text("Your market groups").font(.headline).foregroundStyle(.secondary)
                ForEach(Array(Set(games.map(\.league))).sorted(), id: \.self) { value in
                    let fixtures = games.filter { $0.league == value }
                    Button { league = value; tab = .home } label: {
                        HStack(spacing: 14) {
                            Text(predictionLeagueGlyph(value)).font(.largeTitle).frame(width: 60, height: 60).background(PredictionColors.fill, in: RoundedRectangle(cornerRadius: 16))
                            VStack(alignment: .leading, spacing: 7) {
                                Text("\(value) watchlist").font(.headline)
                                Text("\(fixtures.count) game\(fixtures.count == 1 ? "" : "s") · view markets").font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).accessibilityHidden(true)
                        }.padding(16).predictionSurface()
                    }
                    .buttonStyle(.plain).foregroundStyle(.primary)
                    .accessibilityIdentifier("prediction-squad-\(value.lowercased())")
                }
                if games.isEmpty { ContentUnavailableView("No market groups", systemImage: "person.2", description: Text("Add sports match details from Manage markets to group your fixtures by league.")) }
            }
            .frame(maxWidth: 720, alignment: .leading).padding(20).frame(maxWidth: .infinity)
        }
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
                if profile.positions.filter({ $0.shares > 0 }).isEmpty {
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
            }
            .frame(maxWidth: 720, alignment: .leading).padding(16).frame(maxWidth: .infinity)
        }
    }

    private func history(_ scene: StudioScene) -> some View {
        List {
            if profile.transactions.isEmpty {
                ContentUnavailableView("No trades yet", systemImage: "clock", description: Text("Confirmed purchases and sales appear here."))
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
                            Text(scene.money(profile.total(cash: scene.balance))).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.6).frame(height: 23)
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
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(game.status, systemImage: game.isLive ? "circle.fill" : "clock")
                    .font(.caption.weight(.semibold)).foregroundStyle(game.isLive ? PredictionColors.red : .secondary)
                Spacer(minLength: 8)
                Text(game.league).font(.caption).foregroundStyle(.secondary)
            }
            scoreRow(game.homeTeam, score: game.homeScore, color: PredictionColors.blue)
            scoreRow(game.awayTeam, score: game.awayScore, color: Color(red: 0.76, green: 0.35, blue: 0.18))
        }
        .padding(15).frame(width: 205, alignment: .leading).predictionSurface()
        .accessibilityElement(children: .combine)
    }
    private func scoreRow(_ team: String, score: Int, color: Color) -> some View {
        HStack(spacing: 9) {
            Text(predictionTeamInitials(team)).font(.caption2.weight(.heavy)).foregroundStyle(color).frame(width: 23, height: 22)
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
        .padding(16).predictionSurface()
        .accessibilityIdentifier("prediction-game-\(game.id.uuidString)")
    }
    private func choice(_ outcome: PredictionOutcome, team: String, color: Color) -> some View {
        let price = market.price(for: outcome)
        return Button { onBuy(outcome) } label: {
            HStack(spacing: 12) {
                Text(predictionTeamInitials(team)).font(.caption.weight(.heavy)).foregroundStyle(color)
                    .frame(width: 34, height: 34).background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
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
        path.move(to: CGPoint(x: rect.width * 0.1, y: rect.height * 0.2))
        path.addLine(to: CGPoint(x: rect.width * 0.85, y: rect.height * 0.05))
        path.addLine(to: CGPoint(x: rect.width * 0.95, y: rect.height * 0.95))
        path.addLine(to: CGPoint(x: rect.width * 0.15, y: rect.height * 0.75))
        path.closeSubpath()
        path.move(to: CGPoint(x: rect.width * 0.1, y: rect.height * 0.2))
        path.addLine(to: CGPoint(x: rect.width * 0.9, y: rect.height * 0.5))
        path.addLine(to: CGPoint(x: rect.width * 0.15, y: rect.height * 0.75))
        return path
    }
}

private struct PredictionHelmet: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: width * 0.08, y: height * 0.63))
                    path.addCurve(to: CGPoint(x: width * 0.82, y: height * 0.58), control1: CGPoint(x: -width * 0.05, y: -height * 0.2), control2: CGPoint(x: width, y: -height * 0.1))
                    path.addLine(to: CGPoint(x: width * 0.61, y: height * 0.63))
                    path.addLine(to: CGPoint(x: width * 0.56, y: height * 0.91))
                    path.addLine(to: CGPoint(x: width * 0.22, y: height * 0.81))
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [.white, Color(red: 0.67, green: 0.75, blue: 0.88)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Path { path in
                    path.move(to: CGPoint(x: width * 0.42, y: height * 0.06))
                    path.addCurve(to: CGPoint(x: width * 0.47, y: height * 0.83), control1: CGPoint(x: width * 0.77, y: height * 0.06), control2: CGPoint(x: width * 0.7, y: height * 0.51))
                }.stroke(Color(red: 0.09, green: 0.26, blue: 0.49), lineWidth: width * 0.09)
                Path { path in
                    path.move(to: CGPoint(x: width * 0.63, y: height * 0.52))
                    path.addLine(to: CGPoint(x: width * 0.96, y: height * 0.72))
                    path.addLine(to: CGPoint(x: width * 0.82, y: height * 0.98))
                    path.addLine(to: CGPoint(x: width * 0.54, y: height * 0.86))
                    path.move(to: CGPoint(x: width * 0.61, y: height * 0.66))
                    path.addLine(to: CGPoint(x: width * 0.9, y: height * 0.84))
                }.stroke(Color(red: 0.18, green: 0.24, blue: 0.34), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
        }.accessibilityHidden(true)
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
    private var owned: Double { profile.positions.first { $0.marketID == marketID && $0.outcome == outcome }?.shares ?? 0 }

    var body: some View {
        NavigationStack {
            Group {
                if let market, let scene {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Text(market.category).font(.subheadline.weight(.semibold)).foregroundStyle(PredictionColors.blue)
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
    private enum Field: Hashable { case question, category, chance, volume, chart, league, homeTeam, awayTeam, homeScore, awayScore, status }
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
        let value = PredictionGame(id: gameID, marketID: market.id,
            league: gameLeague.trimmingCharacters(in: .whitespacesAndNewlines),
            homeTeam: homeTeam.trimmingCharacters(in: .whitespacesAndNewlines), awayTeam: awayTeam.trimmingCharacters(in: .whitespacesAndNewlines),
            homeScore: firstScore, awayScore: secondScore, status: gameStatus.trimmingCharacters(in: .whitespacesAndNewlines), isLive: liveGame)
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
        case .squads: return "person.2"
        case .search: return "magnifyingglass"
        case .activity: return "clock"
        case .profile: return "person.crop.circle"
        }
    }
}
private enum PredictionSheet: Identifiable {
    case market(UUID), trade(UUID, PredictionOutcome, MarketTradeSide), markets, profile
    var id: String {
        switch self {
        case .market(let id): return "market-\(id)"
        case .trade(let id, let outcome, let side): return "trade-\(id)-\(outcome.rawValue)-\(side.rawValue)"
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
    static let blue = Color(red: 0.18, green: 0.40, blue: 0.92)
    static let green = Color(red: 0.12, green: 0.51, blue: 0.34)
    static let red = Color(red: 0.78, green: 0.22, blue: 0.27)
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
