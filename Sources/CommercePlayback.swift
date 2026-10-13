import SwiftUI
import Charts

/// An immersive local storefront scene. Values and order changes come from the saved session.
struct CommercePlayback: View {
    let sceneID: UUID
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("cleanPlayback") private var cleanPlayback = false
    @State private var tab: CommerceTab = .home
    @State private var metric: CommerceMetric = .sales
    @State private var range: CommerceRange = .twoWeeks
    @State private var filter: CommerceOrderFilter = .all
    @State private var query = ""
    @State private var descending = true
    @State private var storeLocationOnly = false
    @State private var sheet: CommerceSheet?

    private var scene: StudioScene? { store.scenes.first { $0.id == sceneID } }
    private var profile: CommerceProfile { store.commerceProfile(for: sceneID) }
    private var orders: [CommerceOrder] { store.commerceOrders(for: sceneID) }
    private var alerts: [QueuedAlert] { store.queuedAlerts.filter { $0.sceneID == sceneID } }
    private var filteredOrders: [CommerceOrder] {
        orders.filter { order in
            filter.includes(order) && (query.isEmpty || "\(order.number) \(order.customer)".localizedCaseInsensitiveContains(query))
        }.sorted { descending ? $0.date > $1.date : $0.date < $1.date }
    }
    private var filteredProducts: [CommerceProduct] {
        profile.products.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let scene {
                    VStack(spacing: 0) {
                        header(scene)
                        Group {
                            switch tab {
                            case .home: home(scene)
                            case .orders: orderList(scene)
                            case .products: productList(scene)
                            case .menu: menu(scene)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .background(Color.black)
                    .safeAreaInset(edge: .bottom, spacing: 0) { bottomNavigation }
                } else {
                    ContentUnavailableView("Store unavailable", systemImage: "bag", description: Text("This scene is no longer in your session."))
                        .overlay(alignment: .topTrailing) {
                            Button("Close") { dismiss() }.padding()
                        }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .preferredColorScheme(.dark)
            .sheet(item: $sheet) { destination in
                if let scene {
                    destinationView(destination, scene: scene).preferredColorScheme(.light)
                }
            }
            .task { await store.refreshNotifications() }
            .alert("Unable to update store", isPresented: Binding(get: { store.error != nil && sheet?.id == nil }, set: { if !$0 { store.error = nil } })) {
                Button("OK") { store.error = nil }
            } message: { Text(store.error ?? "") }
            .onChange(of: tab) { _, _ in query = "" }
            .onChange(of: scene?.kind) { _, kind in if kind != .commerce { dismiss() } }
        }
        .accessibilityIdentifier("commerce-playback")
    }

    private func header(_ scene: StudioScene) -> some View {
        HStack(spacing: 12) {
            if tab == .home {
                Menu {
                    Button("Edit store") { sheet = .store }
                    Button("Edit analytics") { sheet = .analytics }
                    Picker("Date range", selection: $range) {
                        ForEach(CommerceRange.allCases) { Text($0.title).tag($0) }
                    }
                    Button("Close scene") { dismiss() }
                } label: {
                    Image(systemName: "person.fill")
                        .font(.system(size: 20, weight: .medium))
                        .frame(width: 36, height: 36)
                        .background(Color(red: 0.71, green: 0.24, blue: 0.78), in: Circle())
                }
                .frame(width: 44, height: 44)
                .accessibilityLabel("Store profile and close scene")
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    Text(String(scene.name.prefix(2)))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 27, height: 27)
                        .background(Color(red: 0.7, green: 0.85, blue: 0.93), in: RoundedRectangle(cornerRadius: 7))
                        .accessibilityHidden(true)
                    Text(scene.name).font(.system(size: 18, weight: .semibold)).lineLimit(1)
                }
                Spacer(minLength: 8)
                Button { sheet = .alerts } label: {
                    Image(systemName: "bell")
                        .font(.system(size: 22))
                        .overlay(alignment: .topTrailing) {
                            if !alerts.isEmpty {
                                Text(alerts.count.formatted())
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(Color.red, in: Capsule())
                                    .offset(x: 8, y: -6)
                            }
                        }
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Notifications, \(alerts.count) queued")
            } else {
                Text(tab.title).font(.system(size: 25, weight: .bold))
                if tab == .orders { Image(systemName: "chevron.down").font(.system(size: 14, weight: .semibold)).accessibilityHidden(true) }
                Spacer()
                if tab == .orders || tab == .products {
                    Button { sheet = tab == .orders ? .newOrder : .product(nil) } label: {
                        Image(systemName: "plus.circle").font(.system(size: 23)).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(tab == .orders ? "Add order" : "Add product")
                }
                Menu {
                    Button("Edit store") { sheet = .store }
                    Button("Edit analytics") { sheet = .analytics }
                    Picker("Date range", selection: $range) {
                        ForEach(CommerceRange.allCases) { Text($0.title).tag($0) }
                    }
                    Button("Close scene") { dismiss() }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 24)).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Store actions and close scene")
            }
            if !cleanPlayback {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .semibold)).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Close scene")
                .accessibilityIdentifier("close-scene")
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14).padding(.vertical, 4)
        .background(Color.black)
    }

    private func home(_ scene: StudioScene) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                analytics(scene)
                VStack(alignment: .leading, spacing: 18) {
                    Text(greeting).font(.system(size: 21, weight: .medium)).foregroundStyle(Color(red: 0.30, green: 0.30, blue: 0.30)).fixedSize(horizontal: false, vertical: true)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            activityCard(title: "Payouts in \(profile.payoutDays) days", value: scene.money(profile.payoutAmount), symbol: "gauge.with.dots.needle.33percent") { sheet = .payout }
                            activityCard(title: "Fulfill orders", value: unfulfilledCount.formatted(), symbol: "tray") { filter = .unfulfilled; tab = .orders }
                            activityCard(title: "Products in stock", value: profile.products.filter { $0.inventory > 0 }.count.formatted(), symbol: "tag") { tab = .products }
                        }
                        .padding(.vertical, 3)
                    }
                    pulseCard
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your store at a glance").font(.system(size: 18, weight: .semibold))
                        glanceRow("Orders", value: scene.orders.formatted(), symbol: "tray") { tab = .orders }
                        glanceRow("Products", value: profile.products.count.formatted(), symbol: "tag") { tab = .products }
                        glanceRow("Available balance", value: scene.money(scene.balance), symbol: "banknote") { sheet = .payout }
                    }
                    .padding(16)
                    .background(.white, in: RoundedRectangle(cornerRadius: 24))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.black.opacity(0.07)))
                }
                .foregroundStyle(Color.black)
                .padding(16).padding(.top, 8).padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white, in: UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
            }
        }
        .background(Color.black)
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("commerce-home")
    }

    private func analytics(_ scene: StudioScene) -> some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Button { metric = .live } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Live").font(.system(size: 13)).foregroundStyle(.white.opacity(0.68))
                            HStack(spacing: 5) {
                                CommerceLiveMark().foregroundStyle(CommerceColors.green).frame(width: 15, height: 15)
                                Text(profile.liveVisitors.formatted()).font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .padding(.vertical, 8).padding(.horizontal, 6)
                        .background(metric == .live ? Color.white.opacity(0.13) : .clear, in: RoundedRectangle(cornerRadius: 13))
                    }
                    .accessibilityLabel("Live visitors, \(profile.liveVisitors)")
                    metricButton(.sales, title: "Total sales", value: scene.sales.formatted(.currency(code: scene.currency).precision(.fractionLength(0))), change: profile.salesChange)
                    metricButton(.orders, title: "Orders", value: scene.orders.formatted(), change: profile.ordersChange)
                    metricButton(.conversion, title: "Conversion rate", value: profile.conversionRate.formatted(.number.precision(.fractionLength(1))) + "%", change: nil)
                }
                .padding(.horizontal, 14)
            }
            CommerceAnalyticsChart(values: profile.chart, metric: metric, range: range, scene: scene, profile: profile)
                .frame(height: 160)
                .padding(.horizontal, 14)
                .accessibilityLabel("\(metric.title) chart for \(range.title)")
                .contextMenu {
                    Picker("Date range", selection: $range) {
                        ForEach(CommerceRange.allCases) { Text($0.title).tag($0) }
                    }
                }
        }
        .foregroundStyle(.white)
        .padding(.top, 9).padding(.bottom, 8)
        .background(.black)
    }

    private func metricButton(_ choice: CommerceMetric, title: String, value: String, change: Double?) -> some View {
        Button { metric = choice } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13)).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(value).font(.system(size: 19, weight: .semibold)).lineLimit(1)
                    if let change {
                        Text((change >= 0 ? "+" : "") + change.formatted(.number.precision(.fractionLength(0))) + "%")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(change >= 0 ? CommerceColors.green : Color.red)
                    }
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(metric == choice ? Color.white.opacity(0.13) : .clear, in: RoundedRectangle(cornerRadius: 13))
        }
        .accessibilityAddTraits(metric == choice ? [.isSelected] : [])
    }

    private var pulseCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                ZStack {
                    Circle().fill(.white.opacity(0.16)).frame(width: 23, height: 23)
                    Circle().fill(.white.opacity(0.24)).frame(width: 17, height: 17)
                    Circle().fill(.white).frame(width: 8, height: 8)
                }
                .frame(width: 23, height: 23)
                .accessibilityHidden(true)
                Text("Sidekick Pulse").font(.system(size: 19, weight: .medium))
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(18)
            VStack(alignment: .leading, spacing: 14) {
                Text(unfulfilledCount > 0 ? "Keep orders moving" : "Keep your bestsellers in stock")
                    .font(.system(size: 18, weight: .semibold))
                Text(unfulfilledCount > 0
                     ? "You have \(unfulfilledCount) orders awaiting fulfillment. Review your latest orders to keep customers up to date."
                     : "\(profile.products.filter { $0.inventory < 10 }.count) products have fewer than 10 items available. Review inventory to plan your next restock.")
                    .font(.system(size: 16)).foregroundStyle(CommerceColors.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    if case .pulse? = sheet { sheet = nil }
                    if unfulfilledCount > 0 { filter = .unfulfilled; tab = .orders } else { tab = .products }
                } label: {
                    Text(unfulfilledCount > 0 ? "Review unfulfilled orders" : "Review product inventory")
                        .font(.system(size: 15, weight: .semibold)).padding(.horizontal, 14).padding(.vertical, 10)
                        .background(.white, in: Capsule())
                        .overlay(Capsule().stroke(Color.black.opacity(0.08)))
                }
            }
            .padding(17).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 24))
        }
        .background(LinearGradient(colors: [Color(red: 0.55, green: 0.26, blue: 0.99), Color(red: 0.4, green: 0.28, blue: 0.95), Color(red: 0.43, green: 0.27, blue: 0.96)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.black.opacity(0.05)))
        .shadow(color: .black.opacity(0.04), radius: 5, y: 3)
    }

    private func activityCard(title: String, value: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                Text(title).font(.system(size: 12)).foregroundStyle(CommerceColors.secondary).lineLimit(1)
                HStack {
                    Text(value).font(.system(size: 16, weight: .semibold)).lineLimit(1)
                    Spacer(minLength: 8)
                    if symbol == "gauge.with.dots.needle.33percent" {
                        CommercePayoutMark().stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                            .frame(width: 20, height: 20).foregroundStyle(CommerceColors.secondary)
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: symbol).font(.system(size: 17)).foregroundStyle(CommerceColors.secondary)
                    }
                }
            }
            .padding(15).frame(width: 170, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.black.opacity(0.065)))
            .shadow(color: .black.opacity(0.035), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func glanceRow(_ title: String, value: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: symbol).frame(width: 22).foregroundStyle(CommerceColors.secondary)
                Text(title).font(.system(size: 14))
                Spacer()
                Text(value).font(.system(size: 14, weight: .medium))
                Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(CommerceColors.secondary)
            }
            .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func orderList(_ scene: StudioScene) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                searchField("Search orders")
                Menu {
                    Picker("Order location", selection: $storeLocationOnly) {
                        Text("All locations").tag(false)
                        Text(scene.name).tag(true)
                    }
                } label: {
                    Image(systemName: "mappin.and.ellipse").font(.system(size: 18)).frame(width: 44, height: 44)
                        .background(CommerceColors.fill, in: Circle())
                }
                .accessibilityLabel(storeLocationOnly ? "Order location, \(scene.name)" : "Order location, all locations")
                Button { descending.toggle() } label: {
                    Image(systemName: "arrow.up.arrow.down").font(.system(size: 18)).frame(width: 44, height: 44)
                        .background(CommerceColors.fill, in: Circle())
                }
                .accessibilityLabel(descending ? "Sort oldest first" : "Sort newest first")
                Menu {
                    Picker("Order status", selection: $filter) {
                        ForEach(CommerceOrderFilter.allCases) { Text($0.title).tag($0) }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease").font(.system(size: 18)).frame(width: 44, height: 44)
                        .background(CommerceColors.fill, in: Circle())
                }
                .accessibilityLabel("Filter orders")
            }
            .padding(.horizontal, 16).padding(.top, 17).padding(.bottom, 10)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    ForEach(CommerceOrderFilter.allCases) { choice in
                        Button { filter = choice } label: {
                            Text(choice.title).font(.system(size: 14, weight: filter == choice ? .semibold : .regular))
                                .padding(.horizontal, 14).frame(minHeight: 40)
                                .background(filter == choice ? CommerceColors.fill : .clear, in: Capsule())
                        }
                        .accessibilityAddTraits(filter == choice ? [.isSelected] : [])
                    }
                }
                .padding(.horizontal, 13)
            }
            if filteredOrders.isEmpty {
                ContentUnavailableView(query.isEmpty ? "No \(filter == .all ? "orders" : filter.title.lowercased() + " orders")" : "No matching orders", systemImage: "tray", description: Text(query.isEmpty ? "Add an order using the plus button." : "Try a customer name or order number."))
                    .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(orderDays, id: \.self) { day in
                        Text(day.formatted(.dateTime.month(.wide).day()))
                            .font(.system(size: 13)).foregroundStyle(CommerceColors.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 17).padding(.vertical, 9)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(CommerceColors.fill)
                        ForEach(orders(on: day)) { order in
                            Button { sheet = .order(order.id) } label: { CommerceOrderRow(order: order, scene: scene) }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 14, leading: 17, bottom: 14, trailing: 17))
                                .listRowBackground(Color.white)
                                .swipeActions(edge: .trailing) {
                                    Button(order.fulfillment == .fulfilled ? "Unfulfill" : "Fulfill") {
                                        store.setOrderStatus(orderID: order.id, sceneID: sceneID, status: order.fulfillment == .fulfilled ? .unfulfilled : .fulfilled)
                                    }
                                    .tint(CommerceColors.green)
                                    Button("Archive") { store.setOrderStatus(orderID: order.id, sceneID: sceneID, status: .archived) }.tint(.gray)
                                }
                        }
                    }
                }
                .listStyle(.plain).scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, 0)
            }
        }
        .foregroundStyle(Color.black)
        .background(Color.white, in: UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
        .environment(\.colorScheme, .light)
        .accessibilityIdentifier("commerce-orders")
    }

    private func productList(_ scene: StudioScene) -> some View {
        VStack(spacing: 0) {
            searchField("Search products").padding(16)
            if filteredProducts.isEmpty {
                ContentUnavailableView("No products", systemImage: "tag", description: Text(query.isEmpty ? "Add your first product using the plus button." : "Try a different product title."))
                    .frame(maxHeight: .infinity)
            } else {
                List(filteredProducts) { product in
                    Button { sheet = .product(product.id) } label: {
                        HStack(spacing: 13) {
                            Image(systemName: product.symbol).font(.system(size: 27)).foregroundStyle(CommerceColors.secondary)
                                .frame(width: 62, height: 66)
                                .background(CommerceColors.fill, in: RoundedRectangle(cornerRadius: 12))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(product.title).font(.system(size: 16, weight: .semibold))
                                Text(scene.money(product.price)).font(.system(size: 14)).foregroundStyle(CommerceColors.secondary)
                                Text(product.inventory > 0 ? "\(product.inventory) in stock" : "Out of stock")
                                    .font(.system(size: 12)).foregroundStyle(product.inventory > 0 ? CommerceColors.secondary : .red)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(CommerceColors.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.white)
                }
                .listStyle(.plain).scrollContentBackground(.hidden)
            }
        }
        .foregroundStyle(Color.black)
        .background(Color.white, in: UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
        .environment(\.colorScheme, .light)
        .accessibilityIdentifier("commerce-products")
    }

    private func menu(_ scene: StudioScene) -> some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Text(String(scene.name.prefix(2))).font(.headline)
                        .frame(width: 44, height: 44).background(CommerceColors.fill, in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(scene.name).font(.headline)
                        Text(scene.currency).font(.caption).foregroundStyle(CommerceColors.secondary)
                    }
                }
            }
            Section {
                Button { sheet = .store } label: { Label("Store settings", systemImage: "gearshape") }
                Button { sheet = .analytics } label: { Label("Analytics", systemImage: "chart.xyaxis.line") }
                Button { sheet = .payout } label: { Label("Finances", systemImage: "banknote") }
                Button { sheet = .alerts } label: { Label("Notifications", systemImage: "bell") }
                Button { sheet = .pulse } label: { Label("Sidekick Pulse", systemImage: "sparkles") }
            }
            Section {
                Button { dismiss() } label: { Label("Close scene", systemImage: "xmark.circle") }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("close-commerce-playback")
            }
        }
        .listStyle(.insetGrouped)
        .foregroundStyle(Color.black)
        .environment(\.colorScheme, .light)
        .background(Color.white)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
    }

    private var bottomNavigation: some View {
        HStack(spacing: 9) {
            Button { sheet = .search } label: {
                Image(systemName: "magnifyingglass").font(.system(size: 22)).frame(width: 48, height: 48)
                    .background(.white, in: Circle())
                    .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
            }
            .accessibilityLabel("Search store")
            HStack(spacing: 2) {
                ForEach(CommerceTab.allCases) { destination in
                    Button { tab = destination } label: {
                        Image(systemName: tab == destination ? destination.selectedSymbol : destination.symbol)
                            .font(.system(size: 19, weight: .medium))
                            .foregroundStyle(tab == destination ? Color.black : CommerceColors.secondary)
                            .frame(maxWidth: .infinity).frame(height: 44)
                            .background(tab == destination ? CommerceColors.fill : .clear, in: Circle())
                    }
                    .accessibilityLabel(destination.title)
                    .accessibilityAddTraits(tab == destination ? [.isSelected] : [])
                    .accessibilityIdentifier("commerce-tab-" + (destination == .menu ? "store" : destination.rawValue))
                }
            }
            .padding(4).background(.white, in: Capsule())
            .shadow(color: .black.opacity(0.10), radius: 5, y: 2)
            Button { sheet = .pulse } label: {
                Image(systemName: "sparkles").font(.system(size: 20)).frame(width: 48, height: 48)
                    .background(.white, in: Circle())
                    .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
            }
            .accessibilityLabel("Sidekick Pulse")
        }
        .buttonStyle(.plain).foregroundStyle(Color.black)
        .padding(.horizontal, 14).padding(.top, 7).padding(.bottom, 4)
        .background(Color.white)
    }

    private func searchField(_ placeholder: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(CommerceColors.secondary)
            TextField(placeholder, text: $query).font(.system(size: 16)).textInputAutocapitalization(.never).autocorrectionDisabled()
                .accessibilityLabel(placeholder)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(CommerceColors.secondary)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12).frame(minHeight: 44)
        .background(CommerceColors.fill, in: RoundedRectangle(cornerRadius: 13))
    }

    @ViewBuilder private func destinationView(_ destination: CommerceSheet, scene: StudioScene) -> some View {
        switch destination {
        case .store: SceneEditor(scene: scene)
        case .analytics: CommerceAnalyticsEditor(profile: profile)
        case .order(let id): CommerceOrderDetail(sceneID: sceneID, orderID: id)
        case .newOrder: CommerceNewOrder(scene: scene)
        case .product(let id): CommerceProductEditor(sceneID: sceneID, productID: id)
        case .alerts: CommerceAlerts(sceneID: sceneID)
        case .search: CommerceStoreSearch(sceneID: sceneID)
        case .payout: informationSheet("Finances") {
            Form {
                Section("Next payout") {
                    LabeledContent("Amount", value: scene.money(profile.payoutAmount))
                    LabeledContent("Expected in", value: "\(profile.payoutDays) days")
                }
                Section("Balance") { LabeledContent("Available", value: scene.money(scene.balance)) }
                Section { Button("Edit payout details") { sheet = .analytics } }
            }
        }
        case .pulse: informationSheet("Sidekick Pulse") {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    pulseCard
                    Text("These recommendations use the orders and inventory in this store.")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding()
            }
        }
        }
    }

    private func informationSheet<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content().navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { sheet = nil } } }
        }
    }

    private var unfulfilledCount: Int { orders.filter { $0.fulfillment == .unfulfilled }.count }
    private var orderDays: [Date] {
        let days = Set(filteredOrders.map { Calendar.current.startOfDay(for: $0.date) })
        return days.sorted { descending ? $0 > $1 : $0 < $1 }
    }
    private func orders(on day: Date) -> [CommerceOrder] { filteredOrders.filter { Calendar.current.isDate($0.date, inSameDayAs: day) } }
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return "Good \(hour < 12 ? "morning" : hour < 18 ? "afternoon" : "evening")! Here’s your activity"
    }
}

