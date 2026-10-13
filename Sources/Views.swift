import SwiftUI
import Charts
import UniformTypeIdentifiers

private let accent = Color(red: 0.24, green: 0.36, blue: 0.94)

private enum StudioTab: Hashable {
    case dashboard, studio, activity, settings
}

struct RootView: View {
    @EnvironmentObject var store: StudioStore
    @Environment(\.scenePhase) private var phase
    @AppStorage("appearance") private var appearance = "System"
    @State private var selection: StudioTab = .dashboard

    var body: some View {
        TabView(selection: $selection) {
            DashboardView(onCompose: { selection = .studio }, onActivity: { selection = .activity })
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }
                .tag(StudioTab.dashboard)
            ComposerView()
                .tabItem { Label("Studio", systemImage: "slider.horizontal.3") }
                .tag(StudioTab.studio)
            ActivityView()
                .tabItem { Label("Activity", systemImage: "clock") }
                .tag(StudioTab.activity)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(StudioTab.settings)
        }
        .tint(accent)
        .preferredColorScheme(appearance == "System" ? nil : appearance == "Dark" ? .dark : .light)
        .task { await store.refreshNotifications() }
        .onChange(of: phase) { _, value in
            if value == .active { Task { await store.refreshNotifications() } }
        }
        .onReceive(NotificationRouter.shared.$request) { route in
            if route != nil { selection = .dashboard }
        }
        .onReceive(NotificationCenter.default.publisher(for: .notificationStateDidChange)) { _ in
            Task { await store.refreshNotifications() }
        }
    }
}

struct StudioLabel: View {
    var body: some View {
        Label("REVERIE STUDIO", systemImage: "sparkle")
            .font(.caption2.weight(.bold))
            .tracking(1.4)
            .foregroundStyle(accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(accent.opacity(0.1), in: Capsule())
            .accessibilityLabel("Reverie Studio")
    }
}

struct WelcomeView: View {
    var done: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 64, weight: .medium))
                    .foregroundStyle(accent)
                    .padding(.top, 20)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 14) {
                    Text("A little make-believe.\nA lot of possibility.")
                        .font(.largeTitle.bold())
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("Build your own world of stores, balances, and milestones. Set the scene, cue the notifications, and enjoy the moment.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 22) {
                    WelcomeFeature(symbol: "square.grid.2x2", title: "A world of your own", detail: "Create stores, banking dashboards, and creator scenes.")
                    WelcomeFeature(symbol: "bell.badge", title: "Make the moment", detail: "Compose events and schedule alerts for the perfect cue.")
                    WelcomeFeature(symbol: "lock", title: "Private by design", detail: "Stored locally; you can export your sessions. No account needed.")
                }
                Text("Reverie is a roleplay simulator. All figures and notifications are fictional. It is not connected to a bank or Shopify.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 600, alignment: .leading)
            .padding(28)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            Button(action: done) {
                Text("Enter your studio")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: 600)
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
        }
        .tint(accent)
    }
}

