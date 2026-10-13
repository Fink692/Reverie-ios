import SwiftUI
import Charts

private let accent = Color(red: 0.24, green: 0.36, blue: 0.94)
struct RootView: View {
    @EnvironmentObject var store: StudioStore
    @AppStorage("appearance") var appearance = "System"
    var body: some View {
        TabView {
            DashboardView().tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }
            ComposerView().tabItem { Label("Studio", systemImage: "slider.horizontal.3") }
            ActivityView().tabItem { Label("Activity", systemImage: "clock") }
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }
        }.tint(accent).preferredColorScheme(appearance == "System" ? nil : appearance == "Dark" ? .dark : .light)
    }
}
struct StudioLabel: View {
    var body: some View {
        Label("REVERIE STUDIO", systemImage: "sparkle").font(.caption2.weight(.bold)).tracking(1.4)
            .foregroundStyle(accent).padding(.horizontal, 12).padding(.vertical, 7)
            .background(accent.opacity(0.1), in: Capsule())
    }
}
struct WelcomeView: View {
    var done: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()
            Image(systemName: "sparkles.rectangle.stack.fill").font(.system(size: 66)).foregroundStyle(accent)
            Text("A little make-believe.\nA lot of possibility.").font(.largeTitle.bold())
            Text("Build your own world of stores, balances, and milestones. Set the scene, cue the notifications, and enjoy the moment.").foregroundStyle(.secondary)
            Label("Custom dashboards and saved scenes", systemImage: "square.grid.2x2")
            Label("Scheduled notifications", systemImage: "bell.badge")
            Label("Private by design. Everything stays here.", systemImage: "lock")
            Spacer()
            Text("Reverie is a roleplay simulator. All figures and notifications are fictional. It is not connected to a bank or Shopify.").font(.footnote).foregroundStyle(.secondary)
            Button(action: done) { Text("Enter your studio").frame(maxWidth: .infinity).padding(10) }.buttonStyle(.borderedProminent).controlSize(.large)
        }.padding(28).tint(accent)
    }
}
struct DashboardView: View {
    @EnvironmentObject var store: StudioStore
    @State private var editing = false
    @State private var range = "Today"
    let ranges = ["Today", "7 days", "30 days"]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack { StudioLabel(); Spacer(); Text("Your world, on cue").font(.caption).foregroundStyle(.secondary) }
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(store.active.kind.title.uppercased()).font(.caption.weight(.semibold)).tracking(2).foregroundStyle(.secondary)
                            Text(store.active.name).font(.title.bold())
                        }
                        Spacer()
                        Menu {
                            ForEach(store.scenes) { scene in Button(scene.name) { store.select(scene) } }
                        } label: { Image(systemName: "chevron.up.chevron.down").padding(12).background(.quaternary, in: Circle()) }
                    }
                    if store.active.kind == .banking { bankCard } else { revenueCard }
                    Picker("Period", selection: $range) { ForEach(ranges, id: \.self) { Text($0) } }.pickerStyle(.segmented)
                    trend
                    HStack(spacing: 12) {
                        MetricCard(title: store.active.kind == .creator ? "Audience" : "Orders", value: (store.active.kind == .creator ? store.active.audience : store.active.orders).formatted(), symbol: "person.2")
                        MetricCard(title: store.active.kind == .banking ? "Income" : "Available", value: store.active.money(store.active.kind == .banking ? store.active.sales : store.active.balance), symbol: "banknote")
                    }
                    HStack { Text("Latest activity").font(.title3.bold()); Spacer(); Text("Reverie").font(.caption2).foregroundStyle(.secondary) }
                    if store.activity.isEmpty {
                        ContentUnavailableView("The stage is set", systemImage: "sparkles", description: Text("Create an event in Studio to bring this scene to life."))
                    } else { ForEach(store.activity.prefix(4)) { event in EventRow(event: event, scene: store.active) } }
                }.padding(20)
            }.background(Color(.systemGroupedBackground))
                .navigationTitle("Reverie").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button { editing = true } label: { Image(systemName: "pencil") }.accessibilityLabel("Edit dashboard") }
                .sheet(isPresented: $editing) { SceneEditor(scene: store.active) }
        }
    }
    var revenueCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Label(store.active.kind == .creator ? "Creator earnings" : "Total sales", systemImage: store.active.kind.symbol); Spacer(); Image(systemName: "arrow.up.right") }
            Text(store.active.money(store.active.sales)).font(.system(.largeTitle, design: .rounded).bold()).minimumScaleFactor(0.5).lineLimit(1)
            HStack { Text("A world you create"); Spacer(); Text("REVERIE").bold() }.font(.caption).opacity(0.85)
        }.padding(24).foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [accent, Color(red: 0.43, green: 0.27, blue: 0.85)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 26))
    }
    var bankCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack { Label("\(store.active.name)", systemImage: "building.columns"); Spacer(); Image(systemName: "wave.3.right") }.font(.subheadline)
            VStack(alignment: .leading, spacing: 6) { Text("Available balance").font(.caption).opacity(0.7); Text(store.active.money(store.active.balance)).font(.largeTitle.bold()).minimumScaleFactor(0.5).lineLimit(1) }
            HStack { Text("••••  2048").tracking(3); Spacer(); Text("REVERIE").font(.caption2.bold()) }
        }.padding(24).foregroundStyle(.white).background(LinearGradient(colors: [Color(red: 0.1, green: 0.15, blue: 0.22), Color(red: 0.2, green: 0.28, blue: 0.37)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 26))
    }
    var trend: some View {
        let values: [Double] = range == "Today" ? [0.18,0.22,0.19,0.38,0.32,0.55,0.51,0.68,0.64,0.88,0.82,1] : range == "7 days" ? [0.28,0.48,0.36,0.75,0.61,0.9,1] : [0.12,0.28,0.21,0.42,0.32,0.67,0.55,0.78,0.7,1]
        return VStack(alignment: .leading, spacing: 16) {
            HStack { Text("The bigger picture").font(.headline); Spacer(); Text(range).font(.caption).foregroundStyle(.secondary) }
            Chart(Array(values.enumerated()), id: \.offset) { item in
                AreaMark(x: .value("Period", item.offset), y: .value("Illustrative trend", item.element)).foregroundStyle(LinearGradient(colors: [accent.opacity(0.2), accent.opacity(0.01)], startPoint: .top, endPoint: .bottom)).interpolationMethod(.monotone)
                LineMark(x: .value("Period", item.offset), y: .value("Illustrative trend", item.element)).foregroundStyle(accent).lineStyle(StrokeStyle(lineWidth: 3)).interpolationMethod(.monotone)
            }.chartXAxis(.hidden).chartYAxis(.hidden).frame(height: 140).accessibilityLabel("Illustrative demo trend for \(range), increasing overall. Not historical data.")
            Text("Illustrative trend · customize your totals with Edit").font(.caption2).foregroundStyle(.secondary)
        }.padding(20).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }
}
struct MetricCard: View {
    let title: String; let value: String; let symbol: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.bold()).minimumScaleFactor(0.5).lineLimit(1)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }
}
struct EventRow: View {
    let event: SceneEvent; let scene: StudioScene
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: event.kind.symbol).foregroundStyle(accent).frame(width: 44, height: 44).background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) { Text(event.title).font(.subheadline.weight(.semibold)); Text(event.detail.isEmpty ? scene.name : event.detail).font(.caption).foregroundStyle(.secondary) }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) { Text(event.kind == .subscriber ? "+1" : scene.money(event.amount)).font(.subheadline.weight(.semibold)); Text(event.date, style: .time).font(.caption2).foregroundStyle(.secondary) }
        }.padding(14).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}