private enum CommerceColors {
    static let fill = Color(red: 0.947, green: 0.947, blue: 0.947)
    static let secondary = Color(red: 0.45, green: 0.46, blue: 0.46)
    static let green = Color(red: 0.02, green: 0.65, blue: 0.37)
}

private struct CommerceLiveMark: View {
    var body: some View {
        ZStack {
            Circle().stroke(style: StrokeStyle(lineWidth: 1.1, dash: [1, 2]))
            Circle().stroke(lineWidth: 1.3).padding(3)
        }
        .accessibilityHidden(true)
    }
}

/// A simple open gauge, drawn locally rather than copied from a third-party icon set.
private struct CommercePayoutMark: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 20
        let origin = CGPoint(x: rect.midX - 10 * scale, y: rect.midY - 10 * scale)
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
        }
        var path = Path()
        path.addArc(center: point(10, 9.5), radius: 6 * scale,
                    startAngle: .degrees(150), endAngle: .degrees(390), clockwise: false)
        path.move(to: point(3.5, 17))
        path.addLine(to: point(16.5, 17))
        path.move(to: point(10, 6.5))
        path.addQuadCurve(to: point(13, 9.5), control: point(13, 6.5))
        return path
    }
}
private enum CommerceTab: String, CaseIterable, Identifiable {
    case home, orders, products, menu
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self { case .home: return "house"; case .orders: return "tray"; case .products: return "tag"; case .menu: return "line.3.horizontal" }
    }
    var selectedSymbol: String {
        switch self { case .home: return "house.fill"; case .orders: return "tray.fill"; case .products: return "tag.fill"; case .menu: return "line.3.horizontal" }
    }
}
private enum CommerceMetric: String, Identifiable { case live, sales, orders, conversion; var id: String { rawValue }; var title: String { self == .sales ? "Total sales" : self == .conversion ? "Conversion rate" : rawValue.capitalized } }
private enum CommerceRange: String, CaseIterable, Identifiable {
    case week, twoWeeks, month
    var id: String { rawValue }
    var days: Int { self == .week ? 7 : self == .twoWeeks ? 14 : 30 }
    var title: String { "Last \(days) days" }
}
private enum CommerceOrderFilter: String, CaseIterable, Identifiable {
    case all, unfulfilled, unpaid, open, archived
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    func includes(_ order: CommerceOrder) -> Bool {
        switch self {
        case .all: return true
        case .unfulfilled: return order.fulfillment == .unfulfilled
        case .unpaid: return !order.isPaid
        case .open: return order.fulfillment != .archived
        case .archived: return order.fulfillment == .archived
        }
    }
}
private enum CommerceSheet: Identifiable {
    case store, analytics, order(UUID), newOrder, product(UUID?), alerts, search, payout, pulse
    var id: String {
        switch self {
        case .store: return "store"
        case .analytics: return "analytics"
        case .order(let id): return "order-" + id.uuidString
        case .newOrder: return "new-order"
        case .product(let id): return "product-" + (id?.uuidString ?? "new")
        case .alerts: return "alerts"
        case .search: return "search"
        case .payout: return "payout"
        case .pulse: return "pulse"
        }
    }
}

