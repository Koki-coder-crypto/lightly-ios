import StoreKit
import SwiftUI

@main
struct ReceiptSplitApp: App {
    @StateObject private var subscription = SubscriptionManager()
    var body: some Scene { WindowGroup { SplitView().environmentObject(subscription) } }
}

private enum AppSpec {
    static let name = "Receipt Split"
    static let freeLimit = 5
    static let monthlyID = "jp.egawa.receiptsplit.pro.monthly"
    static let yearlyID = "jp.egawa.receiptsplit.pro.yearly"
}

@MainActor
final class SplitStore: ObservableObject {
    struct Settlement: Identifiable, Codable {
        let id: UUID
        let title: String
        let total: Int
        let people: Int
        let createdAt: Date
        var perPerson: Int { Int(ceil(Double(total) / Double(people))) }
    }
    @Published var title = ""
    @Published var totalText = ""
    @Published var people = 2
    @Published private(set) var settlements: [Settlement] = []
    @Published var limitReached = false
    private let key = "jp.egawa.receiptsplit.settlements"

    init() { settlements = (try? JSONDecoder().decode([Settlement].self, from: UserDefaults.standard.data(forKey: key) ?? Data())) ?? [] }
    var total: Int? { Int(totalText.filter(\.isNumber)) }
    func save(isPro: Bool) {
        guard let total, total > 0 else { return }
        guard isPro || settlements.count < AppSpec.freeLimit else { limitReached = true; return }
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        settlements.insert(Settlement(id: UUID(), title: name.isEmpty ? "Settlement" : name, total: total, people: people, createdAt: .now), at: 0)
        title = ""; totalText = ""; people = 2; persist()
    }
    func remove(_ offsets: IndexSet) { settlements.remove(atOffsets: offsets); persist() }
    private func persist() { if let data = try? JSONEncoder().encode(settlements) { UserDefaults.standard.set(data, forKey: key) } }
}

struct SplitView: View {
    @StateObject private var store = SplitStore()
    @EnvironmentObject private var subscription: SubscriptionManager
    @State private var showPaywall = false
    var body: some View {
        NavigationStack { List {
            Section { Label("Calculate each person's share and save the result on this device.", systemImage: "yensign.circle.fill").font(.headline) }
            Section("New settlement") {
                TextField("Description (optional)", text: $store.title)
                TextField("Total amount", text: $store.totalText).keyboardType(.numberPad)
                Stepper("People: \(store.people)", value: $store.people, in: 2...30)
                if let total = store.total, total > 0 { LabeledContent("Per person") { Text("Yen \(Int(ceil(Double(total) / Double(store.people))))").font(.title3.bold()).foregroundStyle(.tint) } }
                Button("Save settlement") { store.save(isPro: subscription.isPro) }.buttonStyle(.borderedProminent).disabled(store.total == nil || store.total == 0)
            }
            Section("Saved settlements") {
                if store.settlements.isEmpty { Text("No saved settlements").foregroundStyle(.secondary) }
                ForEach(store.settlements) { item in
                    VStack(alignment: .leading, spacing: 5) { Text(item.title).font(.headline); Text("Total Yen \(item.total) | \(item.people) people | Yen \(item.perPerson) each").foregroundStyle(.secondary); Text(item.createdAt, style: .date).font(.caption).foregroundStyle(.tertiary) }
                }.onDelete(perform: store.remove)
            }
            if !subscription.isPro { Section { Button("See Pro") { showPaywall = true }; Text("The free version saves up to \(AppSpec.freeLimit) settlements.").font(.caption).foregroundStyle(.secondary) } }
        }.navigationTitle(AppSpec.name).sheet(isPresented: $showPaywall) { PaywallView() }.alert("Free limit reached", isPresented: $store.limitReached) { Button("See Pro") { showPaywall = true }; Button("Close", role: .cancel) {} } message: { Text("The free version saves up to \(AppSpec.freeLimit) settlements.") } }
    }
}

@MainActor
final class SubscriptionManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var isPro = false
    @Published var isLoading = false
    private var updates: Task<Void, Never>?
    init() { updates = Task { [weak self] in for await result in Transaction.updates { guard case .verified(let transaction) = result else { continue }; await transaction.finish(); await self?.refresh() } }; Task { await refresh() } }
    deinit { updates?.cancel() }
    func refresh() async { isPro = false; products = (try? await Product.products(for: [AppSpec.monthlyID, AppSpec.yearlyID]))?.sorted { $0.id == AppSpec.yearlyID && $1.id != AppSpec.yearlyID } ?? []; for await result in Transaction.currentEntitlements { if case .verified(let transaction) = result, [AppSpec.monthlyID, AppSpec.yearlyID].contains(transaction.productID) { isPro = true } } }
    func purchase(_ product: Product) async { isLoading = true; defer { isLoading = false }; do { guard case .success(let result) = try await product.purchase(), case .verified(let transaction) = result else { return }; await transaction.finish(); await refresh() } catch { } }
    func restore() async { try? await AppStore.sync(); await refresh() }
}

private struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscription: SubscriptionManager
    var body: some View { NavigationStack { VStack(alignment: .leading, spacing: 18) { Image(systemName: "sparkles").font(.largeTitle).foregroundStyle(.orange); Text("Receipt Split Pro").font(.largeTitle.bold()); Text("Save unlimited settlements."); ForEach(subscription.products, id: \.id) { product in Button { Task { await subscription.purchase(product) } } label: { HStack { VStack(alignment: .leading) { Text(product.displayName); Text(product.description).font(.caption) }; Spacer(); Text(product.displayPrice) }.frame(maxWidth: .infinity).padding() }.buttonStyle(.borderedProminent).disabled(subscription.isLoading) }; Button("Restore purchases") { Task { await subscription.restore() } }; Link("Privacy Policy", destination: URL(string: "https://koki-coder-crypto.github.io/lightly-ios/privacy.html")!); Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!); Text("Price, trial, and renewal terms are shown by the App Store before purchase. Manage or cancel in App Store account settings.").font(.caption).foregroundStyle(.secondary); Spacer() }.padding().navigationTitle("Pro").toolbar { Button("Close") { dismiss() } } } }
}
