import Foundation

enum Economy {
    static let moveUnitCost = 24
    static let hammerCost = 88
    static let swapCost = 130
    static let lifeCost = 152
    /// Cost in coins to undo a move after the per-level free undo is spent.
    static let undoCost = 50
    static let livesBundleCost = 450
    static let shuffleBundleCost = 200
    static let hammerBundleCost = 400
    static let swapBundleCost = 600
    static let starterBundleCost = 520
    static let comboBundleCost = 920
    static let hardLevelBundleCost = 1_250
    static let coinDoublerCost = 700

    /// Cash a fresh install starts with. Single source of truth — read by
    /// Persistence and any scene that defaults a wallet.
    static let startingCash = 2_553

    /// Lives regenerate one at a time on a wall-clock timer. 25 min mirrors the
    /// genre standard so players "miss the game" by tomorrow morning.
    static let lifeRegenInterval: TimeInterval = 25 * 60
    static let livesMax = 6

    /// Piggy bank that fills as you play. Each match adds `piggyPerMatch`,
    /// capped at `piggyMax`. Once full the player can crack it for cash —
    /// either pay `piggyUnlockCost` or watch a rewarded ad.
    static let piggyPerMatch = 6
    static let piggyMax = 1_000
    static let piggyUnlockCost = 99   // store-tier cost when StoreKit lights up

    /// Time-limited coin doubler ("VIP day pass"). When active, every coin
    /// earned through play is multiplied. Bought from the shop.
    static let doublerHoursPerPurchase = 24
    static let doublerMultiplier = 2

    static func costForMoves(quantity: Int) -> Int {
        max(moveUnitCost, quantity * moveUnitCost)
    }
}

enum Monetization {
    static let rewardedAdCoins = 120
    static let rewardedContinueMoves = 5
    static let continueOfferMinLevel = 4
    static let continueOfferMinScoreRatio = 0.65
    static let rewardedAdCooldowns: [TimeInterval] = [
        5 * 60,
        30 * 60,
        60 * 60,
        2 * 60 * 60,
        4 * 60 * 60,
        8 * 60 * 60
    ]

    #if DEBUG
    static let rewardedAdsAvailable = true
    #else
    static let rewardedAdsAvailable = false
    #endif

    static let rewardedAdButtonText = "Watch"
    static let rewardedAdUnavailableButtonText = "Soon"
    static let rewardedAdSubtitle = "+\(rewardedAdCoins) coins"
    static let rewardedAdUnavailableSubtitle = "Ad rewards coming soon"

    static func rewardedAdCooldown(afterWatchCount count: Int) -> TimeInterval {
        guard count > 0 else { return 0 }
        let index = min(count - 1, rewardedAdCooldowns.count - 1)
        return rewardedAdCooldowns[index]
    }

    static func qualifiesForContinueOffer(level: Int,
                                          score: Int,
                                          target: Int,
                                          alreadyUsed: Bool) -> Bool {
        guard !alreadyUsed, level >= continueOfferMinLevel, target > 0 else { return false }
        return Double(score) / Double(target) >= continueOfferMinScoreRatio
    }

    static func coinPackButtonText(_ product: CoinProduct, displayPrice: String? = nil) -> String {
        displayPrice ?? product.fallbackPrice
    }

    static func coinPackSubtitle(_ product: CoinProduct) -> String {
        return "+\(product.coins) coins"
    }
}

enum CoinProduct: String, CaseIterable {
    case small = "com.currenttech.SugarShift.coins.small"
    case large = "com.currenttech.SugarShift.coins.large"

    var coins: Int {
        switch self {
        case .small: return 500
        case .large: return 5_000
        }
    }

    var analyticsName: String {
        switch self {
        case .small: return "coin_pack_small"
        case .large: return "coin_pack_large"
        }
    }

    var fallbackPrice: String {
        switch self {
        case .small: return "$0.99"
        case .large: return "$4.99"
        }
    }
}