private struct CommerceAnalyticsChart: View {
    let values: [Double]
    let metric: CommerceMetric
    let range: CommerceRange
    let scene: StudioScene
    let profile: CommerceProfile
    private var data: [CommerceChartPoint] {
        let source = values.isEmpty ? [0, 0] : values
        let end = Calendar.current.startOfDay(for: Date())
        let magnitude: Double
        switch metric {
        case .sales: magnitude = scene.sales
        case .orders: magnitude = Double(scene.orders)
        case .live: magnitude = Double(profile.liveVisitors)
        case .conversion: magnitude = profile.conversionRate
        }
        return (0..<range.days).map { index in
            let position = Double(index) / Double(max(range.days - 1, 1)) * Double(max(source.count - 1, 0))
            let left = min(Int(position), source.count - 1)
            let right = min(left + 1, source.count - 1)
            let value = source[left] + (source[right] - source[left]) * (position - Double(left))
            let scaled = value * magnitude
            let date = Calendar.current.date(byAdding: .day, value: index - range.days + 1, to: end) ?? end
            return CommerceChartPoint(id: index, date: date, value: max(0, scaled))
        }
    }
    private var axisDates: [Date] {
        let points = data
        let step = max(1, Int(ceil(Double(range.days) / 3)))
        return stride(from: 0, to: points.count, by: step).map { points[$0].date }
    }
    var body: some View {
        Chart(data) { point in
            LineMark(x: .value("Date", point.date), y: .value(metric.title, previousValue(point)), series: .value("Period", "Previous"))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color(red: 0.43, green: 0.57, blue: 0.63))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 5]))
            LineMark(x: .value("Date", point.date), y: .value(metric.title, point.value), series: .value("Period", "Current"))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color(red: 0.0, green: 0.61, blue: 0.84))
                .lineStyle(StrokeStyle(lineWidth: 2))
        }
        .chartLegend(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 2)) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.22))
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(axisLabel(number)).foregroundStyle(.white.opacity(0.75)).font(.system(size: 10))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: axisDates) { value in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day()).foregroundStyle(.white.opacity(0.75)).font(.system(size: 10))
            }
        }
        .chartYScale(domain: 0...max(max(data.map(\.value).max() ?? 0, data.map(previousValue).max() ?? 0) * 1.1, 1))
    }
    private func previousValue(_ point: CommerceChartPoint) -> Double {
        let source = profile.previousChart.isEmpty ? [0, 0] : profile.previousChart
        let position = Double(point.id) / Double(max(range.days - 1, 1)) * Double(max(source.count - 1, 0))
        let left = min(Int(position), source.count - 1)
        let right = min(left + 1, source.count - 1)
        let value = source[left] + (source[right] - source[left]) * (position - Double(left))
        let magnitude: Double
        switch metric {
        case .sales: magnitude = scene.sales
        case .orders: magnitude = Double(scene.orders)
        case .live: magnitude = Double(profile.liveVisitors)
        case .conversion: magnitude = profile.conversionRate
        }
        return max(0, value * magnitude)
    }
    private func axisLabel(_ number: Double) -> String {
        if metric == .conversion { return number.formatted(.number.precision(.fractionLength(0))) + "%" }
        if metric == .sales {
            if number >= 1000 { return (number / 1000).formatted(.currency(code: scene.currency).precision(.fractionLength(0))) + "K" }
            return number.formatted(.currency(code: scene.currency).precision(.fractionLength(0)))
        }
        return number.formatted(.number.precision(.fractionLength(0)))
    }
}
private struct CommerceChartPoint: Identifiable { let id: Int; let date: Date; let value: Double }