private struct WelcomeFeature: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(accent)
                .frame(width: 42, height: 42)
                .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject var store: StudioStore
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var editing = false
    @State private var playback: StudioScene?
    @State private var range = "Today"
    var onCompose: () -> Void = {}
    var onActivity: () -> Void = {}
    private let ranges = ["Today", "7 days", "30 days"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    StudioLabel()
                    HStack(alignment: .center, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(store.active.kind.title.uppercased())
                                .font(.caption.weight(.semibold))
                                .tracking(2)
                                .foregroundStyle(.secondary)
                            Text(store.active.name)
                                .font(.title.bold())
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityAddTraits(.isHeader)
                        }
                        Spacer(minLength: 0)
                        Menu {
                            ForEach(store.scenes) { scene in
                                Button { store.select(scene) } label: {
                                    if scene.id == store.activeID {
                                        Label(scene.name, systemImage: "checkmark")
                                    } else {
                                        Text(scene.name)
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.body.weight(.semibold))
                                .frame(width: 44, height: 44)
                                .background(Color(.secondarySystemGroupedBackground), in: Circle())
                        }
                        .accessibilityLabel("Switch scene")
                        .accessibilityValue(store.active.name)
                    }
                    if store.active.kind == .banking { bankCard } else { revenueCard }
                    if store.active.kind != .creator {
                        Button {
                            let scene = store.active
                            if store.preparePlayback(for: scene.id) { playback = scene }
                        } label: {
                            Label("Open scene", systemImage: "arrow.up.left.and.arrow.down.right")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityIdentifier("open-scene")
                    }
                    Picker("Period", selection: $range) {
                        ForEach(ranges, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityHint("Changes the illustrative chart period")
                    trend
                    metrics
                    Button(action: onCompose) {
                        Label("Create event", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    HStack(alignment: .firstTextBaseline) {
                        Text("Latest activity").font(.title3.bold()).accessibilityAddTraits(.isHeader)
                        Spacer()
                        if !store.activity.isEmpty {
                            Button("See all", action: onActivity)
                                .font(.subheadline.weight(.semibold))
                                .accessibilityLabel("See all activity")
                        }
                    }
                    if store.activity.isEmpty {
                        ContentUnavailableView("The stage is set", systemImage: "sparkles", description: Text("Create an event in Studio to bring this scene to life."))
                    } else {
                        ForEach(store.activity.prefix(4)) { event in
                            EventRow(event: event, scene: store.active)
                        }
                    }
                }
                .frame(maxWidth: 720, alignment: .leading)
                .padding(20)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Reverie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button { editing = true } label: { Image(systemName: "pencil") }
                    .accessibilityLabel("Edit dashboard")
                    .accessibilityHint("Change this scene's name, currency, and totals")
            }
            .sheet(isPresented: $editing) { SceneEditor(scene: store.active) }
            .fullScreenCover(item: $playback) { scene in
                switch scene.kind {
                case .commerce: CommercePlayback(sceneID: scene.id).environmentObject(store)
                case .banking: BankPlayback(sceneID: scene.id).environmentObject(store)
                case .creator: EmptyView()
                }
            }
            .onReceive(NotificationRouter.shared.$request) { route in
                if route != nil { playback = nil }
            }
            .onChange(of: store.scenes) { _, scenes in
                if let playback, !scenes.contains(where: { $0.id == playback.id && $0.kind == playback.kind }) {
                    self.playback = nil
                }
            }
        }
    }

    private var revenueCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(store.active.kind == .creator ? "Creator earnings" : "Total sales", systemImage: store.active.kind.symbol)
                .font(.subheadline.weight(.medium))
            Text(store.active.money(store.active.sales))
                .font(.system(.largeTitle, design: .rounded).bold())
                .monospacedDigit()
                .minimumScaleFactor(0.65)
                .lineLimit(1)
                .accessibilityLabel("\(store.active.kind == .creator ? "Creator earnings" : "Total sales"), \(store.active.money(store.active.sales))")
            Text("A world you create")
                .font(.caption)
                .opacity(0.9)
        }
        .padding(24)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [accent, Color(red: 0.43, green: 0.27, blue: 0.85)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26)
        )
    }

    private var bankCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top) {
                Label(store.active.name, systemImage: "building.columns")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Image(systemName: "wave.3.right").accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Available balance").font(.subheadline).opacity(0.85)
                Text(store.active.money(store.active.balance))
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .monospacedDigit()
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
            }
            HStack {
                Text("••••  2048").tracking(3)
                    .accessibilityLabel("Fictional card ending in 2048")
                Spacer()
                Text("REVERIE").font(.caption2.bold())
            }
        }
        .padding(24)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(red: 0.1, green: 0.15, blue: 0.22), Color(red: 0.2, green: 0.28, blue: 0.37)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26)
        )
    }

    @ViewBuilder private var metrics: some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: 12) { firstMetric; secondMetric }
        } else {
            HStack(alignment: .top, spacing: 12) { firstMetric; secondMetric }
        }
    }

    private var firstMetric: some View {
        MetricCard(
            title: store.active.kind == .banking ? "Income" : store.active.kind == .creator ? "Audience" : "Orders",
            value: store.active.kind == .banking ? store.active.money(store.active.sales) : (store.active.kind == .creator ? store.active.audience : store.active.orders).formatted(),
            symbol: store.active.kind == .banking ? "arrow.down.left" : store.active.kind == .creator ? "person.2" : "bag"
        )
    }

    private var secondMetric: some View {
        MetricCard(
            title: store.active.kind == .banking ? "Activity" : "Available",
            value: store.active.kind == .banking ? store.activity.count.formatted() : store.active.money(store.active.balance),
            symbol: store.active.kind == .banking ? "clock" : "banknote"
        )
    }

    private var trend: some View {
        let values: [Double] = range == "Today" ? [0.18, 0.22, 0.19, 0.38, 0.32, 0.55, 0.51, 0.68, 0.64, 0.88, 0.82, 1] : range == "7 days" ? [0.28, 0.48, 0.36, 0.75, 0.61, 0.9, 1] : [0.12, 0.28, 0.21, 0.42, 0.32, 0.67, 0.55, 0.78, 0.7, 1]
        return VStack(alignment: .leading, spacing: 16) {
            Text("The bigger picture").font(.headline)
            Chart(Array(values.enumerated()), id: \.offset) { item in
                AreaMark(x: .value("Period", item.offset), y: .value("Illustrative trend", item.element))
                    .foregroundStyle(LinearGradient(colors: [accent.opacity(0.22), accent.opacity(0.01)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Period", item.offset), y: .value("Illustrative trend", item.element))
                    .foregroundStyle(accent)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    .interpolationMethod(.monotone)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 140)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Illustrative trend for \(range)")
            .accessibilityValue("Increasing overall. This chart is not historical data.")
            Text("Illustrative trend · customize your totals with Edit")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol).font(.subheadline).foregroundStyle(.secondary)
            Text(value).font(.title3.bold()).monospacedDigit().minimumScaleFactor(0.65).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}

struct EventRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let event: SceneEvent
    let scene: StudioScene

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: event.kind.symbol)
                .foregroundStyle(accent)
                .frame(width: 44, height: 44)
                .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) { description; amountAndTime }
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                description
                Spacer(minLength: 4)
                amountAndTime
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .contain)
    }

    private var description: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title).font(.subheadline.weight(.semibold))
            Text(event.detail.isEmpty ? scene.name : event.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var displayedAmount: String {
        event.kind == .subscriber ? "+1" : scene.money(event.kind.isOutflow ? -event.amount : event.amount)
    }

    private var amountAndTime: some View {
        VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: 4) {
            Text(displayedAmount)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .accessibilityLabel(event.kind == .subscriber ? "One new subscriber" : displayedAmount)
            Text(event.date, style: .time).font(.caption2).foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private enum ComposerSheet: Identifiable {
    case savedCues
    case saveCue(NotificationPreset)
    case queue

    var id: String {
        switch self {
        case .savedCues: return "saved-cues"
        case .saveCue(let preset): return preset.id.uuidString
        case .queue: return "notification-queue"
        }
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
    @State private var composedSceneID: UUID?
    @State private var composedSceneKind: SceneKind?
    @State private var presentedSheet: ComposerSheet?
    private enum InputField: Hashable { case amount, details }
    @FocusState private var focusedInput: InputField?

    private var eventAmount: Double { kind == .subscriber ? 0.01 : Simulation.parseAmount(amount) ?? 0 }
    private var valid: Bool { (kind == .subscriber || Simulation.validAmount(eventAmount)) && detail.count <= 240 }
    private var preview: SceneEvent { SceneEvent(sceneID: store.activeID, kind: kind, amount: eventAmount, detail: detail) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    StudioLabel()
                    Text("Make a moment").font(.title.bold()).accessibilityAddTraits(.isHeader)
                    Text("Compose a milestone for \(store.active.name).")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Section {
                    Picker("Type", selection: $kind) {
                        ForEach(EventKind.allCases) { Text($0.title).tag($0) }
                    }
                    if kind != .subscriber {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Amount · \(store.active.currency)").font(.caption).foregroundStyle(.secondary)
                            TextField("Amount", text: $amount)
                                .keyboardType(.decimalPad)
                                .focused($focusedInput, equals: .amount)
                                .accessibilityLabel("Amount in \(store.active.currency)")
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Details").font(.caption).foregroundStyle(.secondary)
                        TextField("Details", text: $detail, axis: .vertical)
                            .lineLimit(2...4)
                            .focused($focusedInput, equals: .details)
                    }
                } header: {
                    Text("Event")
                } footer: {
                    if kind != .subscriber && !Simulation.validAmount(eventAmount) {
                        Text("Enter an amount between 0.01 and 1 billion. Use your decimal separator and omit grouping separators.")
                    }
                    if detail.count > 240 { Text("Keep event details to 240 characters or fewer.") }
                }
                Section("Preview") {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: store.active.kind.symbol)
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(accent, in: RoundedRectangle(cornerRadius: 12))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("REVERIE").font(.caption.bold())
                                Spacer()
                                Text("now").font(.caption).foregroundStyle(.secondary)
                            }
                            Text(kind.title).font(.headline)
                            Text(preview.body(scene: store.active)).font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .combine)
                    Text("iOS notifications always come from Reverie. Lock Screen appearance depends on your device settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Button {
                        focusedInput = nil
                        if store.emit(kind: kind, amount: eventAmount, detail: detail) != nil {
                            confirmation = "Added to your dashboard."
                        }
                    } label: {
                        Label("Add event to dashboard", systemImage: "plus.circle.fill")
                    }
                    .disabled(!valid || working)
                } footer: {
                    Text("Scheduled alerts are a separate performance cue and do not change dashboard totals.")
                }
                notificationSession
                savedCueSection
            }
            .navigationTitle("Studio")
            .scrollDismissesKeyboard(.interactively)
            .sheet(item: $presentedSheet) { destination in
                switch destination {
                case .savedCues:
                    SavedCuesView { preset in
                        loadPreset(preset)
                        presentedSheet = nil
                    }
                case .saveCue(let preset):
                    CuePresetEditor(preset: preset)
                case .queue:
                    QueuedAlertsView()
                }
            }
            .task(id: "\(store.activeID)-\(store.active.kind.rawValue)") {
                applyScenePreset()
                await store.refreshNotifications()
            }
            .alert("Ready", isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } })) {
                Button("OK") { confirmation = nil }
            } message: { Text(confirmation ?? "") }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedInput = nil }
                }
            }
        }
    }

    private var notificationSession: some View {
        Section("Notification session") {
            Stepper("\(count) notification\(count == 1 ? "" : "s")", value: $count, in: 1...20)
                .disabled(working)
            Picker("Start after", selection: $delay) {
                Text("5 seconds").tag(5.0)
                Text("30 seconds").tag(30.0)
                Text("1 minute").tag(60.0)
                Text("5 minutes").tag(300.0)
                if ![5.0, 30.0, 60.0, 300.0].contains(delay) {
                    Text(cueDelayLabel(delay)).tag(delay)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("notification-delay")
            .disabled(working)
            Text("Multiple alerts arrive 10 seconds apart.").font(.caption).foregroundStyle(.secondary)
            Button {
                cueNotifications()
            } label: {
                HStack {
                    Label("Cue notifications", systemImage: "bell.badge.fill")
                    Spacer()
                    if working { ProgressView().accessibilityLabel("Scheduling notifications") }
                }
            }
            .disabled(!valid || working)
            Button {
                presentedSheet = .queue
            } label: {
                LabeledContent("View queued alerts", value: store.pendingCount.formatted())
            }
            .accessibilityIdentifier("view-queued-alerts")
            .disabled(working)
            if store.pendingCount > 0 {
                LabeledContent("Queued", value: "\(store.pendingCount) alerts")
                    .foregroundStyle(.secondary)
                Button("Cancel \(store.pendingCount) queued alerts", role: .destructive) {
                    Task { await store.cancelNotifications() }
                }
                .disabled(working)
            }
        }
    }

    private var savedCueSection: some View {
        Section {
            if store.presets.isEmpty {
                Text("Save a setup to use again whenever the moment calls.")
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    focusedInput = nil
                    presentedSheet = .savedCues
                } label: {
                    LabeledContent("Saved cues", value: store.presets.count.formatted())
                }
                .accessibilityIdentifier("saved-cues")
                .disabled(working)
            }
            Button {
                focusedInput = nil
                presentedSheet = .saveCue(NotificationPreset(
                    name: kind.title, kind: kind, amount: eventAmount,
                    detail: detail, delay: delay, count: count
                ))
            } label: {
                Label("Save current cue", systemImage: "bookmark")
            }
            .accessibilityIdentifier("save-current-cue")
            .disabled(!valid || working || store.presets.count >= 50)
        } header: {
            Text("Your cues")
        } footer: {
            Text(store.presets.count >= 50
                 ? "You have 50 saved cues. Delete one to save another."
                 : "Saved cues remember the event, amount, details, timing, and alert count. Amounts use the active scene's currency.")
        }
    }

    private func loadPreset(_ preset: NotificationPreset) {
        focusedInput = nil
        kind = preset.kind
        amount = localizedEntry(preset.amount)
        detail = preset.detail
        delay = preset.delay
        count = preset.count
        composedSceneID = store.activeID
        composedSceneKind = store.active.kind
    }

    private func applyScenePreset() {
        guard composedSceneID != store.activeID || composedSceneKind != store.active.kind else { return }
        composedSceneID = store.activeID
        composedSceneKind = store.active.kind
        switch store.active.kind {
        case .commerce:
            kind = .order
            amount = localizedEntry(149)
            detail = "Everyday essentials · Order #1048"
        case .banking:
            kind = .deposit
            amount = localizedEntry(2500)
            detail = "Monthly income"
        case .creator:
            kind = .subscriber
            amount = localizedEntry(25)
            detail = "Someone new joined your world"
        }
    }

    private func cueNotifications() {
        focusedInput = nil
        working = true
        let queuedCount = count
        let queuedKind = kind
        let queuedAmount = eventAmount
        let queuedDetail = detail
        let queuedDelay = delay
        Task {
            let success = await store.schedule(kind: queuedKind, amount: queuedAmount, detail: queuedDetail, delay: queuedDelay, count: queuedCount)
            working = false
            if success {
                confirmation = "\(queuedCount) alert\(queuedCount == 1 ? "" : "s") queued. You can lock your phone or leave the app."
            }
        }
    }
}

