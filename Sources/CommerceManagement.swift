import SwiftUI

/// Manual inventory editing reuses the pictured thumbnail, quantity pill, and dark review action.
/// The public reference does not establish a camera scanner's interaction or permission states.
struct CommerceInventoryAdjustment: View {
    let sceneID: UUID
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @State private var counts: [UUID: Int] = [:]
    @State private var originalCounts: [UUID: Int] = [:]
    @State private var reviewing = false
    private var scene: StudioScene? { store.scenes.first { $0.id == sceneID } }
    private var products: [CommerceProduct] { store.commerceProfile(for: sceneID).products }
    private var changes: [CommerceProduct] {
        products.filter { product in counts[product.id].map { $0 != product.inventory } == true }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let scene {
                    ScrollView {
                        VStack(spacing: 14) {
                            if products.isEmpty {
                                ContentUnavailableView("No products", systemImage: "shippingbox", description: Text("Add products to manage their available inventory."))
                            } else {
                                ForEach(reviewing ? changes : products) { product in
                                    inventoryCard(product, scene: scene)
                                }
                            }
                            if let error = store.error { Text(error).font(.footnote).foregroundStyle(.red) }
                        }
                        .padding(16)
                    }
                    .background(Color(.systemGroupedBackground))
                    .safeAreaInset(edge: .bottom) {
                        Button(reviewing ? "Save inventory" : "Review inventory (\(changes.count))") {
                            if reviewing { save() } else { reviewing = true }
                        }
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(changes.isEmpty ? Color.gray : Color(red: 0.18, green: 0.18, blue: 0.18), in: RoundedRectangle(cornerRadius: 12))
                        .buttonStyle(.plain).disabled(changes.isEmpty)
                        .accessibilityIdentifier(reviewing ? "commerce-save-inventory" : "commerce-review-inventory")
                        .padding(16).background(Color(.systemBackground))
                    }
                } else { ContentUnavailableView("Store unavailable", systemImage: "bag") }
            }
            .navigationTitle(reviewing ? "Review inventory" : "Adjust inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(reviewing ? "Back" : "Cancel") {
                        if reviewing { reviewing = false } else { dismiss() }
                    }
                }
            }
        }
    }

    private func inventoryCard(_ product: CommerceProduct, scene: StudioScene) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: product.symbol).font(.system(size: 26)).foregroundStyle(.secondary)
                    .frame(width: 56, height: 56).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(product.title).font(.system(size: 16, weight: .semibold))
                    Text(scene.money(product.price)).font(.system(size: 14)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            if reviewing {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark").foregroundStyle(Color(red: 0.0, green: 0.46, blue: 0.38))
                    Text("\(product.inventory) → \(counts[product.id] ?? product.inventory) available")
                        .font(.system(size: 15)).foregroundStyle(Color(red: 0.0, green: 0.46, blue: 0.38))
                }
                .accessibilityLabel("\(product.title), from \(product.inventory) to \(counts[product.id] ?? product.inventory) available")
            } else {
                HStack {
                    Text("Available").font(.system(size: 14)).foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 0) {
                        Button { adjust(product, by: -1) } label: {
                            Image(systemName: "minus").frame(width: 44, height: 44)
                        }
                        .disabled((counts[product.id] ?? product.inventory) == 0)
                        .accessibilityLabel("Decrease \(product.title) inventory")
                        .accessibilityIdentifier("commerce-inventory-decrease-" + product.id.uuidString.lowercased())
                        Text((counts[product.id] ?? product.inventory).formatted())
                            .font(.system(size: 16, weight: .semibold)).monospacedDigit()
                            .frame(minWidth: 38).accessibilityLabel("\(counts[product.id] ?? product.inventory) available")
                            .accessibilityIdentifier("commerce-inventory-count-" + product.id.uuidString.lowercased())
                        Button { adjust(product, by: 1) } label: {
                            Image(systemName: "plus").frame(width: 44, height: 44)
                        }
                        .disabled((counts[product.id] ?? product.inventory) >= 1_000_000)
                        .accessibilityLabel("Increase \(product.title) inventory")
                        .accessibilityIdentifier("commerce-inventory-increase-" + product.id.uuidString.lowercased())
                    }
                    .font(.system(size: 18, weight: .medium)).buttonStyle(.plain)
                    .foregroundStyle(Color.primary)
                    .background(Color(.secondarySystemBackground), in: Capsule())
                }
            }
        }
        .padding(16).background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 19))
    }

    private func adjust(_ product: CommerceProduct, by delta: Int) {
        if originalCounts[product.id] == nil { originalCounts[product.id] = product.inventory }
        counts[product.id] = min(1_000_000, max(0, (counts[product.id] ?? product.inventory) + delta))
    }
    private func save() {
        let selected = changes
        guard !selected.isEmpty else { return }
        var profile = store.commerceProfile(for: sceneID)
        for product in selected {
            guard let index = profile.products.firstIndex(where: { $0.id == product.id }),
                  let original = originalCounts[product.id], profile.products[index].inventory == original,
                  let count = counts[product.id] else {
                store.error = "Inventory changed while you were editing. Close this sheet and review it again."
                return
            }
            profile.products[index].inventory = count
        }
        if store.updateCommerceProfile(profile) { dismiss() }
    }
}