private struct CommerceOrderRow: View {
    let order: CommerceOrder
    let scene: StudioScene
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(verbatim: "#\(order.number)").font(.system(size: 18, weight: .semibold))
                Spacer()
                Text(scene.money(order.total)).font(.system(size: 16))
            }
            Text("\(order.customer) • \(order.itemCount) \(order.itemCount == 1 ? "item" : "items") • \(order.date.formatted(.dateTime.hour().minute()))")
                .font(.system(size: 14)).lineLimit(2)
            HStack(spacing: 5) {
                CommerceStatusBadge(status: order.fulfillment)
                Text(order.isPaid ? "Paid" : "Unpaid").font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8).padding(.vertical, 3).background(CommerceColors.fill, in: Capsule())
            }
            Text("Free Shipping").font(.system(size: 12)).foregroundStyle(CommerceColors.secondary)
        }
        .foregroundStyle(Color.black).padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
private struct CommerceStatusBadge: View {
    let status: CommerceFulfillment
    private var title: String { status == .unfulfilled ? "Unfulfilled" : status == .fulfilled ? "Fulfilled" : "Archived" }
    private var color: Color { status == .unfulfilled ? Color(red: 0.97, green: 0.89, blue: 0.42) : status == .fulfilled ? Color(red: 0.68, green: 0.96, blue: 0.73) : CommerceColors.fill }
    var body: some View {
        Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(Color.black)
            .padding(.horizontal, 8).padding(.vertical, 3).background(color, in: Capsule())
    }
}

