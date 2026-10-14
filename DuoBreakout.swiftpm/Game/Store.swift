import StoreKit
import SwiftUI

/// Product IDs. Each one must also be made in App Store Connect with the same ID.
enum StoreIDs {
    static let prefix = "com.ariberkowitz.duobreakout."

    static let skinRetro = prefix + "skin.retro"
    static let skinCandy = prefix + "skin.candy"
    static let skinSpace = prefix + "skin.space"
    static let skinLava = prefix + "skin.lava"
    static let skinGold = prefix + "skin.gold"
    static let levels = prefix + "levels"
    static let party = prefix + "party"
    static let allAccess = prefix + "all"
    static let tipSmall = prefix + "tip.small"
    static let tipBig = prefix + "tip.big"

    /// One-time unlocks. All Access counts as owning every one of them.
    static let unlocks = [skinRetro, skinCandy, skinSpace, skinLava, skinGold, levels, party, allAccess]
    static let tips = [tipSmall, tipBig]
    static let all = unlocks + tips
}

/// In-app purchases with StoreKit 2.
@MainActor
final class Store: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var owned: Set<String> = PurchaseCache.productIDs
    @Published private(set) var isLoading = true
    @Published private(set) var isRestoring = false
    @Published var message: String?

    private var updates: Task<Void, Never>?

    init() {
        updates = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                if case .verified(let transaction) = result {
                    PurchaseCache.record(transaction)
                    await transaction.finish()
                    await self?.refreshEntitlements()
                }
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    func owns(_ productID: String?) -> Bool {
        guard let productID else { return true }
        return owned.contains(productID) || owned.contains(StoreIDs.allAccess)
    }

    func owns(_ skin: Skin) -> Bool { owns(skin.productID) }

    var hasEverything: Bool { owned.contains(StoreIDs.allAccess) }

    func product(_ id: String) -> Product? {
        products.first { $0.id == id }
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: StoreIDs.all)
        } catch {
            products = []
        }
    }

    func buy(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(.verified(let transaction)):
                // Trust the transaction Apple just handed us, even if the
                // entitlement list hasn't caught up yet (common in TestFlight).
                PurchaseCache.record(transaction)
                await transaction.finish()
                await refreshEntitlements()
                if StoreIDs.tips.contains(product.id) {
                    message = "Thank you so much! 💛"
                } else {
                    message = "\(product.displayName) is unlocked. Have fun!"
                }
            case .success(.unverified(_, let error)):
                await refreshEntitlements()
                message = "The purchase went through, but Apple couldn't verify it (\(error.localizedDescription)). Try Restore Purchases."
            case .pending:
                message = "Your purchase is waiting for approval. It unlocks as soon as it's approved."
            case .userCancelled:
                break
            @unknown default:
                await refreshEntitlements()
            }
        } catch {
            message = "The App Store said: \(error.localizedDescription)"
        }
    }

    func restore() async {
        isRestoring = true
        defer { isRestoring = false }
        var syncError: Error?
        do {
            try await AppStore.sync()
        } catch {
            syncError = error
        }
        await refreshEntitlements()
        if !owned.isEmpty {
            let names = owned.map { id in product(id)?.displayName ?? id }
            message = "Restored: \(names.sorted().joined(separator: ", "))."
        } else if let syncError {
            message = "The App Store didn't answer (\(syncError.localizedDescription)). If you bought something, tap its price again: Apple won't charge twice."
        } else {
            message = "No purchases found for this Apple Account."
        }
    }

    /// Reads what this Apple Account owns.
    func refreshEntitlements() async {
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                PurchaseCache.record(transaction)
            }
        }
        for id in StoreIDs.unlocks where !PurchaseCache.productIDs.contains(id) {
            if case .verified(let transaction)? = await StoreKit.Transaction.latest(for: id) {
                PurchaseCache.record(transaction)
            }
        }
        let ids = PurchaseCache.productIDs
        if ids != owned { owned = ids }
    }
}

/// One-time unlocks this device has seen from verified transactions. An unlock stays
/// until Apple reports a refund, so a slow or empty entitlement list can't re-lock it.
enum PurchaseCache {
    private static let key = "ownedProductIDs"

    static var productIDs: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    static func record(_ transaction: StoreKit.Transaction) {
        // Tips are used up straight away. Only remember one-time unlocks.
        guard StoreIDs.unlocks.contains(transaction.productID) else { return }
        var ids = productIDs
        if transaction.revocationDate == nil {
            ids.insert(transaction.productID)
        } else {
            ids.remove(transaction.productID)
        }
        UserDefaults.standard.set(ids.sorted(), forKey: key)
    }
}
