import SwiftUI

// Native compositions informed by References/Banks/chase-1/3/4/8/9,
// bankOfAmerica-4/7/8, and wellsFargo-4/7/8. These destinations are local
// scene views. Their controls never open banking sites or submit applications.
// Reference posters are research sources, not rendered application backgrounds.

struct BankPlanPage: View {
    @EnvironmentObject private var store: StudioStore
    let sceneID: UUID
    let theme: BankTheme
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Plan & track").font(.system(size: 25, weight: .semibold))
                NavigationLink { BankBudgetPage(sceneID: sceneID).toolbar(.visible, for: .navigationBar) } label: {
                    BankDestinationRow(title: "Budget", subtitle: "My flexible budget", symbol: "chart.pie", color: .bankReferenceBlue)
                }.accessibilityIdentifier("bank.plan.budget")
                NavigationLink { BankSnapshotPage(sceneID: sceneID).toolbar(.visible, for: .navigationBar) } label: {
                    BankDestinationRow(title: "Chase Snapshot℠", subtitle: "Credit & debit card usage · Cash flow", symbol: "chart.bar", color: .bankReferenceBlue)
                }.accessibilityIdentifier("bank.plan.snapshot")
                NavigationLink { BankGoalsPage(sceneID: sceneID, theme: theme).toolbar(.visible, for: .navigationBar) } label: {
                    BankDestinationRow(title: "J.P. Morgan Wealth Plan", subtitle: "Monthly spending · Goals", symbol: "flag", color: .bankReferenceBlue)
                }.accessibilityIdentifier("bank.plan.goals")
            }.padding(20)
        }.background(Color(bankReferenceHex: 0xF3F4F6))
    }
}

private struct BankBudgetPage: View {
    @EnvironmentObject private var store: StudioStore
    let sceneID: UUID
    @State private var dailyPacing = true
    private var scene: StudioScene? { store.scenes.first { $0.id == sceneID } }
    private var spent: Double { store.events.filter { $0.sceneID == sceneID && $0.kind.isOutflow && $0.savingsTransfer != true }.reduce(0) { $0 + $1.amount } }
    var body: some View {
        ScrollView {
            if let scene {
                VStack(spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) { Text("My flexible budget").foregroundStyle(Color.bankReferenceBlue); Text(scene.money(scene.balance)) }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 5) { Text("Available balance"); Text(scene.money(scene.balance)) }
                    }.font(.system(size: 13))
                    VStack(spacing: 24) {
                        Toggle("Flexible budget", isOn: $dailyPacing).tint(Color.bankReferenceBlue)
                            .accessibilityIdentifier("bank.budget.daily-pacing")
                        ZStack {
                            Circle().stroke(Color(bankReferenceHex: 0xE7E7E7), lineWidth: 28)
                            Circle().trim(from: 0, to: min(0.85, spent / max(1, spent + scene.balance))).stroke(Color(bankReferenceHex: 0x3D69B1), style: StrokeStyle(lineWidth: 28, lineCap: .butt)).rotationEffect(.degrees(-90))
                            VStack(spacing: 9) { Text(scene.money(scene.balance)).font(.system(size: 27)); Text("left this month").font(.system(size: 12)) }
                        }.frame(width: 225, height: 225).padding(.vertical, 10)
                        BankValueRow(title: "Spent so far", value: scene.money(spent), color: Color(bankReferenceHex: 0x3D69B1))
                        BankValueRow(title: "Potential savings", value: scene.money(store.bankProfile(for: sceneID).savings), color: Color(bankReferenceHex: 0x91BB31))
                    }.padding(20).bankReferenceSurface()
                    BankValueRow(title: "Monthly income", value: scene.money(store.events.filter { $0.sceneID == sceneID && !$0.kind.isOutflow && $0.savingsTransfer != true }.reduce(0) { $0 + $1.amount }), color: Color(bankReferenceHex: 0x45662A)).padding(18).bankReferenceSurface()
                }.padding(20)
            }
        }.background(Color(bankReferenceHex: 0xF3F4F6)).navigationTitle("Budget").navigationBarTitleDisplayMode(.inline)
    }
}

private struct BankSnapshotPage: View {
    @EnvironmentObject private var store: StudioStore
    let sceneID: UUID
    private var events: [SceneEvent] { store.events.filter { $0.sceneID == sceneID && $0.savingsTransfer != true }.sorted { $0.date < $1.date } }
    var body: some View {
        ScrollView {
            if let scene = store.scenes.first(where: { $0.id == sceneID }) {
                VStack(spacing: 18) {
                    VStack(spacing: 18) {
                        Text("Credit & debit card usage").font(.system(size: 20))
                        Text(scene.money(events.filter { $0.kind.isOutflow }.reduce(0) { $0 + $1.amount })).font(.system(size: 24, weight: .semibold))
                        HStack { Text("Daily").underline(); Spacer(); Text("Weekly"); Spacer(); Text("Monthly") }.font(.system(size: 12)).foregroundStyle(.secondary)
                        BankReferenceLine(values: events.suffix(7).map(\.amount), color: Color(bankReferenceHex: 0xE5B632)).frame(height: 130)
                        Text("Today's card transactions").font(.system(size: 13, weight: .semibold))
                        ForEach(events.filter { $0.kind.isOutflow && Calendar.current.isDateInToday($0.date) }) { event in
                            HStack { Text(event.detail); Spacer(); Text(scene.money(event.amount)) }.font(.system(size: 12))
                        }
                    }.padding(20).bankReferenceSurface()
                    VStack(spacing: 16) {
                        Text("Cash flow").font(.system(size: 20))
                        Text("Checking").font(.system(size: 12)).foregroundStyle(.secondary)
                        Text(scene.money(scene.balance)).font(.system(size: 25, weight: .semibold))
                        HStack { Text("Money in"); Spacer(); Text("Money out") }.font(.system(size: 12))
                    }.padding(20).frame(maxWidth: .infinity).bankReferenceSurface()
                }.padding(18)
            }
        }.background(Color.bankReferenceBlue).navigationTitle("Chase Snapshot℠").navigationBarTitleDisplayMode(.inline)
    }
}

struct BankBenefitsPage: View {
    let sceneID: UUID
    let theme: BankTheme
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Benefits").font(.system(size: 25, weight: .semibold))
                NavigationLink { BankCreditScorePage().toolbar(.visible, for: .navigationBar) } label: {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Credit Journey").font(.system(size: 18, weight: .medium)).foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading).padding(16).background(Color.bankReferenceBlue)
                        BankCreditGauge().frame(height: 140).padding(.horizontal, 20)
                    }.padding(.bottom, 16).bankReferenceSurface()
                }.accessibilityIdentifier("bank.benefits.credit-journey")
                NavigationLink { BankCardPage(sceneID: sceneID, theme: theme).toolbar(.visible, for: .navigationBar) } label: {
                    BankDestinationRow(title: "Manage cards", subtitle: "Lock & unlock your card", symbol: "creditcard", color: .bankReferenceBlue)
                }.accessibilityIdentifier("bank.benefits.cards")
            }.padding(20)
        }.background(Color(bankReferenceHex: 0xF3F4F6))
    }
}

private struct BankCreditScorePage: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                BankCreditGauge().frame(height: 190)
                Text("Credit Journey").font(.system(size: 22, weight: .medium))
                Text("Payment history").font(.system(size: 15)).frame(maxWidth: .infinity, alignment: .leading)
                Divider()
                Text("Credit score").font(.system(size: 15)).frame(maxWidth: .infinity, alignment: .leading)
            }.padding(24)
        }.background(.white).navigationTitle("Credit Journey").navigationBarTitleDisplayMode(.inline)
    }
}

private struct BankCreditGauge: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Circle().trim(from: 0.52, to: 0.98).stroke(AngularGradient(colors: [.red, .orange, .yellow, .green], center: .center, startAngle: .degrees(180), endAngle: .degrees(360)), style: StrokeStyle(lineWidth: 12, lineCap: .round)).rotationEffect(.degrees(0))
            VStack(spacing: 3) { Text("720").font(.system(size: 51, weight: .regular)); Text("GOOD").font(.system(size: 13, weight: .semibold)) }.padding(.bottom, 15)
        }.clipped().foregroundStyle(.black).accessibilityElement(children: .combine)
    }
}