struct ActivityView: View {
    @EnvironmentObject var store: StudioStore
    @State private var query = ""
    private var filtered: [SceneEvent] {
        store.activity.filter { query.isEmpty || "\($0.title) \($0.detail)".localizedCaseInsensitiveContains(query) }
    }
    private var grouped: [Date: [SceneEvent]] {
        Dictionary(grouping: filtered) { Calendar.current.startOfDay(for: $0.date) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Text(store.active.name).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    if filtered.isEmpty {
                        ContentUnavailableView(
                            query.isEmpty ? "No moments yet" : "No matching events",
                            systemImage: query.isEmpty ? "clock" : "magnifyingglass",
                            description: Text(query.isEmpty ? "Events you add to this scene appear here." : "Try another title or detail in this scene.")
                        )
                    }
                    ForEach(grouped.keys.sorted(by: >), id: \.self) { date in
                        Text(dayTitle(date))
                            .font(.headline)
                            .padding(.top, 10)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(grouped[date] ?? []) { event in
                            EventRow(event: event, scene: store.active)
                        }
                    }
                }
                .frame(maxWidth: 720, alignment: .leading)
                .padding(20)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Activity")
            .searchable(text: $query, prompt: "Search this scene")
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func dayTitle(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

struct SceneEditor: View {
    @EnvironmentObject var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @State var scene: StudioScene
    @State private var balance = ""
    @State private var sales = ""
    @State private var orders = ""
    @State private var audience = ""
    private enum InputField: Hashable { case name, balance, sales, orders, audience }
    @FocusState private var focusedInput: InputField?

    private var valid: Bool {
        !scene.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && scene.name.count <= 80
            && [Simulation.parseAmount(balance), Simulation.parseAmount(sales)].allSatisfy { value in
                value.map { $0.isFinite && $0 >= 0 && $0 <= 1_000_000_000 } ?? false
            }
            && wholeNumber(orders, maximum: 1_000_000) != nil
            && wholeNumber(audience, maximum: 100_000_000) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Scene name").font(.caption).foregroundStyle(.secondary)
                        TextField("Scene name", text: $scene.name).focused($focusedInput, equals: .name)
                    }
                    Picker("Dashboard", selection: $scene.kind) {
                        ForEach(SceneKind.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Currency", selection: $scene.currency) {
                        ForEach(StudioScene.currencies, id: \.self) { Text($0).tag($0) }
                    }
                } header: {
                    Text("Identity")
                } footer: {
                    if scene.name.count > 80 { Text("Keep your scene name to 80 characters or fewer.") }
                }
                Section {
                    numericField(title: "Available balance", placeholder: "Balance", text: $balance, currency: true, field: .balance)
                    numericField(title: scene.kind == .banking ? "Income" : "Sales / earnings", placeholder: "Sales / income", text: $sales, currency: true, field: .sales)
                    numericField(title: "Orders", placeholder: "Orders", text: $orders, currency: false, field: .orders)
                    numericField(title: "Audience", placeholder: "Audience", text: $audience, currency: false, field: .audience)
                } header: {
                    Text("Dashboard totals")
                } footer: {
                    Text("Use digits and your decimal separator without grouping separators. Amounts can be up to 1 billion, orders up to 1 million, and audience up to 100 million.")
                }
                Section {
                    Text("All values are fictional. Your scene is stored only on this device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Edit scene")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(!valid) }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedInput = nil }
                }
            }
            .onAppear {
                balance = localizedEntry(scene.balance)
                sales = localizedEntry(scene.sales)
                orders = localizedEntry(Double(scene.orders))
                audience = localizedEntry(Double(scene.audience))
            }
        }
    }

    private func numericField(title: String, placeholder: String, text: Binding<String>, currency: Bool, field: InputField) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(currency ? "\(title) · \(scene.currency)" : title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .keyboardType(currency ? .decimalPad : .numberPad)
                .focused($focusedInput, equals: field)
                .accessibilityLabel(currency ? "\(title) in \(scene.currency)" : title)
        }
    }

    private func wholeNumber(_ text: String, maximum: Int) -> Int? {
        guard let value = Simulation.parseAmount(text), value.isFinite,
              value >= 0, value <= Double(maximum), value.rounded(.down) == value else { return nil }
        return Int(value)
    }

    private func save() {
        guard valid else { return }
        scene.name = scene.name.trimmingCharacters(in: .whitespacesAndNewlines)
        scene.balance = Simulation.parseAmount(balance) ?? 0
        scene.sales = Simulation.parseAmount(sales) ?? 0
        scene.orders = wholeNumber(orders, maximum: 1_000_000) ?? 0
        scene.audience = wholeNumber(audience, maximum: 100_000_000) ?? 0
        if store.update(scene) { dismiss() }
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: StudioStore
    @AppStorage("appearance") private var appearance = "System"
    @State private var editing: StudioScene?
    @State private var importingFile = false
    @State private var exportingFile = false
    @State private var exportDocument: SessionFileDocument?
    @State private var pendingImport: Data?
    @State private var importedFilename = ""
    @State private var sessionBusy = false
    @State private var sessionFeedback: String?
    private enum SessionConfirmation: Equatable { case reset, replace }
    @State private var requestedConfirmation: SessionConfirmation?

    var body: some View {
        NavigationStack {
            Form {
                scenesSection
                experienceSection
                dataSection
                Section("About Reverie") {
                    StudioLabel()
                    Text("A private stage for fictional milestones. No accounts, real money, analytics tracking, or connections to financial services.")
                    Text("Not affiliated with Shopify or any bank. Notifications identify Reverie. Charts are illustrative.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Stored locally. Exported files and device backups may be stored by your chosen services.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    LabeledContent("Version", value: "1.0.0")
                }
            }
            .disabled(sessionBusy)
            .navigationTitle("Settings")
            .task { await store.refreshNotifications() }
            .sheet(item: $editing) { SceneEditor(scene: $0) }
            .fileImporter(isPresented: $importingFile, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first { prepareImport(from: url) }
                case .failure(let error):
                    reportFileError(error, action: "open this session")
                }
            }
            .fileExporter(isPresented: $exportingFile, document: exportDocument, contentType: .json, defaultFilename: "Reverie-session") { result in
                switch result {
                case .success:
                    sessionFeedback = "Your scenes, activity, and saved cues were exported."
                case .failure(let error):
                    reportFileError(error, action: "export this session")
                }
                exportDocument = nil
            }
            .confirmationDialog(
                requestedConfirmation == .reset ? "Reset all scenes and cancel every queued alert?" : "Replace your current session?",
                isPresented: Binding(
                    get: { requestedConfirmation != nil },
                    set: { if !$0 { requestedConfirmation = nil; pendingImport = nil } }
                ),
                titleVisibility: .visible
            ) {
                if requestedConfirmation == .reset {
                    Button("Reset everything", role: .destructive) { resetSession() }
                } else if let data = pendingImport {
                    Button("Replace session", role: .destructive) { importSession(data) }
                }
                Button("Cancel", role: .cancel) { pendingImport = nil }
            } message: {
                Text(requestedConfirmation == .reset
                     ? "This removes your scenes, activity, and saved cues, and restores the starter scenes."
                     : "Importing \(importedFilename) replaces your scenes, activity, and saved cues, and cancels all queued alerts.")
            }
            .alert("Your session", isPresented: Binding(get: { sessionFeedback != nil }, set: { if !$0 { sessionFeedback = nil } })) {
                Button("OK") { sessionFeedback = nil }
            } message: { Text(sessionFeedback ?? "") }
        }
    }

    private var scenesSection: some View {
        Section {
            ForEach(store.scenes) { scene in
                HStack(spacing: 12) {
                    Button { store.select(scene) } label: {
                        Label(scene.name, systemImage: scene.kind.symbol)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityHint(scene.id == store.activeID ? "Current dashboard" : "Switches your dashboard to this scene")
                    if scene.id == store.activeID {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(accent)
                            .accessibilityLabel("Selected")
                    }
                    Button { editing = scene } label: {
                        Image(systemName: "pencil").frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Edit \(scene.name)")
                }
                .swipeActions {
                    if store.scenes.count > 1 {
                        Button("Delete", role: .destructive) { store.delete(scene) }
                    }
                }
            }
            Button {
                editing = StudioScene(name: "Untitled scene", kind: .commerce, balance: 0, sales: 0, orders: 0, audience: 0)
            } label: { Label("New scene", systemImage: "plus") }
            .disabled(store.scenes.count >= 100)
        } header: {
            Text("Your scenes")
        } footer: {
            Text("Select a scene to switch dashboards. Swipe left to delete a scene and its activity.")
        }
    }

    private var experienceSection: some View {
        Section("Experience") {
            Picker("Appearance", selection: $appearance) {
                ForEach(["System", "Light", "Dark"], id: \.self) { Text($0).tag($0) }
            }
            LabeledContent("Notifications", value: store.notificationStatus)
            LabeledContent("Queued alerts", value: store.pendingCount.formatted())
            Button("Open iOS Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            Button("Cancel queued notifications", role: .destructive) {
                Task { await store.cancelNotifications() }
            }
            .disabled(store.pendingCount == 0)
        }
    }

    private var dataSection: some View {
        Section {
            Button {
                if let data = store.exportData() {
                    exportDocument = SessionFileDocument(data: data)
                    exportingFile = true
                }
            } label: { Label("Export session", systemImage: "square.and.arrow.up") }
            .accessibilityIdentifier("export-session")
            Button { importingFile = true } label: {
                Label("Import session", systemImage: "square.and.arrow.down")
            }
            .accessibilityIdentifier("import-session")
            Button("Reset all scenes", role: .destructive) { requestedConfirmation = .reset }
            if sessionBusy {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Updating your session…").foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        } header: {
            Text("Your data")
        } footer: {
            Text("Exports include your scenes, activity, and saved cues. Import a Reverie JSON file up to 2 MB to restore a session.")
        }
    }

    private func prepareImport(from url: URL) {
        sessionBusy = true
        importedFilename = url.lastPathComponent
        Task {
            do {
                let data = try await Task.detached(priority: .userInitiated) {
                    let bytes = try SessionFileDocument.readImport(from: url)
                    _ = try Archive.decode(bytes)
                    return bytes
                }.value
                pendingImport = data
                requestedConfirmation = .replace
            } catch {
                reportFileError(error, action: "open this session")
            }
            sessionBusy = false
        }
    }

    private func importSession(_ data: Data) {
        pendingImport = nil
        sessionBusy = true
        Task {
            if await store.importSession(data) { sessionFeedback = "Your session was imported. Queued alerts were cleared." }
            sessionBusy = false
        }
    }

    private func resetSession() {
        sessionBusy = true
        Task {
            await store.reset()
            sessionBusy = false
        }
    }

    private func reportFileError(_ error: Error, action: String) {
        if let cocoaError = error as? CocoaError, cocoaError.code == .userCancelled { return }
        store.error = "Could not \(action): \(error.localizedDescription)"
    }
}

private struct SessionFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        guard data.count <= Archive.maximumBytes else { throw ArchiveError.tooLarge }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
    static func readImport(from url: URL) throws -> Data {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = Data()
        while let chunk = try handle.read(upToCount: min(65_536, Archive.maximumBytes + 1 - data.count)), !chunk.isEmpty {
            data.append(chunk)
            guard data.count <= Archive.maximumBytes else { throw ArchiveError.tooLarge }
        }
        return data
    }
}

private struct SavedCuesView: View {
    @EnvironmentObject var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @State private var editing: NotificationPreset?
    var onApply: (NotificationPreset) -> Void

    var body: some View {
        NavigationStack {
            List {
                if store.presets.isEmpty {
                    ContentUnavailableView("No saved cues", systemImage: "bookmark", description: Text("Save a setup in Studio to use it again."))
                }
                ForEach(store.presets) { preset in
                    HStack(alignment: .center, spacing: 12) {
                        Button { onApply(preset) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(preset.name).font(.headline).foregroundStyle(.primary)
                                Text("\(preset.kind.title) · \(preset.count) alert\(preset.count == 1 ? "" : "s")")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                Text("Starts after \(cueDelayLabel(preset.delay))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(preset.name)
                        .accessibilityValue("\(preset.kind.title), \(preset.count) alerts after \(cueDelayLabel(preset.delay))")
                        .accessibilityHint("Loads this cue into Studio without scheduling it")
                        .accessibilityIdentifier("load-cue-\(preset.id.uuidString)")
                        Button { editing = preset } label: {
                            Image(systemName: "pencil").frame(width: 44, height: 44)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Edit \(preset.name)")
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) { store.deletePreset(preset) }
                    }
                }
            }
            .navigationTitle("Saved cues")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(item: $editing) { CuePresetEditor(preset: $0) }
        }
    }
}

private struct CuePresetEditor: View {
    @EnvironmentObject var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @State var preset: NotificationPreset
    @State private var amount = ""
    @State private var startAfter = ""
    private enum InputField: Hashable { case name, amount, details, delay }
    @FocusState private var focusedInput: InputField?

    private var prepared: NotificationPreset {
        var value = preset
        value.name = preset.name.trimmingCharacters(in: .whitespacesAndNewlines)
        value.detail = preset.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        value.amount = preset.kind == .subscriber ? 0.01 : Simulation.parseAmount(amount) ?? 0
        value.delay = Simulation.parseAmount(startAfter) ?? 0
        return value
    }
    private var valid: Bool { prepared.isValid && preset.name.count <= 60 && preset.detail.count <= 240 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Cue name", text: $preset.name)
                        .focused($focusedInput, equals: .name)
                        .accessibilityIdentifier("cue-name")
                } header: {
                    Text("Name")
                } footer: {
                    if preset.name.count > 60 { Text("Keep cue names to 60 characters or fewer.") }
                }
                Section {
                    Picker("Type", selection: $preset.kind) {
                        ForEach(EventKind.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                    if preset.kind != .subscriber {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Amount · \(store.active.currency)").font(.caption).foregroundStyle(.secondary)
                            TextField("Amount", text: $amount)
                                .keyboardType(.decimalPad)
                                .focused($focusedInput, equals: .amount)
                                .accessibilityLabel("Cue amount")
                        }
                    }
                    TextField("Details", text: $preset.detail, axis: .vertical)
                        .lineLimit(2...4)
                        .focused($focusedInput, equals: .details)
                } header: {
                    Text("Event")
                } footer: {
                    Text(preset.detail.count > 240
                         ? "Keep event details to 240 characters or fewer."
                         : "Amounts use the active scene's currency when you load this cue.")
                }
                Section {
                    Stepper("\(preset.count) notification\(preset.count == 1 ? "" : "s")", value: $preset.count, in: 1...20)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Start after · seconds").font(.caption).foregroundStyle(.secondary)
                        TextField("Seconds", text: $startAfter)
                            .keyboardType(.decimalPad)
                            .focused($focusedInput, equals: .delay)
                            .accessibilityLabel("Start after in seconds")
                    }
                } header: {
                    Text("Timing")
                } footer: {
                    Text("Start after 2 seconds to 24 hours. Multiple alerts arrive 10 seconds apart. Saving a cue does not schedule notifications.")
                }
            }
            .navigationTitle("Save cue")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        focusedInput = nil
                        if store.savePreset(prepared) { dismiss() }
                    }
                    .disabled(!valid)
                    .accessibilityIdentifier("save-cue")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedInput = nil }
                }
            }
            .onAppear {
                amount = localizedEntry(preset.amount)
                startAfter = localizedEntry(preset.delay)
            }
        }
    }
}