private struct CommerceOrderDetail: View {
    let sceneID: UUID
    let orderID: UUID
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    private var scene: StudioScene? { store.scenes.first { $0.id == sceneID } }
    private var order: CommerceOrder? { store.commerceOrders(for: sceneID).first { $0.id == orderID } }

    var body: some View {
        NavigationStack {
            Group {
                if let order, let scene {
                    detail(order, scene: scene)
                        .navigationTitle(Text(verbatim: "#\(order.number)"))
                } else {
                    ContentUnavailableView("Order unavailable", systemImage: "tray")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .accessibilityIdentifier("commerce-order-detail")
    }

    private func detail(_ order: CommerceOrder, scene: StudioScene) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        CommerceStatusBadge(status: order.fulfillment)
                        Text(order.isPaid ? "Paid" : "Unpaid")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(CommerceColors.fill, in: Capsule())
                    }
                    Text(order.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 13)).foregroundStyle(CommerceColors.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            Section {
                HStack(spacing: 8) {
                    Image(systemName: order.fulfillment == .fulfilled ? "checkmark.circle" : "tray")
                        .foregroundStyle(CommerceColors.secondary)
                    Text(verbatim: "\(order.fulfillment.title) (\(order.itemCount))")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                }
                productRow(order, scene: scene)
                Button {
                    store.setOrderStatus(orderID: orderID, sceneID: sceneID,
                                         status: order.fulfillment == .fulfilled ? .unfulfilled : .fulfilled)
                } label: {
                    Text(order.fulfillment == .fulfilled ? "Mark as unfulfilled" : "Fulfill items")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Color(red: 0.18, green: 0.18, blue: 0.18), in: RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
                .padding(.vertical, 3)
                .accessibilityLabel(order.fulfillment == .fulfilled ? "Mark as unfulfilled" : "Mark as fulfilled")
                .accessibilityIdentifier("fulfill-order")
            }
            Section {
                HStack(spacing: 8) {
                    Image(systemName: order.isPaid ? "checkmark.circle" : "creditcard")
                        .foregroundStyle(CommerceColors.secondary)
                    Text(order.isPaid ? "Paid" : "Payment pending").font(.system(size: 16, weight: .semibold))
                    Spacer()
                }
                HStack {
                    Text("Subtotal").font(.system(size: 14))
                    Text("\(order.itemCount) \(order.itemCount == 1 ? "item" : "items")")
                        .font(.system(size: 12)).foregroundStyle(CommerceColors.secondary)
                    Spacer()
                    Text(scene.money(order.total)).font(.system(size: 14))
                }
                HStack {
                    Text("Total").font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Text(scene.currency).font(.system(size: 12)).foregroundStyle(CommerceColors.secondary)
                    Text(scene.money(order.total)).font(.system(size: 15, weight: .semibold))
                }
                LabeledContent(order.isPaid ? "Paid by customer" : "Amount due", value: scene.money(order.total))
                    .font(.system(size: 14))
                Button(order.isPaid ? "Mark as unpaid" : "Mark as paid") {
                    store.setOrderPaid(orderID: orderID, sceneID: sceneID, isPaid: !order.isPaid)
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(CommerceColors.secondary)
                .frame(minHeight: 44).contentShape(Rectangle())
                .accessibilityIdentifier("order-payment-status")
            }
            Section {
                HStack(spacing: 12) {
                    Text(initials(order.customer)).font(.system(size: 14, weight: .semibold))
                        .frame(width: 38, height: 38)
                        .background(CommerceColors.fill, in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Customer").font(.system(size: 12)).foregroundStyle(CommerceColors.secondary)
                        Text(order.customer).font(.system(size: 15, weight: .medium))
                    }
                }
            }
            Section {
                Button(order.fulfillment == .archived ? "Reopen order" : "Archive order") {
                    store.setOrderStatus(orderID: orderID, sceneID: sceneID,
                                         status: order.fulfillment == .archived ? .unfulfilled : .archived)
                }
                .foregroundStyle(CommerceColors.secondary)
                .frame(minHeight: 44).contentShape(Rectangle())
            }
            if let error = store.error { Section { Text(error).foregroundStyle(.red) } }
        }
        .listStyle(.insetGrouped)
        .foregroundStyle(Color.black)
        .scrollContentBackground(.hidden)
        .background(Color(red: 0.965, green: 0.965, blue: 0.965))
    }

    private func productRow(_ order: CommerceOrder, scene: StudioScene) -> some View {
        // The archive stores aggregate order totals. Name a catalog item only when its
        // price and quantity exactly explain that total; otherwise preserve the known aggregate.
        let product = store.commerceProfile(for: sceneID).products.first {
            abs($0.price * Double(order.itemCount) - order.total) < 0.005
        }
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: product?.symbol ?? "cube.box")
                .font(.system(size: 25)).foregroundStyle(CommerceColors.secondary)
                .frame(width: 56, height: 62)
                .background(CommerceColors.fill, in: RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .topTrailing) {
                    Text(verbatim: String(order.itemCount))
                        .font(.system(size: 10, weight: .semibold)).padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.white, in: Capsule()).offset(x: 4, y: -4)
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(product?.title ?? "Order items").font(.system(size: 15, weight: .semibold))
                Text(product == nil ? "Custom order" : "Default variant")
                    .font(.system(size: 12)).foregroundStyle(CommerceColors.secondary)
                if let product {
                    Text("\(scene.money(product.price)) × \(order.itemCount)").font(.system(size: 13))
                } else {
                    Text("Quantity: \(order.itemCount)").font(.system(size: 13))
                }
            }
            Spacer(minLength: 4)
            Text(scene.money(order.total)).font(.system(size: 14)).padding(.top, 2)
        }
        .padding(.vertical, 8)
    }
    private func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}

