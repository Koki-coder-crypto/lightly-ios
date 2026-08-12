import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    static let monthlyID = "jp.egawa.lightly.pro.monthly"
    static let yearlyID = "jp.egawa.lightly.pro.yearly"
    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro = false
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    private var updateTask: Task<Void, Never>?

    init() { updateTask = observeTransactions(); Task { await refresh() } }
    deinit { updateTask?.cancel() }

    func refresh() async {
        do { products = try await Product.products(for: [Self.monthlyID, Self.yearlyID]).sorted { $0.price < $1.price } }
        catch { products = [] }
        await refreshEntitlements()
    }
    func purchase(_ product: Product) async {
        isLoading = true; defer { isLoading = false }
        do {
            switch try await product.purchase() {
            case .success(let verification): let transaction = try checkedTransaction(verification); await transaction.finish(); await refreshEntitlements()
            case .userCancelled, .pending: break
            @unknown default: break
            }
        } catch { errorMessage = "購入を完了できませんでした。時間をおいてもう一度お試しください。" }
    }
    func restore() async {
        do { try await AppStore.sync(); await refreshEntitlements() }
        catch { errorMessage = "購入の復元ができませんでした。" }
    }
    private func observeTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await update in Transaction.updates {
                guard case .verified(let transaction) = update else { continue }
                await transaction.finish(); await self?.refreshEntitlements()
            }
        }
    }
    private func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkedTransaction(result) else { continue }
            if [Self.monthlyID, Self.yearlyID].contains(transaction.productID) { active = true }
        }
        isPro = active
    }
    private func checkedTransaction<T>(_ result: VerificationResult<T>) throws -> T {
        switch result { case .unverified: throw StoreError.failedVerification; case .verified(let transaction): return transaction }
    }
    private enum StoreError: Error { case failedVerification }
}
