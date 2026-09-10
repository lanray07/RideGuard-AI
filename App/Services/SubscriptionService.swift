import StoreKit
import Observation

@Observable @MainActor
final class SubscriptionService {
    static let productIDs = ["com.rideguard.pro.monthly", "com.rideguard.pro.annual"]
    private(set) var products: [Product] = []
    private(set) var hasPro = false
    private(set) var isLoading = false
    var error: String?
    private var listener: Task<Void, Never>?
    func start() async {
        guard listener == nil else { return }
        listener = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result, Self.productIDs.contains(transaction.productID) {
                    await transaction.finish()
                    await self?.refresh()
                }
            }
        }
        isLoading = true
        defer { isLoading = false }
        do { products = try await Product.products(for: Self.productIDs).sorted { $0.price < $1.price } }
        catch { self.error = error.localizedDescription }
        await refresh()
    }
    func refresh() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, Self.productIDs.contains(transaction.productID),
               transaction.revocationDate == nil, !transaction.isUpgraded,
               transaction.expirationDate.map({ $0 > .now }) ?? false { entitled = true }
        }
        hasPro = entitled
    }
    func purchase(_ product: Product) async {
        error = nil
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)): await transaction.finish(); await refresh()
            case .success(.unverified): error = "The purchase could not be verified. No access was changed."
            case .pending: error = "Purchase pending approval."
            case .userCancelled: break
            @unknown default: error = "Purchase status unavailable. Please restore purchases."
            }
        } catch { self.error = error.localizedDescription }
    }
    func restore() async {
        do { try await AppStore.sync(); await refresh() }
        catch { self.error = error.localizedDescription }
    }
}