struct BankInvestmentPage: View {
    @EnvironmentObject private var store: StudioStore
    let sceneID: UUID
    let theme: BankTheme
    @State private var section = "Balances"
    private var profile: BankProfile { store.bankProfile(for: sceneID) }
    private var products: [BankProduct] { profile.referenceProducts.filter { $0.kind == .investment } }
    private var totalValue: Double { products.reduce(0) { $0 + $1.balance } }
    var body: some View {
        ScrollView {
            if let scene = store.scenes.first(where: { $0.id == sceneID }) {
                VStack(alignment: .leading, spacing: 20) {
                    if theme == .bankOfAmerica {
                        HStack(spacing: 0) {
                            ForEach(["Holdings", "Balances", "Activity", "Performance"], id: \.self) { title in
                                Button { section = title } label: { Text(title).font(.system(size: 12)).frame(maxWidth: .infinity).padding(.vertical, 14).foregroundStyle(section == title ? Color(bankReferenceHex: 0xE31837) : .secondary).overlay(alignment: .bottom) { if section == title { Rectangle().fill(Color(bankReferenceHex: 0xE31837)).frame(height: 2) } } }
                                    .accessibilityIdentifier("bank.invest.\(title.lowercased())")
                            }
                        }.padding(.horizontal, -18)
                        VStack(spacing: 12) {
                            Text("Provided by Merrill").font(.system(size: 10)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .trailing)
                            Text(products.first?.name ?? "\(profile.holderName ?? scene.name)'s Investment Account").font(.system(size: 20, weight: .semibold))
                            Text("CMA-•••-\(products.first?.suffix ?? profile.accountSuffix)").font(.system(size: 12)).foregroundStyle(.secondary)
                            Text(scene.money(totalValue)).font(.system(size: 35, weight: .semibold))
                        }.frame(maxWidth: .infinity).padding(.vertical, 14)
                        investmentBody(scene)
                    } else {
                        Text(theme == .wellsFargo ? "WellsTrade®" : "Invest with J.P. Morgan").font(.system(size: 24, weight: .medium))
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Total account value").font(.system(size: 14))
                            Text(scene.money(totalValue)).font(.system(size: 33, weight: .regular))
                            BankReferenceLine(values: [0.2, 0.32, 0.3, 0.54, 0.36, 0.58, 0.53, 0.6, 0.79, 0.72, 0.91], color: .bankReferenceBlue).frame(height: 150)
                        }.padding(20).bankReferenceSurface()
                        NavigationLink { BankStockQuotePage().toolbar(.visible, for: .navigationBar) } label: { BankDestinationRow(title: "Elly Inc. (ELLY)", subtitle: "Quote · Position details", symbol: "chart.xyaxis.line", color: .bankReferenceBlue) }
                            .accessibilityIdentifier("bank.invest.quote")
                        ForEach(products) { product in BankProductAccountTile(sceneID: sceneID, theme: theme, product: product, style: .america) }
                    }
                }.padding(18)
            }
        }.background(Color(bankReferenceHex: 0xF6F6F6))
    }
    @ViewBuilder private func investmentBody(_ scene: StudioScene) -> some View {
        if section == "Activity" {
            VStack(alignment: .leading, spacing: 12) {
                Text("Activity").font(.system(size: 17, weight: .semibold))
                Text("No transactions").font(.system(size: 14)).foregroundStyle(.secondary)
            }.padding(16).bankReferenceSurface()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text(section == "Holdings" ? "Holdings" : "Balance Details").font(.system(size: 16, weight: .semibold)).padding(.bottom, 14)
                BankValueRow(title: "Total Account Value", value: scene.money(totalValue), color: .bankReferenceBlue)
                ForEach(products) { product in
                    Divider().padding(.vertical, 12)
                    BankProductAccountTile(sceneID: sceneID, theme: theme, product: product, style: .america)
                }
            }.padding(16).bankReferenceSurface()
            VStack(alignment: .leading, spacing: 8) {
                Text("HISTORICAL TOTAL VALUE").font(.system(size: 11)).foregroundStyle(.secondary)
                BankReferenceLine(values: [0.35, 0.4, 0.31, 0.45, 0.44, 0.43, 0.5, 0.62, 0.59, 0.52], color: .bankReferenceBlue).frame(height: 140)
            }.padding(16).bankReferenceSurface()
        }
    }
}

private struct BankStockQuotePage: View {
    @State private var range = "1Y"
    @State private var watching = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack { Text("Quote").foregroundStyle(Color.bankReferenceBlue).underline(); Spacer(); Text("Position details").foregroundStyle(.secondary) }.font(.system(size: 13))
                Text("Elly Inc.     ELLY").font(.system(size: 16, weight: .semibold))
                HStack(alignment: .firstTextBaseline) { Text("80.58").font(.system(size: 38, weight: .semibold)); Text("+1.03 (1.28%)").font(.system(size: 17)).foregroundStyle(Color(bankReferenceHex: 0x168067)) }
                HStack { ForEach(["1D", "5D", "1M", "3M", "1Y", "3Y", "Max"], id: \.self) { value in Button(value) { range = value }.font(.system(size: 12)).foregroundStyle(range == value ? Color.bankReferenceBlue : .secondary).frame(maxWidth: .infinity) } }
                BankReferenceLine(values: [0.4, 0.46, 0.39, 0.41, 0.2, 0.1, 0.2, 0.24, 0.24, 0.35, 0.8, 0.67, 0.78, 0.93], color: .bankReferenceBlue).frame(height: 200)
                Button(watching ? "Watching" : "Watch") { watching.toggle() }.font(.system(size: 15)).frame(maxWidth: .infinity).padding(.vertical, 12).overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.gray, lineWidth: 1)).accessibilityIdentifier("bank.invest.watch")
                Text("Overview").font(.system(size: 20, weight: .medium))
                Text("Elly Inc.").font(.system(size: 14)).foregroundStyle(.secondary)
            }.padding(20)
        }.background(.white).navigationTitle("Elly Inc. (ELLY)").navigationBarTitleDisplayMode(.inline)
    }
}

struct BankDealsPage: View {
    let sceneID: UUID
    let theme: BankTheme
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(theme == .bankOfAmerica ? "BankAmeriDeals®" : "Offers").font(.system(size: 25, weight: .semibold))
                if theme == .bankOfAmerica {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Image(systemName: "tag"); Text("BankAmeriDeals®"); Spacer(); Text("$5.00") }.font(.system(size: 17))
                        Text("12 available deals").font(.system(size: 13)).foregroundStyle(.secondary)
                    }.padding(20).bankReferenceSurface()
                    NavigationLink { BankRewardsPage(sceneID: sceneID).toolbar(.visible, for: .navigationBar) } label: { BankDestinationRow(title: "My Rewards", subtitle: "Benefits, rewards and deals", symbol: "gift", color: .bankReferenceBlue) }
                        .accessibilityIdentifier("bank.deals.rewards")
                } else if theme == .wellsFargo {
                    NavigationLink { BankCreditCardProductsPage().toolbar(.visible, for: .navigationBar) } label: {
                        BankDestinationRow(title: "Active Cash®", subtitle: "$200 cash rewards bonus", symbol: "creditcard", color: Color(bankReferenceHex: 0xD71E28))
                    }.accessibilityIdentifier("bank.offers.active-cash")
                }
            }.padding(20)
        }.background(Color(bankReferenceHex: 0xF3F3F3)).navigationTitle(theme == .bankOfAmerica ? "BankAmeriDeals®" : "Offers").navigationBarTitleDisplayMode(.inline)
    }
}

struct BankRewardsPage: View {
    @EnvironmentObject private var store: StudioStore
    let sceneID: UUID
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("My Rewards").font(.system(size: 16)).frame(maxWidth: .infinity).padding(.vertical, 16).background(.white)
                VStack(spacing: 8) {
                    Text("Hi \(store.bankProfile(for: sceneID).holderName ?? "Jamie")").font(.system(size: 11)).foregroundStyle(.secondary)
                    Text("Preferred Rewards").font(.system(size: 15, weight: .semibold))
                    Text("Platinum tier member").font(.system(size: 13))
                    Text("$361.00").font(.system(size: 32, weight: .semibold)).padding(.top, 10)
                    Text("Total rewards value in 2023  ⓘ").font(.system(size: 11)).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).padding(24).bankReferenceSurface().padding(16)
                VStack(spacing: 0) {
                    rewardRow("Preferred Rewards", subtitle: "Explore all your benefits", value: "$56.00", symbol: "star.square")
                    Divider()
                    rewardRow("Credit Cards", subtitle: "$339.03 cash & 1,502 points to view/redeem", value: "$300.00", symbol: "creditcard")
                    Divider()
                    NavigationLink { BankDealsPage(sceneID: sceneID, theme: .bankOfAmerica).toolbar(.visible, for: .navigationBar) } label: {
                        BankDestinationRow(title: "BankAmeriDeals®", subtitle: "12 available deals", symbol: "tag", color: .gray, value: "$5.00")
                    }.accessibilityIdentifier("bank.rewards.deals")
                    Divider()
                    rewardRow("Partner Rewards", subtitle: "Manage or add new partners", value: "", symbol: "heart")
                }.background(.white)
            }
        }.background(Color(bankReferenceHex: 0xF1F1F1)).navigationTitle("My Rewards").navigationBarTitleDisplayMode(.inline)
    }
    private func rewardRow(_ title: String, subtitle: String, value: String, symbol: String) -> some View {
        NavigationLink { BankRewardDetail(title: title, subtitle: subtitle, value: value).toolbar(.visible, for: .navigationBar) } label: { BankDestinationRow(title: title, subtitle: subtitle, symbol: symbol, color: .gray, value: value) }
    }
}