struct ComposerView: View {
    @EnvironmentObject var store: StudioStore
    @State private var kind: EventKind = .order
    @State private var amount = "149.00"
    @State private var detail = "Everyday essentials · Order #1048"
    @State private var delay = 5.0
    @State private var count = 1
    @State private var working = false
    @State private var confirmation: String?
    var valid: Bool { Double(amount).map(Simulation.validAmount) ?? false }
    var body: some View {
        NavigationStack {
            Form {
                Section { StudioLabel(); Text("Make a moment").font(.title.bold()); Text("Compose a milestone for \(store.active.name).").foregroundStyle(.secondary) }
                Section("Event") {
                    Picker("Type", selection: $kind) { ForEach(EventKind.allCases) { Text($0.title).tag($0) } }
                    TextField("Amount", text: $amount).keyboardType(.decimalPad)
                    TextField("Details", text: $detail, axis: .vertical).lineLimit(2...4)
                }
                Section("Preview") {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: store.active.kind.symbol).foregroundStyle(.white).padding(10).background(accent, in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 5) { HStack { Text("REVERIE").font(.caption.bold()); Spacer(); Text("now").font(.caption).foregroundStyle(.secondary) }; Text(kind.title).font(.headline); Text("\(store.active.name) · \(store.active.money(Double(amount) ?? 0)) · \(detail)").font(.subheadline) }
                    }.padding(.vertical, 8)
                    Text("iOS notifications always come from Reverie. Lock Screen appearance depends on your device settings.").font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Button { if store.emit(kind: kind, amount: Double(amount) ?? 0, detail: detail) != nil { confirmation = "Added to your dashboard." } } label: { Label("Add event to dashboard", systemImage: "plus.circle.fill") }.disabled(!valid)
                } footer: { Text("Scheduled alerts are a separate performance cue and do not change dashboard totals.") }
                Section("Notification session") {
                    Stepper("\(count) notification\(count == 1 ? "" : "s")", value: $count, in: 1...20)
                    Picker("Start after", selection: $delay) { Text("5 seconds").tag(5.0); Text("30 seconds").tag(30.0); Text("1 minute").tag(60.0); Text("5 minutes").tag(300.0) }
                    Text("Multiple alerts arrive 10 seconds apart.").font(.caption).foregroundStyle(.secondary)
                    Button {
                        working = true
                        Task { let success = await store.schedule(kind: kind, amount: Double(amount) ?? 0, detail: detail, delay: delay, count: count); working = false; if success { confirmation = "\(count) alerts queued. You can lock your phone or leave the app." } }
                    } label: { HStack { Label("Cue notifications", systemImage: "bell.badge.fill"); Spacer(); if working { ProgressView() } } }.disabled(!valid || working)
                    if store.pendingCount > 0 { Button("Cancel \(store.pendingCount) queued alerts", role: .destructive) { Task { await store.cancelNotifications() } } }
                }
            }.navigationTitle("Studio").task { await store.refreshNotifications() }
                .alert("Ready", isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } })) { Button("OK") { confirmation = nil } } message: { Text(confirmation ?? "") }
                .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } } }
        }
    }
}
struct ActivityView: View {
    @EnvironmentObject var store: StudioStore
    @State private var query = ""
    var filtered: [SceneEvent] { store.activity.filter { query.isEmpty || "\($0.title) \($0.detail)".localizedCaseInsensitiveContains(query) } }
    var body: some View {
        NavigationStack {
            ScrollView { LazyVStack(spacing: 12) { StudioLabel(); if filtered.isEmpty { ContentUnavailableView("No moments yet", systemImage: "clock", description: Text("Events you add to this scene appear here.")) }; ForEach(filtered) { EventRow(event: $0, scene: store.active) } }.padding(20) }
                .background(Color(.systemGroupedBackground)).navigationTitle("Activity").searchable(text: $query, prompt: "Search this scene")
        }
    }
}
struct SceneEditor: View {
    @EnvironmentObject var store: StudioStore
    @Environment(\.dismiss) var dismiss
    @State var scene: StudioScene
    @State private var balance = ""
    @State private var sales = ""
    var valid: Bool { !scene.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && [Double(balance), Double(sales)].allSatisfy { value in value.map { $0.isFinite && $0 >= 0 && $0 <= 1_000_000_000 } ?? false } }
    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") { TextField("Scene name", text: $scene.name); Picker("Dashboard", selection: $scene.kind) { ForEach(SceneKind.allCases) { Text($0.title).tag($0) } }; Picker("Currency", selection: $scene.currency) { ForEach(["USD", "GBP", "EUR", "CAD", "AUD", "JPY"], id: \.self) { Text($0) } } }
                Section("Dashboard totals") { TextField("Balance", text: $balance).keyboardType(.decimalPad); TextField("Sales / income", text: $sales).keyboardType(.decimalPad); Stepper("Orders: \(scene.orders)", value: $scene.orders, in: 0...1000000); Stepper("Audience: \(scene.audience)", value: $scene.audience, in: 0...100000000) }
                Section { Text("All values are fictional. Your scene is stored only on this device.").font(.footnote).foregroundStyle(.secondary) }
            }.navigationTitle("Edit scene").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { scene.name = scene.name.trimmingCharacters(in: .whitespacesAndNewlines); scene.balance = Double(balance) ?? 0; scene.sales = Double(sales) ?? 0; store.update(scene); dismiss() }.disabled(!valid) } }
                .onAppear { balance = String(scene.balance); sales = String(scene.sales) }
        }
    }
}
struct SettingsView: View {
    @EnvironmentObject var store: StudioStore
    @Environment(\.scenePhase) var phase
    @AppStorage("appearance") var appearance = "System"
    @State private var editing: StudioScene?
    @State private var reset = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Your scenes") {
                    ForEach(store.scenes) { scene in HStack { Button { store.select(scene) } label: { Label(scene.name, systemImage: scene.kind.symbol) }; Spacer(); if scene.id == store.activeID { Image(systemName: "checkmark.circle.fill").foregroundStyle(accent) }; Button { editing = scene } label: { Image(systemName: "pencil") }.buttonStyle(.borderless).accessibilityLabel("Edit \(scene.name)") }.swipeActions { if store.scenes.count > 1 { Button("Delete", role: .destructive) { store.delete(scene) } } } }
                    Button { editing = StudioScene(name: "Untitled scene", kind: .commerce, balance: 0, sales: 0, orders: 0, audience: 0) } label: { Label("New scene", systemImage: "plus") }
                }
                Section("Experience") { Picker("Appearance", selection: $appearance) { ForEach(["System", "Light", "Dark"], id: \.self) { Text($0) } }; LabeledContent("Notifications", value: store.notificationStatus); Button("Open iOS Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }; Button("Cancel queued notifications", role: .destructive) { Task { await store.cancelNotifications() } } }
                Section("Your data") { ShareLink(item: store.export()) { Label("Export session", systemImage: "square.and.arrow.up") }; Button("Reset all scenes", role: .destructive) { reset = true } }
                Section("About Reverie") { StudioLabel(); Text("A private stage for fictional milestones. No accounts, real money, analytics tracking, or connections to financial services."); Text("Not affiliated with Shopify or any bank. Notifications identify Reverie. Charts are illustrative.").font(.footnote).foregroundStyle(.secondary); LabeledContent("Version", value: "1.0.0") }
            }.navigationTitle("Settings").sheet(item: $editing) { SceneEditor(scene: $0) }
                .confirmationDialog("Reset all scenes and cancel every queued alert?", isPresented: $reset, titleVisibility: .visible) { Button("Reset everything", role: .destructive) { Task { await store.reset() } } }
                .task { await store.refreshNotifications() }.onChange(of: phase) { _, value in if value == .active { Task { await store.refreshNotifications() } } }
        }.preferredColorScheme(appearance == "System" ? nil : appearance == "Dark" ? .dark : .light)
    }
}
#Preview { RootView().environmentObject(StudioStore()) }