private struct CommerceNewOrder: View {
    let scene: StudioScene
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @State private var customer = ""
    @State private var amount = ""
    @State private var itemCount = 1
    @FocusState private var editing: Bool
    private var valid: Bool {
        let name = customer.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && name.count <= 80 && (1...100).contains(itemCount) && Simulation.parseAmount(amount).map(Simulation.validAmount) == true
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Customer") { TextField("Customer name", text: $customer).textContentType(.name).focused($editing) }
                Section("Order") {
                    TextField("Total in \(scene.currency)", text: $amount).keyboardType(.decimalPad).focused($editing)
                    Stepper("\(itemCount) \(itemCount == 1 ? "item" : "items")", value: $itemCount, in: 1...100)
                }
                if let error = store.error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("Create order").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(!valid) }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { editing = false } }
            }
        }
        .accessibilityIdentifier("commerce-new-order")
    }
    private func save() {
        guard valid, let value = Simulation.parseAmount(amount) else { return }
        if store.addCommerceOrder(sceneID: scene.id, customer: customer.trimmingCharacters(in: .whitespacesAndNewlines), itemCount: itemCount, total: value) != nil { dismiss() }
    }
}

private struct CommerceProductEditor: View {
    let sceneID: UUID
    let productID: UUID?
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var price = ""
    @State private var inventory = ""
    @State private var symbol = "tshirt"
    @State private var didLoad = false
    @FocusState private var editing: Bool
    private let symbols = ["tshirt", "tshirt.fill", "bag", "bag.fill", "shoe", "cup.and.saucer", "lamp.desk", "headphones", "book", "gift", "leaf", "cube.box", "sun.max.fill"]
    private var parsedInventory: Int? {
        guard let number = Simulation.parseAmount(inventory), number <= 1_000_000, number >= 0, number.rounded(.down) == number else { return nil }
        return Int(number)
    }
    private var valid: Bool {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !clean.isEmpty && clean.count <= 80 && Simulation.parseAmount(price).map { (0...1_000_000_000).contains($0) } == true && parsedInventory != nil
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        Image(systemName: symbol).font(.system(size: 48)).frame(width: 100, height: 110)
                            .foregroundStyle(CommerceColors.secondary).background(CommerceColors.fill, in: RoundedRectangle(cornerRadius: 20))
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    TextField("Product title", text: $title).focused($editing)
                    Picker("Product image", selection: $symbol) {
                        ForEach(symbols, id: \.self) { name in Label(name.replacingOccurrences(of: ".", with: " ").capitalized, systemImage: name).tag(name) }
                    }
                }
                Section("Pricing and inventory") {
                    TextField("Price", text: $price).keyboardType(.decimalPad).focused($editing)
                    TextField("Available inventory", text: $inventory).keyboardType(.numberPad).focused($editing)
                }
                if productID != nil {
                    Section {
                        Button("Delete product", role: .destructive) {
                            var profile = store.commerceProfile(for: sceneID)
                            profile.products.removeAll { $0.id == productID }
                            if store.updateCommerceProfile(profile) { dismiss() }
                        }
                    }
                }
                if let error = store.error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle(productID == nil ? "Add product" : "Edit product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(!valid) }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { editing = false } }
            }
            .onAppear(perform: load)
        }
        .accessibilityIdentifier("commerce-product-editor")
    }
    private func load() {
        guard !didLoad else { return }
        didLoad = true
        if let product = store.commerceProfile(for: sceneID).products.first(where: { $0.id == productID }) {
            title = product.title
            price = product.price.formatted(.number.grouping(.never))
            inventory = product.inventory.formatted(.number.grouping(.never))
            symbol = product.symbol
        } else { inventory = "0" }
    }
    private func save() {
        guard valid, let amount = Simulation.parseAmount(price), let count = parsedInventory else { return }
        var profile = store.commerceProfile(for: sceneID)
        let product = CommerceProduct(id: productID ?? UUID(), title: title.trimmingCharacters(in: .whitespacesAndNewlines), price: amount, inventory: count, symbol: symbol)
        if let index = profile.products.firstIndex(where: { $0.id == product.id }) { profile.products[index] = product }
        else { profile.products.append(product) }
        if store.updateCommerceProfile(profile) { dismiss() }
    }
}