private struct BankRewardDetail: View {
    let title: String
    let subtitle: String
    let value: String
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 18) { Text(title).font(.system(size: 25, weight: .semibold)); if !value.isEmpty { Text(value).font(.system(size: 33, weight: .semibold)) }; Text(subtitle).font(.system(size: 15)).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(24) }.background(.white).navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}

struct BankExplorePage: View {
    let sceneID: UUID
    let theme: BankTheme
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 4)
    private let banking = ["Checking", "Savings & CDs", "Credit cards", "Mortgages", "Loans", "Business", "Investing", "Offers"]
    private let services = ["LifeSync®", "Make an appointment", "My Tracker", "Security Center", "Tax Center", "Relief Center"]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack { Image(systemName: "magnifyingglass"); Text("Need help?"); Spacer(); Image(systemName: "bubble.left.and.bubble.right.fill").foregroundStyle(Color(bankReferenceHex: 0x663B85)) }.font(.system(size: 12)).padding(10).background(.white, in: Capsule())
                Text("Explore Wells Fargo").font(.system(size: 23, weight: .regular))
                VStack(alignment: .leading, spacing: 18) {
                    Text("Banking & Investing").font(.system(size: 17))
                    LazyVGrid(columns: columns, spacing: 8) { ForEach(banking, id: \.self) { product in productLink(product) } }
                    Text("Services").font(.system(size: 17)).padding(.top, 3)
                    LazyVGrid(columns: columns, spacing: 8) { ForEach(services, id: \.self) { product in productLink(product) } }
                }.padding(16).bankReferenceSurface(radius: 20)
            }.padding(.horizontal, 16).padding(.vertical, 18)
        }.background(Color(bankReferenceHex: 0xF5F2EE))
    }
    private func productLink(_ product: String) -> some View {
        NavigationLink { productDestination(product).toolbar(.visible, for: .navigationBar) } label: {
            VStack(spacing: 7) {
                Text(product).font(.system(size: 9)).multilineTextAlignment(.center).frame(height: 26)
                BankProductArtwork(product: product).frame(height: 40)
            }.foregroundStyle(.black).frame(maxWidth: .infinity).padding(.horizontal, 3).padding(.vertical, 9).background(product == "Offers" ? Color(bankReferenceHex: 0xF0E6FF) : .white, in: RoundedRectangle(cornerRadius: 10)).shadow(color: .black.opacity(0.08), radius: 5, y: 3)
        }.accessibilityIdentifier("bank.explore.\(product.lowercased().replacingOccurrences(of: " ", with: "-"))")
    }
    @ViewBuilder private func productDestination(_ product: String) -> some View {
        switch product {
        case "Checking": BankAccountDetail(sceneID: sceneID, theme: theme, savings: false)
        case "Savings & CDs": BankAccountDetail(sceneID: sceneID, theme: theme, savings: true)
        case "Credit cards": BankCreditCardProductsPage()
        case "Investing": BankInvestmentPage(sceneID: sceneID, theme: theme).navigationTitle("WellsTrade®")
        case "Offers": BankDealsPage(sceneID: sceneID, theme: theme)
        case "LifeSync®": BankGoalsPage(sceneID: sceneID, theme: theme)
        case "My Tracker": BankSpendingPage(sceneID: sceneID, theme: theme).navigationTitle("My Tracker")
        case "Security Center": BankServicesPage(sceneID: sceneID, theme: theme, title: "Security Center")
        default: BankProductInformationPage(product: product)
        }
    }
}

private struct BankProductInformationPage: View {
    let product: String
    @State private var selection = "Overview"
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(product).font(.system(size: 25, weight: .regular))
                BankProductArtwork(product: product).frame(maxWidth: .infinity).frame(height: 130).padding(25).bankReferenceSurface()
                Picker(product, selection: $selection) { Text("Overview").tag("Overview"); Text("Details").tag("Details") }.pickerStyle(.segmented)
                Text(selection == "Overview" ? product : "\(product) details").font(.system(size: 20, weight: .medium))
            }.padding(22)
        }.background(Color(bankReferenceHex: 0xF5F2EE)).navigationTitle(product).navigationBarTitleDisplayMode(.inline)
    }
}

private struct BankCreditCardProductsPage: View {
    @State private var category = "Cash back"
    private let categories = [("Cash back", "banknote"), ("Rewards", "star"), ("Low intro rate", "percent"), ("Travel", "airplane")]
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("Find the card that fits your life").font(.system(size: 20, weight: .regular))
                HStack(alignment: .top) { ForEach(categories, id: \.0) { item in Button { category = item.0 } label: { VStack(spacing: 8) { Image(systemName: item.1).font(.system(size: 24)); Text(item.0).font(.system(size: 11)).multilineTextAlignment(.center) }.foregroundStyle(category == item.0 ? Color(bankReferenceHex: 0xBE1E2D) : .gray).frame(maxWidth: .infinity) } } }
                VStack(spacing: 17) {
                    BankWellsActiveCashCard().frame(width: 155, height: 94)
                    Text("Active Cash®").font(.system(size: 14)).foregroundStyle(.secondary)
                    Text("Earn unlimited 2% cash rewards on purchases").font(.system(size: 20, weight: .semibold)).multilineTextAlignment(.center)
                    Text("Intro offer  $200 cash rewards bonus when you spend $500 in purchases within the first 3 months").font(.system(size: 13)).multilineTextAlignment(.center)
                    Divider()
                    HStack { Text("Rewards"); Spacer(); Text("2% cash rewards on purchases") }.font(.system(size: 12))
                    Divider()
                    HStack { Text("Annual fee"); Spacer(); Text("$0") }.font(.system(size: 12))
                    NavigationLink { BankProductInformationPage(product: "Active Cash® card").toolbar(.visible, for: .navigationBar) } label: { Text("Learn more").font(.system(size: 14)).padding(.horizontal, 28).padding(.vertical, 10).overlay(Capsule().stroke(.gray, lineWidth: 1)) }.accessibilityIdentifier("bank.products.active-cash.learn-more")
                }.padding(24).bankReferenceSurface(radius: 10)
            }.padding(22)
        }.background(Color(bankReferenceHex: 0xBE920B)).navigationTitle("Credit cards").navigationBarTitleDisplayMode(.inline)
    }
}

private struct BankWellsActiveCashCard: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(colors: [Color(bankReferenceHex: 0x868483), Color(bankReferenceHex: 0x353434)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Path { path in path.move(to: CGPoint(x: 0, y: proxy.size.height)); path.addLine(to: CGPoint(x: proxy.size.width, y: 5)); path.addLine(to: CGPoint(x: proxy.size.width, y: 16)); path.addLine(to: CGPoint(x: 0, y: proxy.size.height)); }.fill(Color(bankReferenceHex: 0xC8A85D))
                VStack(alignment: .leading) { HStack { Text("WELLS FARGO").font(.system(size: 7, weight: .bold, design: .serif)); Spacer(); Text("ACTIVE\nCASH").font(.system(size: 7)).multilineTextAlignment(.trailing) }; RoundedRectangle(cornerRadius: 2).fill(Color(bankReferenceHex: 0xDDD7C8)).frame(width: 17, height: 13).padding(.top, 5); Spacer(); Text("VISA").font(.system(size: 13, weight: .bold)).italic().frame(maxWidth: .infinity, alignment: .trailing) }.foregroundStyle(.white).padding(10)
            }.clipShape(RoundedRectangle(cornerRadius: 6))
        }.accessibilityLabel("Wells Fargo Active Cash Visa card")
    }
}

