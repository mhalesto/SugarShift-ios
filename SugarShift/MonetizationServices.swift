import Foundation
import StoreKit

extension Notification.Name {
    static let storeKitCoinsDelivered = Notification.Name("SugarShift.storeKitCoinsDelivered")
    static let storeKitProductsLoaded = Notification.Name("SugarShift.storeKitProductsLoaded")
}

enum PurchaseOutcome {
    case delivered(coins: Int)
    case cancelled
    case pending
    case failed
}

@MainActor
final class StoreKitService {
    static let shared = StoreKitService()

    private var productsByID: [String: Product] = [:]
    private var transactionTask: Task<Void, Never>?

    private init() {}

    deinit {
        transactionTask?.cancel()
    }

    func startTransactionListener() {
        guard transactionTask == nil else { return }
        transactionTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.deliver(result)
            }
        }
    }

    func loadProducts() async {
        do {
            let products = try await Product.products(for: CoinProduct.allCases.map(\.rawValue))
            productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
            NotificationCenter.default.post(name: .storeKitProductsLoaded, object: nil)
        } catch {
            productsByID = [:]
            Analytics.track("storekit_load_failed", properties: ["error": "\(error)"])
        }
    }

    func displayPrice(for product: CoinProduct) -> String {
        productsByID[product.rawValue]?.displayPrice ?? product.fallbackPrice
    }

    func purchase(_ product: CoinProduct) async -> PurchaseOutcome {
        if productsByID.isEmpty {
            await loadProducts()
        }
        guard let storeProduct = productsByID[product.rawValue] else {
            Analytics.track("storekit_product_missing", properties: ["product": product.rawValue])
            return .failed
        }

        do {
            let result = try await storeProduct.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                let deliveredCoins = await deliver(transaction)
                return .delivered(coins: deliveredCoins)
            case .userCancelled:
                Analytics.track("storekit_purchase_cancelled", properties: ["product": product.rawValue])
                return .cancelled
            case .pending:
                Analytics.track("storekit_purchase_pending", properties: ["product": product.rawValue])
                return .pending
            @unknown default:
                Analytics.track("storekit_purchase_unknown", properties: ["product": product.rawValue])
                return .failed
            }
        } catch {
            Analytics.track("storekit_purchase_failed",
                            properties: ["product": product.rawValue,
                                         "error": "\(error)"])
            return .failed
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified(_, let error):
            throw error
        }
    }

    @discardableResult
    private func deliver(_ result: VerificationResult<Transaction>) async -> Int {
        do {
            let transaction = try checkVerified(result)
            return await deliver(transaction)
        } catch {
            Analytics.track("storekit_transaction_update_failed",
                            properties: ["error": "\(error)"])
            return 0
        }
    }

    @discardableResult
    private func deliver(_ transaction: Transaction) async -> Int {
        guard let product = CoinProduct(rawValue: transaction.productID) else {
            await transaction.finish()
            return 0
        }

        let transactionID = "\(transaction.id)"
        guard !Persistence.hasDeliveredStoreKitTransaction(transactionID) else {
            await transaction.finish()
            Analytics.track("storekit_transaction_duplicate_ignored",
                            properties: ["product": product.rawValue,
                                         "transaction": transactionID])
            return 0
        }

        Persistence.cash += product.coins
        Persistence.markStoreKitTransactionDelivered(transactionID)
        FirebaseBackendService.shared.recordStoreKitDelivery(transactionID: transactionID,
                                                             productID: product.rawValue,
                                                             coins: product.coins)
        notifyCoinsDelivered(product)
        Analytics.track("storekit_transaction_delivered",
                        properties: ["product": product.rawValue,
                                     "transaction": transactionID,
                                     "coins": "\(product.coins)"])
        await transaction.finish()
        return product.coins
    }

    private func notifyCoinsDelivered(_ product: CoinProduct) {
        NotificationCenter.default.post(name: .storeKitCoinsDelivered,
                                        object: nil,
                                        userInfo: ["coins": product.coins,
                                                   "product": product.rawValue])
    }
}

enum RewardedAdService {
    static var isAvailable: Bool { Monetization.rewardedAdsAvailable }

    static func showRewardedAd(reason: String, completion: @escaping (Bool) -> Void) {
        Analytics.track("rewarded_ad_requested", properties: ["reason": reason])
        #if DEBUG
        completion(true)
        #else
        completion(false)
        #endif
    }
}