/// In-scene access to the existing local notification scheduler and reusable cue presets.
/// It does not assert a Shopify notification-settings screen absent from the public references.
struct CommerceNotificationConfiguration: View {
    let sceneID: UUID
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @State private var style: NotificationStyle = .shopifyOrder
    @State private var amount = "149.00"
    @State private var detail = "Online Store"
    @State private var customer = ""
    @State private var items = 2
    @State private var orderNumber = ""
    @State private var customTitle = ""
    @State private var delay = 5.0
    @State private var count = 1
    @State private var interval = 10.0
    @State private var working = false
    @State private var result: String?
    @FocusState private var editing: Bool
    private var scene: StudioScene? { store.scenes.first { $0.id == sceneID } }
    private var amountRequired: Bool { style.isCustom ? detail.contains("{amount}") : style.usesAmount }
    private var eventAmount: Double { amountRequired ? Simulation.parseAmount(amount) ?? 0 : 0.01 }
    private var cleanCustomer: String? { optionalText(customer) }
    private var parsedOrder: Int? {
        guard let value = Simulation.parseAmount(orderNumber), value.rounded(.down) == value, (1...2_000_000).contains(value) else { return nil }
        return Int(value)
    }
    private var savedCues: [NotificationPreset] {
        store.presets.filter { ($0.style?.isAvailable(for: .commerce) ?? [.order, .refund, .payout].contains($0.kind)) }
    }
    private var valid: Bool {
        guard let scene, orderNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || parsedOrder != nil else { return false }
        return NotificationPlan.make(scene: scene, kind: style.eventKind, amount: eventAmount, detail: detail,
            delay: delay, count: count, pendingCount: 0, style: style, interval: interval,
            customerName: cleanCustomer, itemCount: items, orderNumber: parsedOrder, customTitle: optionalText(customTitle)) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                if let scene {
                    Section("Notification") {
                        Picker("Type", selection: $style) {
                            ForEach(NotificationStyle.allCases.filter { $0.isAvailable(for: .commerce) }) {
                                Text($0.name).tag($0)
                            }
                        }
                        .accessibilityIdentifier("commerce-notification-style")
                        if amountRequired {
                            TextField("\(style.amountLabel) in \(scene.currency)", text: $amount).keyboardType(.decimalPad).focused($editing)
                                .accessibilityIdentifier("commerce-notification-amount")
                        }
                        TextField("Details", text: $detail, axis: .vertical).lineLimit(2...4).focused($editing)
                            .accessibilityIdentifier("commerce-notification-details")
                        TextField("Title (optional)", text: $customTitle).focused($editing)
                            .accessibilityIdentifier("commerce-notification-title")
                    }
                    Section("Order details") {
                        TextField("Customer name (optional)", text: $customer).textContentType(.name).focused($editing)
                            .accessibilityIdentifier("commerce-notification-customer")
                        Stepper("\(items) \(items == 1 ? "item" : "items")", value: $items, in: 1...1000)
                            .accessibilityIdentifier("commerce-notification-items")
                        TextField("Order number (optional)", text: $orderNumber).keyboardType(.numberPad).focused($editing)
                            .accessibilityIdentifier("commerce-notification-order-number")
                    }
                    Section("Preview") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Reverie")
                                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Text(style.title(orderNumber: parsedOrder, customTitle: optionalText(customTitle))).font(.headline)
                            Text(style.body(scene: scene, amount: eventAmount, detail: detail,
                                customerName: cleanCustomer, itemCount: items, orderNumber: parsedOrder))
                                .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4).accessibilityElement(children: .combine)
                    }
                    Section {
                        Picker("Start after", selection: $delay) {
                            Text("5 seconds").tag(5.0)
                            Text("30 seconds").tag(30.0)
                            Text("1 minute").tag(60.0)
                            Text("5 minutes").tag(300.0)
                            if ![5.0, 30.0, 60.0, 300.0].contains(delay) { Text("\(Int(delay)) seconds").tag(delay) }
                        }
                        .accessibilityIdentifier("commerce-notification-delay")
                        Stepper("\(count) notification\(count == 1 ? "" : "s")", value: $count, in: 1...20)
                            .accessibilityIdentifier("commerce-notification-count")
                        if count > 1 {
                            Picker("Repeat interval", selection: $interval) {
                                ForEach([5.0, 10.0, 15.0, 30.0, 60.0], id: \.self) { Text("\(Int($0)) seconds").tag($0) }
                                if ![5.0, 10.0, 15.0, 30.0, 60.0].contains(interval) { Text("\(Int(interval)) seconds").tag(interval) }
                            }
                            .accessibilityIdentifier("commerce-notification-interval")
                        }
                        Button {
                            editing = false
                            Task { await schedule() }
                        } label: {
                            HStack {
                                Label("Cue notifications", systemImage: "bell.badge")
                                Spacer()
                                if working { ProgressView() }
                            }
                            .frame(minHeight: 44)
                        }
                        .disabled(!valid || working).accessibilityIdentifier("commerce-cue-notifications")
                    } header: { Text("Timing") } footer: {
                        Text("Scheduled alerts leave store totals unchanged. iOS uses this installed app’s name and icon.")
                    }
                    Section("Saved cues") {
                        Menu("Load template") {
                            ForEach(NotificationTemplate.templates(for: .commerce)) { template in
                                Button(template.name) { load(template) }
                            }
                        }
                        .accessibilityIdentifier("commerce-notification-templates")
                        if !savedCues.isEmpty {
                            Menu("Load saved cue") {
                                ForEach(savedCues) { preset in Button(preset.name) { load(preset) } }
                            }
                        }
                        Button("Save current cue") { saveCue() }.disabled(!valid || working)
                            .accessibilityIdentifier("commerce-notification-save-cue")
                    }
                    if let result { Section { Text(result).foregroundStyle(.secondary) } }
                    if let error = store.error { Section { Text(error).foregroundStyle(.red) } }
                } else { ContentUnavailableView("Store unavailable", systemImage: "bag") }
            }
            .navigationTitle("Configure notifications").navigationBarTitleDisplayMode(.inline)
            .disabled(working)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.disabled(working) }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { editing = false } }
            }
        }
    }

    private func optionalText(_ value: String) -> String? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }
    private func schedule() async {
        guard valid else { return }
        working = true
        defer { working = false }
        if await store.schedule(kind: style.eventKind, amount: eventAmount, detail: detail, delay: delay,
            count: count, style: style, interval: interval, customerName: cleanCustomer,
            itemCount: items, orderNumber: parsedOrder, customTitle: optionalText(customTitle), sceneID: sceneID) {
            result = "\(count) notification\(count == 1 ? "" : "s") queued."
        }
    }
    private func saveCue() {
        let preset = NotificationPreset(name: style.name, kind: style.eventKind, amount: eventAmount,
            detail: detail, delay: delay, count: count, style: style, interval: interval,
            customerName: cleanCustomer, itemCount: items, orderNumber: parsedOrder, customTitle: optionalText(customTitle))
        if store.savePreset(preset) { result = "Cue saved." }
    }
    private func load(_ preset: NotificationPreset) {
        style = preset.style ?? (preset.kind == .refund ? .shopifyRefund : preset.kind == .payout ? .shopifyPayout : .shopifyOrder)
        amount = preset.amount.formatted(.number.grouping(.never))
        detail = preset.detail
        customer = preset.customerName ?? ""
        items = preset.itemCount ?? 2
        orderNumber = preset.orderNumber.map(String.init) ?? ""
        customTitle = preset.customTitle ?? ""
        delay = preset.delay
        count = preset.count
        interval = preset.interval
        result = nil
    }
    private func load(_ template: NotificationTemplate) {
        style = template.style
        amount = template.amount.formatted(.number.grouping(.never))
        detail = template.detail
        customer = template.customerName ?? ""
        items = template.itemCount ?? 2
        orderNumber = template.orderNumber.map(String.init) ?? ""
        customTitle = template.customTitle ?? ""
        delay = template.delay
        count = template.count
        interval = template.interval
        result = nil
    }
}