struct BankGoalsPage: View {
    @EnvironmentObject private var store: StudioStore
    let sceneID: UUID
    let theme: BankTheme
    var body: some View {
        ScrollView {
            if let scene = store.scenes.first(where: { $0.id == sceneID }) {
                VStack(alignment: .leading, spacing: 20) {
                    Text(theme == .wellsFargo ? "LifeSync" : "J.P. Morgan Wealth Plan").font(.system(size: 24, weight: .medium))
                    HStack { Text(theme == .wellsFargo ? "Goals" : "Monthly spending").fontWeight(.semibold); Spacer(); Text(theme == .wellsFargo ? "Snapshot" : "Net worth history"); if theme == .wellsFargo { Spacer(); Text("Newsfeed") } }.font(.system(size: 12))
                    if theme == .wellsFargo {
                        VStack(alignment: .leading, spacing: 15) {
                            Text("My dream vacation").font(.system(size: 16, weight: .medium))
                            Image(systemName: "sailboat.fill").font(.system(size: 85)).foregroundStyle(Color(bankReferenceHex: 0x809CA7)).frame(maxWidth: .infinity).frame(height: 150).background(Color(bankReferenceHex: 0xDCE7EB), in: RoundedRectangle(cornerRadius: 5))
                            Text(scene.money(50_000)).font(.system(size: 32))
                            Text("What you have: \(scene.money(store.bankProfile(for: sceneID).savings))").font(.system(size: 14))
                            ProgressView(value: min(1, store.bankProfile(for: sceneID).savings / 50_000)).tint(Color(bankReferenceHex: 0x86A954))
                            NavigationLink { BankSavingsTransferPage(sceneID: sceneID, theme: theme).toolbar(.visible, for: .navigationBar) } label: { Text("Add money").font(.system(size: 14, weight: .semibold)) }.accessibilityIdentifier("bank.goals.add-money")
                        }.padding(20).bankReferenceSurface()
                    } else {
                        let spending = store.events.filter { $0.sceneID == sceneID && $0.kind.isOutflow && $0.savingsTransfer != true }.reduce(0) { $0 + $1.amount }
                        Text(scene.money(spending)).font(.system(size: 33, weight: .semibold))
                        Text("Your spending this month").font(.system(size: 12))
                        BankReferenceLine(values: [0.1, 0.18, 0.25, 0.29, 0.47, 0.49, 0.7, 0.81, 0.84, 0.99], color: .bankReferenceBlue).frame(height: 190)
                        VStack(alignment: .leading, spacing: 16) { Text("Goals").font(.system(size: 22, weight: .medium)); Text("Long-term goals with J.P. Morgan").font(.system(size: 14)); HStack { Label("My Retirement", systemImage: "building.columns"); Spacer(); Text("Looks good") }.font(.system(size: 13)) }.padding(20).bankReferenceSurface()
                    }
                }.padding(22)
            }
        }.background(Color(bankReferenceHex: 0xF5F6F6)).navigationTitle(theme == .wellsFargo ? "LifeSync" : "J.P. Morgan Wealth Plan").navigationBarTitleDisplayMode(.inline)
    }
}

private struct BankProductArtwork: View {
    let product: String
    private var symbol: String {
        switch product {
        case "Checking": return "banknote.fill"
        case "Savings & CDs": return "tray.full.fill"
        case "Credit cards": return "creditcard.fill"
        case "Mortgages": return "house.fill"
        case "Loans": return "dollarsign.circle.fill"
        case "Business": return "storefront.fill"
        case "Investing": return "chart.bar.xaxis"
        case "Offers": return "gift.fill"
        case "LifeSync®": return "circle.hexagongrid.fill"
        case "Make an appointment": return "calendar"
        case "My Tracker": return "magnifyingglass"
        case "Security Center": return "checkmark.shield.fill"
        case "Tax Center": return "calculator.fill"
        default: return "sun.max.fill"
        }
    }
    private var color: Color {
        switch product {
        case "Credit cards", "Mortgages": return Color(bankReferenceHex: 0xE44E52)
        case "Checking", "Business", "Investing", "Offers", "My Tracker", "Tax Center": return Color(bankReferenceHex: 0xA678D8)
        case "Security Center": return Color(bankReferenceHex: 0x88D5B2)
        default: return Color(bankReferenceHex: 0xF1AC38)
        }
    }
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.18)).frame(width: 38, height: 13).offset(x: 4, y: 14)
            Image(systemName: symbol).font(.system(size: 32, weight: .regular)).foregroundStyle(color).shadow(color: color.opacity(0.25), radius: 1, x: 3, y: 3)
        }.accessibilityHidden(true)
    }
}

private struct BankDestinationRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color
    var value = ""
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 22)).foregroundStyle(color).frame(width: 28)
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.system(size: 16)); Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary) }
            Spacer(minLength: 5)
            if !value.isEmpty { Text(value).font(.system(size: 15)).foregroundStyle(.secondary) }
            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(.secondary)
        }.foregroundStyle(.black).padding(16).bankReferenceSurface()
    }
}

private struct BankValueRow: View {
    let title: String
    let value: String
    let color: Color
    var body: some View { HStack { Text(title); Spacer(minLength: 8); Text(value).foregroundStyle(color).multilineTextAlignment(.trailing) }.font(.system(size: 14)) }
}

private struct BankReferenceLine: View {
    let values: [Double]
    let color: Color
    var body: some View {
        GeometryReader { proxy in
            let data = values.count > 1 ? values : [0, 0]
            let low = data.min() ?? 0
            let spread = max(1, (data.max() ?? 1) - low)
            Path { path in
                for (index, value) in data.enumerated() {
                    let point = CGPoint(x: CGFloat(index) / CGFloat(data.count - 1) * proxy.size.width, y: proxy.size.height - CGFloat((value - low) / spread) * proxy.size.height)
                    if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
            }.stroke(color, lineWidth: 1.8)
            VStack { Spacer(); Rectangle().fill(Color.gray.opacity(0.25)).frame(height: 1) }
        }.accessibilityLabel("Account value chart")
    }
}

enum BankProductTileStyle { case america, citi, capitalOne }

struct BankProductAccountTile: View {
    @EnvironmentObject private var store: StudioStore
    let sceneID: UUID
    let theme: BankTheme
    let product: BankProduct
    let style: BankProductTileStyle
    private var money: String { store.scenes.first(where: { $0.id == sceneID })?.money(product.balance) ?? product.balance.formatted(.currency(code: "USD")) }
    var body: some View {
        NavigationLink { BankProductDetailPage(sceneID: sceneID, theme: theme, productID: product.id).toolbar(.visible, for: .navigationBar) } label: {
            Group {
                switch style {
                case .america:
                    VStack(alignment: .leading, spacing: 13) {
                        Text(product.kind == .investment ? "Merrill" : "Bank of America  ▰").font(.system(size: 11, weight: .semibold))
                        HStack { Text(product.name).font(.system(size: 12)); Spacer(minLength: 6); Text(money).font(.system(size: 15, weight: .semibold)); Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(.secondary) }
                    }.foregroundStyle(.black).padding(16)
                case .citi:
                    VStack(alignment: .leading, spacing: 11) {
                        HStack(alignment: .top) {
                            Label("Credit Card", systemImage: "creditcard").font(.system(size: 11))
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) { Text(money).font(.system(size: 20, weight: .medium)); Text(product.balanceLabel.capitalized).font(.system(size: 10)) }
                        }
                        Text("\(product.name) ·\(product.suffix)").font(.system(size: 11))
                    }.padding(14).foregroundStyle(.white).background {
                        ZStack { LinearGradient(colors: product.name.contains("Diamond") ? [Color(bankReferenceHex: 0x414647), Color(bankReferenceHex: 0x101516)] : [Color(bankReferenceHex: 0x073A61), Color(bankReferenceHex: 0x005885)], startPoint: .topLeading, endPoint: .bottomTrailing); BankCardLinePattern().stroke(.white.opacity(0.08), lineWidth: 0.5) }.clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                case .capitalOne:
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(product.name) ·\(product.suffix)").font(.system(size: 14, weight: .medium)).tracking(1)
                        Text(money).font(.system(size: 36, weight: .light))
                        Text(product.balanceLabel.uppercased()).font(.system(size: 10)).tracking(0.5)
                    }.padding(22).frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(.white).background {
                        ZStack { product.name.uppercased().contains("SAVOR") ? Color(bankReferenceHex: 0xAD663E) : Color(bankReferenceHex: 0x727476); BankCardLinePattern().stroke(.white.opacity(0.14), lineWidth: 0.7) }.clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                }
            }.lineLimit(2).minimumScaleFactor(0.75)
        }.accessibilityIdentifier("bank.product.\(product.id.uuidString)")
    }
}

struct BankProductDetailPage: View {
    @EnvironmentObject private var store: StudioStore
    let sceneID: UUID
    let theme: BankTheme
    let productID: UUID
    @State private var editing = false
    private var products: [BankProduct] { store.bankProfile(for: sceneID).referenceProducts }
    private var product: BankProduct? { products.first { $0.id == productID } }
    var body: some View {
        Group {
            if let product, let scene = store.scenes.first(where: { $0.id == sceneID }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if product.kind == .creditCard {
                            BankReferencePlasticCard(theme: theme, holderName: store.bankProfile(for: sceneID).holderName ?? scene.name, suffix: product.suffix, frozen: product.cardFrozen, name: product.name).frame(height: 210)
                        }
                        Text(product.name).font(.system(size: 22, weight: .semibold))
                        Text("••••\(product.suffix)").font(.system(size: 13)).foregroundStyle(.secondary)
                        Text(scene.money(product.balance)).font(.system(size: 33, weight: .regular))
                        Text(product.balanceLabel.capitalized).font(.system(size: 13)).foregroundStyle(.secondary)
                        if let minimum = product.minimumPayment { BankValueRow(title: "Minimum Payment Due", value: scene.money(minimum), color: .bankReferenceBlue).padding(16).bankReferenceSurface() }
                        if let due = product.paymentDue { BankValueRow(title: "Payment Due", value: due, color: .bankReferenceBlue).padding(16).bankReferenceSurface() }
                        if let rewards = product.rewards {
                            BankValueRow(title: "Total Rewards Balance Earned", value: product.rewardsUnit == "points" ? rewards.formatted(.number.precision(.fractionLength(0))) + " points" : scene.money(rewards), color: .bankReferenceBlue).padding(16).bankReferenceSurface()
                        }
                        if product.kind == .creditCard {
                            Toggle(product.cardFrozen ? "Card locked" : "Card unlocked", isOn: Binding(get: { product.cardFrozen }, set: { frozen in
                                var updated = products
                                guard let index = updated.firstIndex(where: { $0.id == productID }) else { return }
                                updated[index].cardFrozen = frozen
                                _ = store.updateBankProducts(sceneID: sceneID, products: updated)
                            })).tint(Color.bankReferenceBlue).padding(18).bankReferenceSurface().accessibilityIdentifier("bank.product.freeze")
                        }
                        if let error = store.error { Text(error).font(.footnote).foregroundStyle(.red) }
                    }.padding(22)
                }.background(Color(bankReferenceHex: 0xF3F4F6)).navigationTitle(product.name).navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { editing = true }.accessibilityIdentifier("bank.product.edit") } }
                    .sheet(isPresented: $editing) { BankProductEditor(sceneID: sceneID, productID: productID) }
            } else { ContentUnavailableView("Account unavailable", systemImage: "creditcard") }
        }
    }
}