private struct CommerceAnalyticsEditor: View {
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @State var profile: CommerceProfile
    @State private var chartText = ""
    @State private var previousText = ""
    @State private var didLoad = false
    @FocusState private var editing: Bool
    private var chartValues: [Double]? { parseSeries(chartText) }
    private var previousValues: [Double]? { parseSeries(previousText) }
    private func parseSeries(_ text: String) -> [Double]? {
        let fields = text.split(separator: ",", omittingEmptySubsequences: false)
        guard (2...60).contains(fields.count) else { return nil }
        let values = fields.compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        guard values.count == fields.count, values.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else { return nil }
        return values
    }
    private var valid: Bool {
        (0...1_000_000).contains(profile.liveVisitors) && profile.conversionRate.isFinite && (0...100).contains(profile.conversionRate)
        && profile.salesChange.isFinite && (-100...10_000).contains(profile.salesChange)
        && profile.ordersChange.isFinite && (-100...10_000).contains(profile.ordersChange)
        && profile.payoutAmount.isFinite && (0...1_000_000_000).contains(profile.payoutAmount)
        && (0...365).contains(profile.payoutDays) && chartValues != nil && previousValues != nil
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Live and conversion") {
                    labeledNumber("Live visitors", value: $profile.liveVisitors)
                    labeledDecimal("Conversion rate (%)", value: $profile.conversionRate)
                }
                Section("Compared with previous period") {
                    labeledDecimal("Sales change (%)", value: $profile.salesChange, signed: true)
                    labeledDecimal("Orders change (%)", value: $profile.ordersChange, signed: true)
                }
                Section("Payout") {
                    labeledDecimal("Payout amount", value: $profile.payoutAmount)
                    labeledNumber("Days until payout", value: $profile.payoutDays)
                }
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Current period").font(.caption).foregroundStyle(.secondary)
                        TextField("Current chart values", text: $chartText, axis: .vertical)
                            .keyboardType(.numbersAndPunctuation).lineLimit(2...5).focused($editing)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Previous period").font(.caption).foregroundStyle(.secondary)
                        TextField("Previous chart values", text: $previousText, axis: .vertical)
                            .keyboardType(.numbersAndPunctuation).lineLimit(2...5).focused($editing)
                    }
                } header: { Text("Chart shape") } footer: {
                    Text("Enter 2–60 values from 0 to 1, separated by commas. Each value is a fraction of the selected metric. Use a period for decimals. Date ranges spread the shape across the selected period.")
                }
                if let error = store.error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("Analytics settings").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") {
                    guard valid, let values = chartValues, let previous = previousValues else { return }
                    profile.chart = values
                    profile.previousChart = previous
                    if store.updateCommerceProfile(profile) { dismiss() }
                }.disabled(!valid) }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { editing = false } }
            }
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                chartText = profile.chart.map { String($0) }.joined(separator: ", ")
                previousText = profile.previousChart.map { String($0) }.joined(separator: ", ")
            }
        }
    }
    private func labeledDecimal(_ title: String, value: Binding<Double>, signed: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(title, value: value, format: .number.grouping(.never))
                .keyboardType(signed ? .numbersAndPunctuation : .decimalPad).focused($editing)
        }
    }
    private func labeledNumber(_ title: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(title, value: value, format: .number.grouping(.never)).keyboardType(.numberPad).focused($editing)
        }
    }
}

