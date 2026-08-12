import StoreKit
import SwiftUI

@main
struct AppMain: App {
    @StateObject private var subscription = SubscriptionManager()
    var body: some Scene { WindowGroup { DashboardView().environmentObject(subscription) } }
}

private enum AppSpec {
    static let name = "割り勘メモ"
    static let icon = "yensign.circle"
    static let job = "立替えた金額をすぐに公平に分けたい"
    static let free = "月5回の精算"
    static let pro = "無制限・履歴・定番グループ"
    static let action = "精算を作る"
    static let monthlyID = "jp.egawa.receiptsplit.pro.monthly"
    static let yearlyID = "jp.egawa.receiptsplit.pro.yearly"
}

@MainActor
final class UtilityStore: ObservableObject {
    @Published var title = ""
    @Published var detail = ""
    @Published private(set) var entries: [Entry] = []
    @Published var isRunning = false
    struct Entry: Identifiable, Codable { let id: UUID; let title: String; let detail: String; let createdAt: Date }
    private let key = "jp.egawa.receiptsplit.entries"
    init() { entries = (try? JSONDecoder().decode([Entry].self, from: UserDefaults.standard.data(forKey: key) ?? Data())) ?? [] }
    func save() {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        entries.insert(Entry(id: UUID(), title: cleaned, detail: detail.trimmingCharacters(in: .whitespacesAndNewlines), createdAt: .now), at: 0)
        title = ""; detail = ""
        if let data = try? JSONEncoder().encode(entries) { UserDefaults.standard.set(data, forKey: key) }
    }
    func remove(_ offsets: IndexSet) { entries.remove(atOffsets: offsets); if let data = try? JSONEncoder().encode(entries) { UserDefaults.standard.set(data, forKey: key) } }
}

struct DashboardView: View {
    @StateObject private var store = UtilityStore()
    @EnvironmentObject private var subscription: SubscriptionManager
    @State private var showPaywall = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label(AppSpec.job, systemImage: AppSpec.icon).font(.headline)
                    Text(subscription.isPro ? AppSpec.pro : AppSpec.free).font(.subheadline).foregroundStyle(.secondary)
                }
                Section("新しく追加") {
                    TextField("タイトル", text: $store.title)
                    TextField("補足・期限・相手など", text: $store.detail)
                    Button(AppSpec.action) { store.save() }.buttonStyle(.borderedProminent).disabled(store.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Section("履歴") {
                    if store.entries.isEmpty { Text("まだ記録はありません").foregroundStyle(.secondary) }
                    ForEach(store.entries) { entry in
                        VStack(alignment: .leading, spacing: 4) { Text(entry.title).font(.headline); if !entry.detail.isEmpty { Text(entry.detail).font(.subheadline).foregroundStyle(.secondary) }; Text(entry.createdAt, style: .date).font(.caption).foregroundStyle(.tertiary) }
                    }.onDelete(perform: store.remove)
                }
                if !subscription.isPro { Section { Button("Proの機能を見る") { showPaywall = true } } }
            }
            .navigationTitle(AppSpec.name)
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }
}

@MainActor
final class SubscriptionManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var isPro = false
    @Published var isLoading = false
    init() { Task { await refresh() } }
    func refresh() async {
        isPro = false
        products = (try? await Product.products(for: [AppSpec.monthlyID, AppSpec.yearlyID]))?.sorted { ($0.id == AppSpec.yearlyID ? 0 : 1) < ($1.id == AppSpec.yearlyID ? 0 : 1) } ?? []
        for await item in Transaction.currentEntitlements { if case .verified(let transaction) = item, [AppSpec.monthlyID, AppSpec.yearlyID].contains(transaction.productID) { isPro = true } }
    }
    func purchase(_ product: Product) async {
        isLoading = true; defer { isLoading = false }
        do {
            guard case .success(let result) = try await product.purchase(), case .verified(let transaction) = result else { return }
            await transaction.finish(); await refresh()
        } catch { }
    }
    func restore() async { try? await AppStore.sync(); await refresh() }
}

private struct PaywallView: View {
    @Environment(.dismiss) private var dismiss
    @EnvironmentObject private var subscription: SubscriptionManager
    var body: some View { NavigationStack { VStack(alignment: .leading, spacing: 20) {
        Image(systemName: "sparkles").font(.largeTitle).foregroundStyle(.orange)
        Text("\(AppSpec.name) Pro").font(.largeTitle.bold())
        Text(AppSpec.pro)
        ForEach(subscription.products, id: \.id) { product in Button { Task { await subscription.purchase(product) } } label: { HStack { VStack(alignment: .leading) { Text(product.displayName); Text(product.description).font(.caption) }; Spacer(); Text(product.displayPrice) }.frame(maxWidth: .infinity).padding() }.buttonStyle(.borderedProminent) }
        Button("購入を復元") { Task { await subscription.restore() } }
        Text("トライアルの期間と終了後の更新価格は購入前に表示されます。サブスクリプションはApple IDに請求され、App Storeの設定から管理・解約できます。").font(.caption).foregroundStyle(.secondary)
        Spacer()
    }.padding().navigationTitle("Pro").toolbar { Button("閉じる") { dismiss() } } } }
}