private struct BankProductEditor: View {
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    let sceneID: UUID
    let productID: UUID
    @State private var name = ""
    @State private var suffix = ""
    @State private var balance = ""
    @State private var balanceLabel = ""
    @State private var minimum = ""
    @State private var due = ""
    @State private var rewards = ""
    @State private var rewardsUnit = "cash"
    private var products: [BankProduct] { store.bankProfile(for: sceneID).referenceProducts }
    private var product: BankProduct? { products.first { $0.id == productID } }
    private var updated: BankProduct? {
        guard var value = product, let parsed = Simulation.parseAmount(balance) else { return nil }
        let minimumValue = minimum.isEmpty ? nil : Simulation.parseAmount(minimum)
        let rewardValue = rewards.isEmpty ? nil : Simulation.parseAmount(rewards)
        guard (minimum.isEmpty || minimumValue != nil) && (rewards.isEmpty || rewardValue != nil) else { return nil }
        value.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        value.suffix = suffix
        value.balance = parsed
        value.balanceLabel = balanceLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        value.minimumPayment = minimumValue
        value.paymentDue = due.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : due.trimmingCharacters(in: .whitespacesAndNewlines)
        value.rewards = rewardValue
        value.rewardsUnit = rewardValue == nil ? nil : rewardsUnit
        return value.isValid ? value : nil
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("Product name", text: $name).accessibilityIdentifier("bank.product.editor.name")
                    TextField("Account ending (4 digits)", text: $suffix).keyboardType(.numberPad)
                    TextField("Balance", text: $balance).keyboardType(.decimalPad).accessibilityIdentifier("bank.product.editor.balance")
                    TextField("Balance label", text: $balanceLabel)
                }
                if product?.kind == .creditCard {
                    Section("Payment and rewards") {
                        TextField("Minimum payment (optional)", text: $minimum).keyboardType(.decimalPad)
                        TextField("Payment due (optional)", text: $due)
                        TextField("Rewards (optional)", text: $rewards).keyboardType(.decimalPad)
                        Picker("Reward unit", selection: $rewardsUnit) { Text("Cash").tag("cash"); Text("Points").tag("points") }
                    }
                }
                if let error = store.error { Section { Text(error).font(.footnote).foregroundStyle(.red) } }
            }.navigationTitle("Account details").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") {
                        guard let updated, let index = products.firstIndex(where: { $0.id == productID }) else { return }
                        var values = products; values[index] = updated
                        if store.updateBankProducts(sceneID: sceneID, products: values) { dismiss() }
                    }.disabled(updated == nil).accessibilityIdentifier("bank.product.editor.save") }
                }
                .onAppear {
                    guard let product else { return }
                    name = product.name; suffix = product.suffix; balance = product.balance.formatted(.number.grouping(.never)); balanceLabel = product.balanceLabel
                    minimum = product.minimumPayment?.formatted(.number.grouping(.never)) ?? ""; due = product.paymentDue ?? ""; rewards = product.rewards?.formatted(.number.grouping(.never)) ?? ""; rewardsUnit = product.rewardsUnit ?? "cash"
                }
        }.preferredColorScheme(.light)
    }
}

struct BankProductsPage: View {
    let sceneID: UUID
    let theme: BankTheme
    @State private var search = ""
    private var groups: [(String, [String])] {
        if theme == .barclays { return [("Borrow", ["Loans", "Credit cards", "Overdrafts", "Mortgages"]), ("Everyday banking", ["Current accounts", "Switch current account"]), ("Insurance", ["Life insurance", "Travel insurance"])] }
        if theme == .citi { return [("Your Banking Options", ["Banking Overview", "Savings", "Checking", "Certificate of Deposit", "Banking IRAs", "Small Business Banking"])] }
        return [("Banking", ["Checking", "Savings"]), ("Credit Cards", ["Credit cards"]), ("Investing", ["Investment accounts"])]
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(theme == .citi ? "Banking" : "Products").font(.system(size: 26, weight: .bold))
                HStack { Image(systemName: "magnifyingglass"); TextField(theme == .barclays ? "Search or ask a question" : "Search products", text: $search) }.font(.system(size: 13)).padding(12).background(.white, in: RoundedRectangle(cornerRadius: 4))
                if theme == .citi { Text("Explore All Products & Offers  ❯").font(.system(size: 15, weight: .medium)).foregroundStyle(Color.bankReferenceBlue).frame(maxWidth: .infinity).padding(15).overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.bankReferenceBlue, lineWidth: 1)) }
                ForEach(groups, id: \.0) { group in
                    let titles = group.1.filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) }
                    if !titles.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(group.0).font(.system(size: 14, weight: .semibold)).padding(16)
                            ForEach(titles, id: \.self) { title in
                                NavigationLink { destination(title).toolbar(.visible, for: .navigationBar) } label: { HStack { Image(systemName: productIcon(title)).frame(width: 23); Text(title); Spacer(); Image(systemName: "chevron.right") }.font(.system(size: 13)).padding(16).foregroundStyle(theme == .citi ? .white : .black) }
                                if title != titles.last { Divider().padding(.leading, 16) }
                            }
                        }.background(theme == .citi ? Color(bankReferenceHex: 0x102C4B) : .white, in: RoundedRectangle(cornerRadius: 7)).foregroundStyle(theme == .citi ? .white : .black)
                    }
                }
            }.padding(18)
        }.background(Color(bankReferenceHex: 0xF3F4F5))
    }
    @ViewBuilder private func destination(_ title: String) -> some View {
        switch title {
        case "Checking", "Current accounts", "Banking Overview": BankAccountDetail(sceneID: sceneID, theme: theme, savings: false)
        case "Savings": BankAccountDetail(sceneID: sceneID, theme: theme, savings: true)
        case "Investment accounts": BankInvestmentPage(sceneID: sceneID, theme: theme).navigationTitle("Invest")
        default: BankProductInformationPage(product: title)
        }
    }
    private func productIcon(_ title: String) -> String { title.lowercased().contains("card") ? "creditcard" : title.lowercased().contains("insurance") ? "shield" : title.lowercased().contains("mortgage") ? "house" : "building.columns" }
}

