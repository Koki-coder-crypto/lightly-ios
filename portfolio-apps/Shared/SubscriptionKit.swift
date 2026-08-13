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
    private var transactionUpdates: Task<Void, Never>?

    init(monthlyID: String, yearlyID: String) {
        self.monthlyID = monthlyID
        self.yearlyID = yearlyID
        transactionUpdates = Task { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self?.refresh()
            }
        }
        Task { await refresh() }
    }

    deinit { transactionUpdates?.cancel() }

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
        } catch { errorMessage = "Your purchase could not be completed. Please try again." }
    }

    func restore() async {
        do { try await AppStore.sync(); await refresh() }
        catch { errorMessage = "Your purchases could not be restored." }
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
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "sparkles").font(.system(size: 36)).foregroundStyle(.orange)
                        Text("Private by design").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    Text("\(name) Pro").font(.system(.largeTitle, design: .rounded, weight: .bold))
                    ForEach(benefits, id: \.self) { Label($0, systemImage: "checkmark.circle.fill").foregroundStyle(.primary) }
                    if subscription.products.isEmpty {
                        ProgressView("Loading plans…").frame(maxWidth: .infinity).padding()
                    } else {
                        ForEach(subscription.products, id: \.id) { product in
                            Button { Task { await subscription.purchase(product) } } label: {
                                HStack { VStack(alignment: .leading, spacing: 4) { Text(product.displayName).font(.headline); Text(detail(product)).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text(product.displayPrice).font(.headline) }
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(16)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(product.id == subscription.yearlyID ? .blue : .gray)
                            .disabled(subscription.isLoading)
                            .accessibilityHint(product.id == subscription.yearlyID ? "Recommended annual subscription" : "Monthly subscription")
                        }
                    }
                    Button("Restore purchases") { Task { await subscription.restore() } }.frame(maxWidth: .infinity)
                    Text("If eligible, Apple shows the trial period and renewal price before purchase. Payment is charged to your Apple ID and subscriptions can be managed or cancelled in App Store settings.").font(.caption).foregroundStyle(.secondary)
                    HStack { Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!); Link("Privacy Policy", destination: URL(string: "https://koki-coder-crypto.github.io/lightly-ios/portfolio/privacy.html")!) }.font(.caption)
                }
                .padding(24)
                .frame(maxWidth: 640, alignment: .leading)
                .background(Color(uiColor: .systemGroupedBackground))
            }
            .navigationTitle("Pro")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
            .alert("Purchase issue", isPresented: Binding(get: { subscription.errorMessage != nil }, set: { if !$0 { subscription.errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(subscription.errorMessage ?? "")
            }
        }
    }

    private func detail(_ product: Product) -> String {
        guard let offer = product.subscription?.introductoryOffer else { return product.description }
        return "\(offer.period.value) \(unit(offer.period.unit)) free trial, then \(product.displayPrice)/\(unit(product.subscription?.subscriptionPeriod.unit ?? .month))"
    }

    private func unit(_ unit: Product.SubscriptionPeriod.Unit) -> String {
        switch unit { case .day: "day"; case .week: "week"; case .month: "month"; case .year: "year"; @unknown default: "period" }
    }
}