private struct CommerceAlerts: View {
    let sceneID: UUID
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    private var alerts: [QueuedAlert] { store.queuedAlerts.filter { $0.sceneID == sceneID } }
    private var events: [SceneEvent] { store.events.filter { $0.sceneID == sceneID }.sorted { $0.date > $1.date } }
    var body: some View {
        NavigationStack {
            List {
                if alerts.isEmpty && events.isEmpty {
                    ContentUnavailableView("No notifications yet", systemImage: "bell", description: Text("Order activity and queued alerts appear here."))
                }
                if !alerts.isEmpty {
                    Section("Upcoming") {
                        ForEach(alerts) { alert in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(alert.title).font(.headline)
                                Text(alert.body).font(.subheadline).foregroundStyle(.secondary)
                                if let date = alert.date { Text(date, style: .relative).font(.caption).foregroundStyle(.secondary) }
                            }
                            .swipeActions { Button("Cancel", role: .destructive) { Task { await store.cancelAlert(alert) } } }
                            .contextMenu { Button("Cancel notification", role: .destructive) { Task { await store.cancelAlert(alert) } } }
                        }
                    }
                }
                if !events.isEmpty {
                    Section("Store activity") {
                        ForEach(events.prefix(100)) { event in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: event.kind.symbol).frame(width: 24).foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.title).font(.headline)
                                    if let scene = store.scenes.first(where: { $0.id == sceneID }) { Text(event.body(scene: scene)).font(.subheadline).foregroundStyle(.secondary) }
                                    Text(event.date, style: .relative).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Notifications").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { await store.refreshNotifications() }
            .refreshable { await store.refreshNotifications() }
        }
    }
}

private struct CommerceStoreSearch: View {
    let sceneID: UUID
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var destination: CommerceSheet?
    private var orders: [CommerceOrder] {
        store.commerceOrders(for: sceneID).filter { query.isEmpty || "\($0.number) \($0.customer)".localizedCaseInsensitiveContains(query) }
    }
    private var products: [CommerceProduct] {
        store.commerceProfile(for: sceneID).products.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }
    }
    var body: some View {
        NavigationStack {
            List {
                if orders.isEmpty && products.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
                if !orders.isEmpty {
                    Section("Orders") {
                        ForEach(orders) { order in
                            Button { destination = .order(order.id) } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(verbatim: "#\(order.number)").font(.headline)
                                    Text(order.customer).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                if !products.isEmpty {
                    Section("Products") {
                        ForEach(products) { product in
                            Button { destination = .product(product.id) } label: {
                                Label(product.title, systemImage: product.symbol)
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Orders and products")
            .navigationTitle("Search").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $destination) { selection in
                switch selection {
                case .order(let id): CommerceOrderDetail(sceneID: sceneID, orderID: id)
                case .product(let id): CommerceProductEditor(sceneID: sceneID, productID: id)
                default: EmptyView()
                }
            }
        }
    }
}