struct BankQuickLockPage: View {
    @EnvironmentObject private var store: StudioStore
    let sceneID: UUID
    let theme: BankTheme
    private var products: [BankProduct] { store.bankProfile(for: sceneID).referenceProducts }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Citi® Quick Lock").font(.system(size: 21, weight: .semibold)).frame(maxWidth: .infinity).foregroundStyle(.white).padding(17).background(Color.bankReferenceBlue).padding(.horizontal, -20)
                Text("Temporarily lock and unlock your card").font(.system(size: 15)).foregroundStyle(.secondary)
                ForEach(products.filter { $0.kind == .creditCard }) { product in
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 25) {
                            BankReferencePlasticCard(theme: theme, holderName: "", suffix: product.suffix, frozen: product.cardFrozen, name: product.name).frame(width: 136, height: 86)
                            VStack(spacing: 8) {
                                Text(product.cardFrozen ? "Tap to unlock" : "Tap to lock").font(.system(size: 12)).foregroundStyle(.secondary)
                                Toggle(product.cardFrozen ? "Locked" : "Active", isOn: Binding(get: { product.cardFrozen }, set: { frozen in update(product.id, frozen: frozen) })).font(.system(size: 12)).tint(product.cardFrozen ? Color(bankReferenceHex: 0xED7277) : Color(bankReferenceHex: 0x91C995)).accessibilityIdentifier("bank.product.freeze.\(product.id.uuidString)")
                            }
                        }
                        NavigationLink { BankProductDetailPage(sceneID: sceneID, theme: theme, productID: product.id).toolbar(.visible, for: .navigationBar) } label: { Text("\(product.name) ·\(product.suffix)").font(.system(size: 13)).foregroundStyle(.secondary) }
                        Divider()
                    }
                }
                Text("Instantly block new card purchases and ATM withdrawals. Unlock your card when you're ready to use it again.").font(.system(size: 13)).foregroundStyle(.secondary)
            }.padding(.horizontal, 20).padding(.bottom, 24)
        }.background(.white)
    }
    private func update(_ id: UUID, frozen: Bool) {
        var updated = products
        guard let index = updated.firstIndex(where: { $0.id == id }) else { return }
        updated[index].cardFrozen = frozen
        _ = store.updateBankProducts(sceneID: sceneID, products: updated)
    }
}

struct BankProductCardCatalogPage: View {
    @EnvironmentObject private var store: StudioStore
    let sceneID: UUID
    let theme: BankTheme
    @State private var pendingLock: UUID?
    private var products: [BankProduct] { store.bankProfile(for: sceneID).referenceProducts }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Cards").font(.system(size: 26, weight: .semibold))
                ForEach(products.filter { $0.kind == .creditCard }) { product in
                    VStack(alignment: .leading, spacing: 14) {
                        NavigationLink { BankProductDetailPage(sceneID: sceneID, theme: theme, productID: product.id).toolbar(.visible, for: .navigationBar) } label: { BankReferencePlasticCard(theme: theme, holderName: store.bankProfile(for: sceneID).holderName ?? "", suffix: product.suffix, frozen: product.cardFrozen, name: product.name).frame(height: 208) }
                        HStack { Text("\(product.name) ·\(product.suffix)").font(.system(size: 15, weight: .medium)); Spacer(); Button(product.cardFrozen ? "Unlock this Card" : "Lock this Card") { if product.cardFrozen { update(product.id, frozen: false) } else { pendingLock = product.id } }.font(.system(size: 13)).accessibilityIdentifier("bank.product.freeze.\(product.id.uuidString)") }
                    }.padding(16).bankReferenceSurface()
                }
            }.padding(20)
        }.background(Color(bankReferenceHex: 0xF3F4F5)).confirmationDialog("Lock this Card", isPresented: Binding(get: { pendingLock != nil }, set: { if !$0 { pendingLock = nil } }), titleVisibility: .visible) {
            Button("Yes, Lock This Card") { if let id = pendingLock { update(id, frozen: true) }; pendingLock = nil }
            Button("Cancel", role: .cancel) { pendingLock = nil }
        }
    }
    private func update(_ id: UUID, frozen: Bool) {
        var updated = products
        guard let index = updated.firstIndex(where: { $0.id == id }) else { return }
        updated[index].cardFrozen = frozen
        _ = store.updateBankProducts(sceneID: sceneID, products: updated)
    }
}

struct BankHelpPage: View {
    let sceneID: UUID
    let theme: BankTheme
    @State private var search = ""
    private let groups = [("Quick links", ["Manage your cards", "Statements and documents", "Disputed payments", "Report fraud"]), ("Our services", ["Need additional support?", "Money worries", "My appointments"])]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Help").font(.system(size: 26, weight: .bold))
                HStack { Image(systemName: "magnifyingglass"); TextField("Search or ask a question", text: $search) }.font(.system(size: 13)).padding(12).background(.white).overlay(Rectangle().stroke(.gray, lineWidth: 0.7))
                ForEach(groups, id: \.0) { group in
                    Text(group.0).font(.system(size: 14, weight: .medium))
                    VStack(spacing: 0) {
                        ForEach(group.1.filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) }, id: \.self) { title in
                            NavigationLink { helpDestination(title).toolbar(.visible, for: .navigationBar) } label: { HStack { Image(systemName: title.contains("cards") ? "creditcard" : title.contains("Statements") ? "doc.text" : "info.circle").foregroundStyle(Color.bankReferenceBlue); Text(title); Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary) }.foregroundStyle(.black).font(.system(size: 13)).padding(16) }
                            if title != group.1.last { Divider().padding(.horizontal, 16) }
                        }
                    }.bankReferenceSurface(radius: 4)
                }
            }.padding(18)
        }.background(Color(bankReferenceHex: 0xF3F4F5))
    }
    @ViewBuilder private func helpDestination(_ title: String) -> some View {
        switch title {
        case "Manage your cards": BankCardPage(sceneID: sceneID, theme: theme)
        case "Statements and documents": BankStatementPage(sceneID: sceneID, theme: theme)
        default: BankProductInformationPage(product: title)
        }
    }
}

struct BankServicesPage: View {
    let sceneID: UUID
    let theme: BankTheme
    var title = "Services"
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(title).font(.system(size: 26, weight: .semibold))
                NavigationLink { BankCardPage(sceneID: sceneID, theme: theme).toolbar(.visible, for: .navigationBar) } label: { BankDestinationRow(title: theme == .citi ? "Citi® Quick Lock" : "Manage your cards", subtitle: "Temporarily lock and unlock your card", symbol: "lock", color: .bankReferenceBlue) }
                NavigationLink { BankPaymentPage(sceneID: sceneID, theme: theme, initiallyIncoming: true).toolbar(.visible, for: .navigationBar) } label: { BankDestinationRow(title: "Mobile check deposit", subtitle: "Deposit to your account", symbol: "camera", color: .bankReferenceBlue) }
                NavigationLink { BankStatementPage(sceneID: sceneID, theme: theme).toolbar(.visible, for: .navigationBar) } label: { BankDestinationRow(title: "Statements and documents", subtitle: "Account statements", symbol: "doc.text", color: .bankReferenceBlue) }
                NavigationLink { BankHelpPage(sceneID: sceneID, theme: theme).toolbar(.visible, for: .navigationBar) } label: { BankDestinationRow(title: "Help", subtitle: "Your account services", symbol: "questionmark.circle", color: .bankReferenceBlue) }
            }.padding(20)
        }.background(Color(bankReferenceHex: 0xF3F4F5)).navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}

struct BankSpendingPage: View {
    @EnvironmentObject private var store: StudioStore
    let sceneID: UUID
    let theme: BankTheme
    private var events: [SceneEvent] { store.events.filter { $0.sceneID == sceneID && $0.savingsTransfer != true }.sorted { $0.date > $1.date } }
    var body: some View {
        ScrollView {
            if let scene = store.scenes.first(where: { $0.id == sceneID }) {
                VStack(alignment: .leading, spacing: 20) {
                    Text(theme == .monzo ? "Trends" : "Spending").font(.system(size: 26, weight: .semibold))
                    Text(Date.now.formatted(.dateTime.month(.wide))).font(.system(size: 16)).foregroundStyle(.secondary)
                    Text(scene.money(events.filter { $0.kind.isOutflow }.reduce(0) { $0 + $1.amount })).font(.system(size: 34, weight: .semibold))
                    Text("Total spent").font(.system(size: 13)).foregroundStyle(.secondary)
                    BankReferenceLine(values: events.reversed().filter { $0.kind.isOutflow }.map(\.amount), color: theme == .monzo ? Color(bankReferenceHex: 0x007D8A) : .bankReferenceBlue).frame(height: 180)
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Spending activity").font(.system(size: 18, weight: .semibold))
                        if events.filter({ $0.kind.isOutflow }).isEmpty { Text("No payments yet").font(.system(size: 14)).foregroundStyle(.secondary) }
                        ForEach(events.filter { $0.kind.isOutflow }) { event in HStack { Image(systemName: "arrow.up.right").foregroundStyle(Color.bankReferenceBlue); Text(event.detail); Spacer(); Text(scene.money(event.amount)) }.font(.system(size: 14)); Divider() }
                    }.padding(18).bankReferenceSurface()
                }.padding(22)
            }
        }.background(Color(bankReferenceHex: 0xF3F4F5))
    }
}