private struct QueuedAlertsView: View {
    @EnvironmentObject var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @State private var cancelling: Set<String> = []
    private var alerts: [QueuedAlert] {
        store.queuedAlerts.sorted {
            let first = $0.date ?? .distantFuture
            let second = $1.date ?? .distantFuture
            return first == second ? $0.id < $1.id : first < second
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if alerts.isEmpty {
                    ContentUnavailableView("Your queue is clear", systemImage: "bell", description: Text("Notifications you cue in Studio appear here until they are delivered."))
                }
                ForEach(alerts) { alert in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(alert.title).font(.headline)
                            Text(alert.body).font(.subheadline).foregroundStyle(.secondary)
                            if let sceneID = alert.sceneID,
                               let scene = store.scenes.first(where: { $0.id == sceneID }) {
                                Text(scene.name).font(.caption.weight(.semibold)).foregroundStyle(accent)
                            }
                            if let date = alert.date {
                                Text(date.formatted(date: .abbreviated, time: .standard))
                                    .font(.caption).foregroundStyle(.secondary)
                            } else {
                                Text("Delivery time set by iOS").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        Button(role: .destructive) {
                            cancelling.insert(alert.id)
                            Task {
                                await store.cancelAlert(alert)
                                cancelling.remove(alert.id)
                            }
                        } label: {
                            Group {
                                if cancelling.contains(alert.id) { ProgressView() }
                                else { Image(systemName: "xmark.circle.fill") }
                            }
                            .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.borderless)
                        .disabled(cancelling.contains(alert.id))
                        .accessibilityLabel("Cancel \(alert.title)")
                        .accessibilityIdentifier("cancel-alert-\(alert.id)")
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Queued alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .task { await store.refreshNotifications() }
            .refreshable { await store.refreshNotifications() }
        }
    }
}

private func cueDelayLabel(_ delay: Double) -> String {
    if delay >= 3600, delay.truncatingRemainder(dividingBy: 3600) == 0 {
        let hours = Int(delay / 3600)
        return "\(hours) hour\(hours == 1 ? "" : "s")"
    }
    if delay >= 60, delay.truncatingRemainder(dividingBy: 60) == 0 {
        let minutes = Int(delay / 60)
        return "\(minutes) minute\(minutes == 1 ? "" : "s")"
    }
    return "\(delay.formatted(.number.precision(.fractionLength(0...2)))) seconds"
}

private func localizedEntry(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.locale = .current
    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = false
    formatter.maximumFractionDigits = 16
    return formatter.string(from: NSNumber(value: value)) ?? String(value)
}

#Preview { RootView().environmentObject(StudioStore()) }
