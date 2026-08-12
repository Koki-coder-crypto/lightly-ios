import StoreKit
import SwiftUI

/// A transparent, device-local free allowance. It resets at the beginning of each calendar month.
/// The app always shows the allowance before the user reaches a paywall.
enum FreeUsageQuota {
    static func remaining(namespace: String, limit: Int, now: Date = .now) -> Int {
        let defaults = UserDefaults.standard
        let monthKey = "\(namespace).freeUsage.month"
        let countKey = "\(namespace).freeUsage.count"
        let month = monthStamp(now)
        if defaults.string(forKey: monthKey) != month {
            defaults.set(month, forKey: monthKey)
            defaults.set(0, forKey: countKey)
        }
        return max(0, limit - defaults.integer(forKey: countKey))
    }

    @discardableResult
    static func consume(namespace: String, limit: Int, now: Date = .now) -> Bool {
        let remaining = remaining(namespace: namespace, limit: limit, now: now)
        guard remaining > 0 else { return false }
        let countKey = "\(namespace).freeUsage.count"
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: countKey) + 1, forKey: countKey)
        return true
    }

    private static func monthStamp(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)"
    }
}

@MainActor
final class SubscriptionManager: ObservableObject {
    let monthlyID: String
    let yearlyID: String
    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro = false
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    init(monthlyID: String, yearlyID: String) {
        self.monthlyID = monthlyID
        self.yearlyID = yearlyID
        Task { await refresh() }
    }

    func refresh() async {
        isPro = false
        products = (try? await Product.products(for: [monthlyID, yearlyID]))?.sorted {
            ($0.id == yearlyID ? 0 : 1) < ($1.id == yearlyID ? 0 : 1)
        } ?? []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if [monthlyID, yearlyID].contains(transaction.productID) { isPro = true }
        }
    }

    func purchase(_ product: Product) async {
        isLoading = true; defer { isLoading = false }
        do {
            guard case .success(let result) = try await product.purchase(), case .verified(let transaction) = result else { return }
            await transaction.finish()
            await refresh()
        } catch { errorMessage = "購入を完了できませんでした。時間をおいてもう一度お試しください。" }
    }

    func restore() async {
        do { try await AppStore.sync(); await refresh() }
        catch { errorMessage = "購入を復元できませんでした。" }
    }
}

struct SubscriptionPaywall: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscription: SubscriptionManager
    let name: String
    let benefits: [String]
    let privacyURL: URL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "sparkles").font(.system(size: 40)).foregroundStyle(.orange)
                    Text("\(name) Pro").font(.system(.largeTitle, design: .rounded, weight: .bold))
                    ForEach(benefits, id: \.self) { Label($0, systemImage: "checkmark.circle.fill").foregroundStyle(.primary) }
                    if subscription.products.isEmpty {
                        ProgressView("プランを読み込み中…").frame(maxWidth: .infinity).padding()
                    } else {
                        ForEach(subscription.products, id: \.id) { product in
                            Button { Task { await subscription.purchase(product) } } label: {
                                HStack { VStack(alignment: .leading, spacing: 4) { Text(product.displayName).font(.headline); Text(detail(product)).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text(product.displayPrice).font(.headline) }
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(16)
                            }.buttonStyle(.borderedProminent).tint(product.id == subscription.yearlyID ? .blue : .gray).disabled(subscription.isLoading)
                        }
                    }
                    Button("購入を復元") { Task { await subscription.restore() } }.frame(maxWidth: .infinity)
                    Text("トライアル対象の場合、期間と終了後の更新価格は購入前にAppleが表示します。お支払いはApple IDに請求され、App Storeの設定からいつでも管理・解約できます。").font(.caption).foregroundStyle(.secondary)
                    HStack { Link("利用規約", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!); Link("プライバシー", destination: privacyURL) }.font(.caption)
                }.padding(24)
            }.navigationTitle("Pro").toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } } }
        }
    }

    private func detail(_ product: Product) -> String {
        guard let offer = product.subscription?.introductoryOffer else { return product.description }
        return "\(offer.period.value) \(unit(offer.period.unit))無料トライアル後 \(product.displayPrice)/\(unit(product.subscription?.subscriptionPeriod.unit ?? .month))"
    }

    private func unit(_ unit: Product.SubscriptionPeriod.Unit) -> String {
        switch unit { case .day: "日"; case .week: "週"; case .month: "月"; case .year: "年"; @unknown default: "期間" }
    }
}