struct BankReferencePlasticCard: View {
    let theme: BankTheme
    let holderName: String
    let suffix: String
    let frozen: Bool
    var name = ""
    private var colors: [Color] {
        switch theme {
        case .starling: return [Color(bankReferenceHex: 0xF995F6), Color(bankReferenceHex: 0xF995F6)]
        case .monzo: return [Color(bankReferenceHex: 0xFF4C43), Color(bankReferenceHex: 0xFF4C43)]
        case .barclays: return [Color(bankReferenceHex: 0x03AFE3), Color(bankReferenceHex: 0x03AFE3)]
        case .capitalOne: return name.uppercased().contains("SAVOR") ? [Color(bankReferenceHex: 0xB37C4E), Color(bankReferenceHex: 0x8F542D)] : [Color(bankReferenceHex: 0xCACED0), Color(bankReferenceHex: 0x898F94)]
        case .citi: return name.contains("Diamond") ? [Color(bankReferenceHex: 0x424647), Color(bankReferenceHex: 0x171B1D)] : [Color(bankReferenceHex: 0x2588BE), Color(bankReferenceHex: 0x003D76)]
        default: return [Color(bankReferenceHex: 0x22557A), Color(bankReferenceHex: 0x113451)]
        }
    }
    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            if theme == .capitalOne || theme == .citi { BankCardLinePattern().stroke(.white.opacity(0.2), lineWidth: 0.7) }
            if theme == .barclays {
                VStack { Spacer(); BankBarclaysSymbol().fill(.white).frame(width: 37, height: 45); Spacer(); Text("VISA").font(.system(size: 12, weight: .bold)).italic().frame(maxWidth: .infinity, alignment: .trailing) }.padding(16)
            } else if theme == .capitalOne {
                VStack(alignment: .leading, spacing: 15) {
                    Text("Capital One").font(.system(size: 17, weight: .bold)).italic().frame(maxWidth: .infinity, alignment: .trailing)
                    Text(name.isEmpty ? "QUICKSILVER" : name).font(.system(size: 25, weight: .light)).tracking(2)
                    HStack { Spacer(); RoundedRectangle(cornerRadius: 4).fill(Color(bankReferenceHex: 0xD5D5CF)).frame(width: 37, height: 28) }
                    Spacer(minLength: 5)
                    Text(holderName.uppercased()).font(.system(size: 11))
                }.padding(22).foregroundStyle(.white)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    HStack { Text(theme == .starling ? "STARLING" : theme == .monzo ? "monzo" : theme == .citi ? "citi" : theme == .capitalOne ? "Capital One" : theme.name).font(.system(size: theme == .starling ? 25 : 22, weight: .bold)); Spacer(); if theme == .starling { Text("Virtual ●").font(.system(size: 11)) } else { Image(systemName: "wave.3.right").font(.system(size: 19)) } }
                    if theme != .starling { RoundedRectangle(cornerRadius: 4).fill(Color(bankReferenceHex: 0xDED9C8)).frame(width: 34, height: 25) }
                    Spacer(minLength: 5)
                    if theme != .starling { Text("•••• •••• •••• \(suffix)").font(.system(size: 18, weight: .medium, design: .monospaced)) }
                    HStack { if theme != .starling { Text(holderName.uppercased()).font(.system(size: 10)) }; Spacer(); if theme == .starling { Text("world\ndebit").font(.system(size: 9)) }; if theme == .starling || theme == .monzo || theme == .citi || theme == .capitalOne { BankMastercardMark().frame(width: 48, height: 29) } else { Text("VISA").font(.system(size: 23, weight: .bold)).italic() } }
                }.padding(22).foregroundStyle(theme == .starling || theme == .capitalOne ? Color(bankReferenceHex: 0x4B2450) : .white)
            }
        }.clipShape(RoundedRectangle(cornerRadius: theme == .barclays ? 5 : 13)).opacity(frozen ? 0.65 : 1).accessibilityLabel("\(theme.name) card ending \(suffix), \(frozen ? "locked" : "active")")
    }
}

struct BankSpacesPage: View {
    @EnvironmentObject private var store: StudioStore
    let sceneID: UUID
    @State private var section = "Spending"
    private var profile: BankProfile { store.bankProfile(for: sceneID) }
    var body: some View {
        ScrollView {
            if let scene = store.scenes.first(where: { $0.id == sceneID }) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack { Text("Spaces").font(.system(size: 26, weight: .bold)); Spacer(); NavigationLink { BankSpaceDetailPage(sceneID: sceneID, title: "Monthly Bills", groceries: false).toolbar(.visible, for: .navigationBar) } label: { Text("Manage").font(.system(size: 14, weight: .semibold)) } }
                    Picker("Spaces", selection: $section) { Text("Spending").tag("Spending"); Text("Saving").tag("Saving") }.pickerStyle(.segmented)
                    HStack(spacing: 14) { Image(systemName: "square.grid.2x2").font(.system(size: 26)).foregroundStyle(Color(bankReferenceHex: 0x007D9B)); VStack(alignment: .leading, spacing: 5) { Text("Total in \(section)").font(.system(size: 13)).foregroundStyle(.secondary); Text(scene.money(profile.savings)).font(.system(size: 19, weight: .semibold)) }; Spacer() }.padding(18).bankReferenceSurface()
                    Text("Regular Spaces [\(scene.money(profile.savings))]").font(.system(size: 13)).foregroundStyle(.secondary)
                    NavigationLink { BankSpaceDetailPage(sceneID: sceneID, title: "The Big Shop", groceries: true).toolbar(.visible, for: .navigationBar) } label: {
                        HStack(spacing: 0) { BankReferenceGroceries().frame(width: 108, height: 126); VStack(alignment: .leading, spacing: 16) { Text("The Big Shop").font(.system(size: 18, weight: .semibold)); Spacer(minLength: 5); HStack { Text(scene.money(min(50, profile.savings))).font(.system(size: 22, weight: .semibold)); Spacer(); Text("75%").font(.system(size: 12)).foregroundStyle(.secondary) }; ProgressView(value: 0.75).tint(Color(bankReferenceHex: 0x53DDCC)) }.padding(14) }.foregroundStyle(.black).bankReferenceSurface(radius: 8).clipShape(RoundedRectangle(cornerRadius: 8))
                    }.accessibilityIdentifier("bank.spaces.groceries")
                    NavigationLink { BankSpaceDetailPage(sceneID: sceneID, title: "Monthly Bills", groceries: false).toolbar(.visible, for: .navigationBar) } label: {
                        HStack(spacing: 0) { BankReferenceCottage().frame(width: 100, height: 112); VStack(alignment: .leading, spacing: 25) { Text("Monthly Bills").font(.system(size: 15, weight: .semibold)); Text(scene.money(max(0, profile.savings - min(50, profile.savings)))).font(.system(size: 22, weight: .semibold)) }.padding(14); Spacer() }.foregroundStyle(.black).bankReferenceSurface(radius: 8).clipShape(RoundedRectangle(cornerRadius: 8))
                    }.accessibilityIdentifier("bank.spaces.bills")
                }.padding(20)
            }
        }.background(Color(bankReferenceHex: 0xF7F8F8))
    }
}

private struct BankSpaceDetailPage: View {
    @EnvironmentObject private var store: StudioStore
    let sceneID: UUID
    let title: String
    let groceries: Bool
    var body: some View {
        ScrollView {
            if let scene = store.scenes.first(where: { $0.id == sceneID }) {
                VStack(alignment: .leading, spacing: 20) {
                    ZStack(alignment: .bottomLeading) {
                        Group { if groceries { BankReferenceGroceries() } else { BankReferenceCottage(hero: true) } }.frame(height: 210)
                        LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                        VStack(alignment: .leading, spacing: 6) { Text(title).font(.system(size: 25, weight: .bold)); Text("Space").font(.system(size: 15)) }.foregroundStyle(.white).padding(18)
                    }.clipped().padding(.horizontal, -20)
                    HStack { Text(scene.money(store.bankProfile(for: sceneID).savings)).font(.system(size: 24, weight: .semibold)); Spacer(); NavigationLink { BankSavingsTransferPage(sceneID: sceneID, theme: .starling).toolbar(.visible, for: .navigationBar) } label: { Text("Manage Space").font(.system(size: 14, weight: .semibold)) } }
                    Text("Activity").font(.system(size: 16)).foregroundStyle(.secondary)
                    ForEach(store.events.filter { $0.sceneID == sceneID && $0.savingsTransfer == true }.sorted { $0.date > $1.date }) { event in HStack { Image(systemName: "arrow.left.arrow.right").foregroundStyle(Color.bankReferenceBlue); Text(event.detail); Spacer(); Text(scene.money(event.amount)) }.font(.system(size: 14)).padding(16).bankReferenceSurface() }
                }.padding(20)
            }
        }.background(Color(bankReferenceHex: 0xF7F8F8)).navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}

struct BankMonzoSavingsPage: View {
    @EnvironmentObject private var store: StudioStore
    let sceneID: UUID
    var body: some View {
        ScrollView {
            if let scene = store.scenes.first(where: { $0.id == sceneID }) {
                let savings = store.bankProfile(for: sceneID).savings
                VStack(spacing: 20) {
                    VStack(spacing: 0) { BankReferenceHoliday().frame(width: 100, height: 79); Text("Holiday Fund").font(.system(size: 12, weight: .medium)).foregroundStyle(.white).frame(width: 100).padding(.vertical, 6).background(Color(bankReferenceHex: 0xBC7937)) }.clipShape(RoundedRectangle(cornerRadius: 15)).padding(.top, 20)
                    Text(scene.money(savings)).font(.system(size: 29, weight: .semibold))
                    HStack(spacing: 10) {
                        NavigationLink { BankSavingsTransferPage(sceneID: sceneID, theme: .monzo, initiallyToSavings: false).toolbar(.visible, for: .navigationBar) } label: { Label("Withdraw", systemImage: "minus.circle.fill") }
                        NavigationLink { BankSavingsTransferPage(sceneID: sceneID, theme: .monzo).toolbar(.visible, for: .navigationBar) } label: { Label("Add money", systemImage: "plus.circle.fill") }
                    }.font(.system(size: 12, weight: .semibold)).buttonStyle(.bordered).buttonBorderShape(.capsule).tint(Color(bankReferenceHex: 0x008EAD))
                    VStack(alignment: .leading, spacing: 20) { Text("Savings goal · \(Int(min(1, savings / 5_000) * 100))% of \(scene.money(5_000))").font(.system(size: 13, weight: .semibold)); ProgressView(value: min(1, savings / 5_000)).tint(Color(bankReferenceHex: 0x00B96B)) }.padding(18).frame(maxWidth: .infinity, alignment: .leading).bankReferenceSurface(radius: 13)
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Activity").font(.system(size: 15, weight: .semibold))
                        ForEach(store.events.filter { $0.sceneID == sceneID && $0.savingsTransfer == true }.sorted { $0.date > $1.date }) { event in HStack { Image(systemName: "person.fill").foregroundStyle(.white).padding(7).background(Color(bankReferenceHex: 0xFF4C43), in: RoundedRectangle(cornerRadius: 5)); Text("Personal account"); Spacer(); Text(scene.money(event.amount)).foregroundStyle(event.kind.isOutflow ? Color(bankReferenceHex: 0x00A763) : .black) }.font(.system(size: 14)) }
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading).bankReferenceSurface(radius: 13)
                }.padding(20)
            }
        }.background(Color(bankReferenceHex: 0xF0F7F3)).navigationTitle("Savings").navigationBarTitleDisplayMode(.inline)
    }
}

struct BankRevolutAccountsPage: View {
    @EnvironmentObject private var store: StudioStore
    let sceneID: UUID
    var body: some View {
        ScrollView {
            if let scene = store.scenes.first(where: { $0.id == sceneID }) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Accounts").font(.system(size: 27, weight: .bold)).foregroundStyle(.white)
                    ForEach(BankReferenceRevolutPhoto.allCases, id: \.self) { photo in
                        NavigationLink { BankRevolutAccountDetailPage(sceneID: sceneID, photo: photo).toolbar(.visible, for: .navigationBar) } label: {
                            ZStack(alignment: .bottomLeading) { BankReferenceRevolutArtwork(photo: photo).frame(height: 150); LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom); VStack(alignment: .leading, spacing: 8) { Text(photo.title).font(.system(size: 16, weight: .medium)); Text(scene.money(photo == .savings ? store.bankProfile(for: sceneID).savings : scene.balance)).font(.system(size: 28, weight: .semibold)) }.foregroundStyle(.white).padding(18) }.clipShape(RoundedRectangle(cornerRadius: 15))
                        }.accessibilityIdentifier("bank.accounts.\(photo.rawValue)")
                    }
                }.padding(20)
            }
        }.background(Color(bankReferenceHex: 0x080D15)).navigationTitle("Accounts").navigationBarTitleDisplayMode(.inline)
    }
}

private struct BankRevolutAccountDetailPage: View {
    @EnvironmentObject private var store: StudioStore
    let sceneID: UUID
    let photo: BankReferenceRevolutPhoto
    var body: some View {
        ScrollView {
            if let scene = store.scenes.first(where: { $0.id == sceneID }) {
                VStack(spacing: 20) {
                    ZStack { BankReferenceRevolutArtwork(photo: photo).frame(height: 235); Color.black.opacity(0.35); VStack(spacing: 14) { Text(photo.title).font(.system(size: 17, weight: .medium)); Text(scene.money(photo == .savings ? store.bankProfile(for: sceneID).savings : scene.balance)).font(.system(size: 42, weight: .bold)) }.foregroundStyle(.white) }.clipShape(RoundedRectangle(cornerRadius: 18))
                    HStack(spacing: 16) {
                        NavigationLink { BankPaymentPage(sceneID: sceneID, theme: .revolut, initiallyIncoming: true).toolbar(.visible, for: .navigationBar) } label: { Label("Add money", systemImage: "plus") }
                        NavigationLink { BankSavingsTransferPage(sceneID: sceneID, theme: .revolut).toolbar(.visible, for: .navigationBar) } label: { Label("Move", systemImage: "arrow.left.arrow.right") }
                    }.font(.system(size: 14, weight: .medium)).buttonStyle(.bordered).buttonBorderShape(.capsule).tint(.white)
                    VStack(alignment: .leading, spacing: 15) { Text("Transactions").font(.system(size: 18, weight: .semibold)); ForEach(store.events.filter { $0.sceneID == sceneID && (photo != .savings || $0.savingsTransfer == true) }.sorted { $0.date > $1.date }) { event in HStack { Text(event.detail); Spacer(); Text(scene.money(event.amount)) }.font(.system(size: 14)); Divider() } }.foregroundStyle(.white).padding(18).frame(maxWidth: .infinity, alignment: .leading).background(Color(bankReferenceHex: 0x24262A), in: RoundedRectangle(cornerRadius: 15))
                }.padding(20)
            }
        }.background(Color(bankReferenceHex: 0x080D15)).navigationTitle(photo.title).navigationBarTitleDisplayMode(.inline)
    }
}

private struct BankMastercardMark: View {
    var body: some View { HStack(spacing: -10) { Circle().fill(Color(bankReferenceHex: 0xEA1639)); Circle().fill(Color(bankReferenceHex: 0xFFAA18).opacity(0.92)) }.accessibilityLabel("Mastercard") }
}

private struct BankCardLinePattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for index in 0..<24 { let radius = CGFloat(index + 1) * rect.width / 26; path.addEllipse(in: CGRect(x: rect.width * 0.86 - radius, y: rect.height * 0.7 - radius * 0.65, width: radius * 2, height: radius * 1.3)) }
        return path
    }
}

private extension View {
    func bankReferenceSurface(radius: CGFloat = 8) -> some View { background(.white, in: RoundedRectangle(cornerRadius: radius)) }
}

private extension Color {
    static var bankReferenceBlue: Color { Color(bankReferenceHex: 0x0069AA) }
    init(bankReferenceHex: UInt32) { self.init(red: Double((bankReferenceHex >> 16) & 255) / 255, green: Double((bankReferenceHex >> 8) & 255) / 255, blue: Double(bankReferenceHex & 255) / 255) }
}
