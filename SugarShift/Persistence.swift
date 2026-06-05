import Foundation
import UIKit

/// Tiny `UserDefaults` wrapper for the persistent values we need to survive
/// app relaunches: current level, total score, wallet, lives, shuffle stock,
/// and the +Moves quantity preference.
enum Persistence {

    enum K {
        static let level         = "ss.currentLevel"
        static let totalScore    = "ss.totalScore"
        static let cash          = "ss.cash"
        static let lives         = "ss.lives"
        static let lifeRefAt     = "ss.lifeReferenceAt"
        static let shuffleCount  = "ss.shuffleCount"
        static let movesQuantity = "ss.movesQuantity"
        static let hammerCount   = "ss.hammerCount"
        static let swapCount     = "ss.swapCount"
        static let sound         = "ss.soundEnabled"
        static let music         = "ss.musicEnabled"
        static let haptics       = "ss.hapticsEnabled"
        static let reduceMotion  = "ss.reduceMotion"
        static let highContrast  = "ss.highContrast"
        static let largeText     = "ss.largeText"
        static let candyLabels   = "ss.candyLabels"
        static let shapedBoard   = "ss.shapedBoard"
        static let starsPrefix   = "ss.stars."
        static let claimedStarMilestone = "ss.claimedStarMilestone"
        static let hintPrefix    = "ss.hint."
        static let rewardPrefix  = "ss.reward."
        static let threeStarPrefix = "ss.threeStarReward."
        static let eventRewardPrefix = "ss.eventReward."
        static let bossRewardPrefix = "ss.bossReward."
        /// Bitmask of mastery medals earned for a level (0…7).
        /// Bit 0 = no-booster, bit 1 = moves-to-spare, bit 2 = goal-overshot.
        static let medalsPrefix  = "ss.medals."
        /// 1 = thumbs up, 2 = thumbs down. Absent = not yet rated.
        static let ratingPrefix  = "ss.rating."
        static let colorBlindPatterns = "ss.colorBlindPatterns"
        static let ghostPreview  = "ss.ghostPreview"
        static let dailyReward   = "ss.dailyRewardDate"
        static let dailyAdBonus  = "ss.dailyAdBonusDate"
        static let rewardedAdDate = "ss.rewardedAdDate"
        static let rewardedAdCount = "ss.rewardedAdCount"
        static let rewardedAdNextAt = "ss.rewardedAdNextAt"
        static let dailyStreak   = "ss.dailyStreak"
        static let themes        = "ss.unlockedThemes"
        static let piggyCoins    = "ss.piggyCoins"
        static let doublerExp    = "ss.coinDoublerExpiresAt"
        static let storeKitDeliveredTransactions = "ss.storeKitDeliveredTransactions"
        static let backendUpdatedAt = "ss.backendUpdatedAt"
        static let lastResetAt   = "ss.lastResetAt"
        static let resetLockActive = "ss.resetLockActive"
        static let pushAuthAsked = "ss.pushAuthRequested"
        static let gcOptIn       = "ss.gameCenterOptIn"
    }

    /// Whether the player has opted into Game Center sign-in. Defaults to true
    /// now that the target includes the Game Center entitlement; players can
    /// still turn it off from Settings.
    static var gameCenterOptIn: Bool {
        get { storedBool(K.gcOptIn, default: true) }
        set { d.set(newValue, forKey: K.gcOptIn) }
    }

    /// Keys whose value should round-trip through iCloud KVS so progress
    /// follows the player to a new device. Soft list — sync is a no-op when
    /// the iCloud entitlement isn't enabled in the project.
    static let cloudSyncedKeys: [String] = [
        K.level, K.totalScore, K.cash, K.lives, K.lifeRefAt,
        K.shuffleCount, K.hammerCount, K.swapCount,
        K.movesQuantity,
        K.dailyReward, K.dailyAdBonus, K.dailyStreak,
        K.rewardedAdDate, K.rewardedAdCount, K.rewardedAdNextAt,
        K.themes, K.piggyCoins, K.doublerExp,
        K.storeKitDeliveredTransactions,
        K.backendUpdatedAt,
        K.lastResetAt
    ]
    static let cloudSyncedPrefixes: [String] = [
        K.starsPrefix, K.rewardPrefix, K.threeStarPrefix, K.eventRewardPrefix, K.bossRewardPrefix,
        K.medalsPrefix, K.ratingPrefix
    ]

    private static let d = UserDefaults.standard

    private static var isResetLocked: Bool {
        d.bool(forKey: K.resetLockActive)
    }

    private static func cloudPush() {
        if d.bool(forKey: K.resetLockActive) {
            d.set(false, forKey: K.resetLockActive)
        }
        d.set(Date().timeIntervalSince1970, forKey: K.backendUpdatedAt)
        Cloud.push()
        FirebaseBackendService.shared.scheduleProgressSync()
    }

    /// Returns either the stored int for `key` or the supplied default if no
    /// value has ever been written. Avoids `integer(forKey:)`'s "always 0"
    /// problem on first launch.
    private static func storedInt(_ key: String, default fallback: Int) -> Int {
        if d.object(forKey: key) == nil { return fallback }
        return d.integer(forKey: key)
    }

    static var currentLevel: Int {
        get { isResetLocked ? 1 : max(1, storedInt(K.level, default: 1)) }
        set {
            d.set(max(1, min(newValue, Levels.count)), forKey: K.level)
            cloudPush()
        }
    }

    static var totalScore: Int {
        get { isResetLocked ? 0 : storedInt(K.totalScore, default: 0) }
        set {
            d.set(newValue, forKey: K.totalScore)
            cloudPush()
        }
    }

    static var cash: Int {
        get { isResetLocked ? Economy.startingCash : storedInt(K.cash, default: Economy.startingCash) }
        set {
            d.set(newValue, forKey: K.cash)
            cloudPush()
        }
    }

    // MARK: - Lives (wall-clock regen)

    /// Lives are stored as a `(baseline, referenceAt)` pair. The materialized
    /// value at any point in time is `baseline + floor((now - ref) / interval)`,
    /// capped at `Economy.livesMax`. Doing the math at read time means the
    /// timer keeps running while the app is closed.
    static var lives: Int {
        get { isResetLocked ? Economy.livesMax : LifeState.load().materialized(at: Date()) }
        set {
            let now = Date()
            let state = LifeState.load()
            let current = state.materialized(at: now)
            let target = max(0, min(Economy.livesMax, newValue))
            guard target != current else { return }

            if target >= Economy.livesMax {
                LifeState(baseline: Economy.livesMax, referenceAt: nil).save()
                return
            }

            // Preserve partial-tick progress: snap reference to the most recent
            // completed regen tick, so neither losing nor gaining a life resets
            // the countdown the player can already see.
            let snappedRef: Date
            if let ref = state.referenceAt {
                let ticks = Int(max(0, now.timeIntervalSince(ref)) / Economy.lifeRegenInterval)
                snappedRef = ref.addingTimeInterval(Double(ticks) * Economy.lifeRegenInterval)
            } else {
                snappedRef = now
            }
            LifeState(baseline: target, referenceAt: snappedRef).save()
        }
    }

    /// Seconds until the next life refills, or 0 when at max.
    static var secondsUntilNextLife: TimeInterval {
        guard let next = LifeState.load().nextLifeAt(at: Date()) else { return 0 }
        return max(0, next.timeIntervalSinceNow)
    }

    /// "5:32" style countdown for the HUD next to the lives heart.
    static var nextLifeCountdownText: String {
        let s = Int(secondsUntilNextLife.rounded(.up))
        guard s > 0 else { return "" }
        let m = s / 60
        let r = s % 60
        return String(format: "%d:%02d", m, r)
    }

    private struct LifeState {
        let baseline: Int
        let referenceAt: Date?

        func materialized(at now: Date) -> Int {
            guard baseline < Economy.livesMax, let ref = referenceAt else { return baseline }
            let ticks = Int(max(0, now.timeIntervalSince(ref)) / Economy.lifeRegenInterval)
            return min(Economy.livesMax, baseline + ticks)
        }

        func nextLifeAt(at now: Date) -> Date? {
            guard baseline < Economy.livesMax, let ref = referenceAt else { return nil }
            let elapsed = max(0, now.timeIntervalSince(ref))
            let ticks = Int(elapsed / Economy.lifeRegenInterval)
            return ref.addingTimeInterval(Double(ticks + 1) * Economy.lifeRegenInterval)
        }

        static func load() -> LifeState {
            let raw = max(0, min(Economy.livesMax, storedInt(K.lives, default: 5)))
            if raw >= Economy.livesMax { return LifeState(baseline: Economy.livesMax, referenceAt: nil) }
            let ref = (Persistence.d.object(forKey: K.lifeRefAt) as? Date) ?? Date()
            return LifeState(baseline: raw, referenceAt: ref)
        }

        func save() {
            Persistence.d.set(baseline, forKey: K.lives)
            if let ref = referenceAt, baseline < Economy.livesMax {
                Persistence.d.set(ref, forKey: K.lifeRefAt)
            } else {
                Persistence.d.removeObject(forKey: K.lifeRefAt)
            }
            Persistence.cloudPush()
        }
    }

    static var shuffleCount: Int {
        get { isResetLocked ? 2 : storedInt(K.shuffleCount, default: 2) }
        set {
            d.set(newValue, forKey: K.shuffleCount)
            cloudPush()
        }
    }

    static var movesQuantity: Int {
        get { isResetLocked ? 5 : storedInt(K.movesQuantity, default: 5) }
        set {
            d.set(newValue, forKey: K.movesQuantity)
            cloudPush()
        }
    }

    static var hammerCount: Int {
        get { isResetLocked ? 0 : storedInt(K.hammerCount, default: 0) }
        set {
            d.set(newValue, forKey: K.hammerCount)
            cloudPush()
        }
    }

    static var swapCount: Int {
        get { isResetLocked ? 0 : storedInt(K.swapCount, default: 0) }
        set {
            d.set(newValue, forKey: K.swapCount)
            cloudPush()
        }
    }

    // MARK: - Piggy bank (fills with play, cracks for cash)

    static var piggyCoins: Int {
        get { isResetLocked ? 0 : max(0, min(Economy.piggyMax, storedInt(K.piggyCoins, default: 0))) }
        set {
            d.set(max(0, min(Economy.piggyMax, newValue)), forKey: K.piggyCoins)
            cloudPush()
        }
    }

    static var piggyIsFull: Bool { piggyCoins >= Economy.piggyMax }

    static func addToPiggy(_ amount: Int) {
        guard amount > 0 else { return }
        piggyCoins = min(Economy.piggyMax, piggyCoins + amount)
    }

    /// Empties the piggy and returns the prior balance (caller credits cash).
    static func emptyPiggy() -> Int {
        let pot = piggyCoins
        piggyCoins = 0
        return pot
    }

    // MARK: - Coin doubler day pass

    static var coinDoublerExpiresAt: Date? {
        get { isResetLocked ? nil : d.object(forKey: K.doublerExp) as? Date }
        set {
            if let newValue { d.set(newValue, forKey: K.doublerExp) }
            else { d.removeObject(forKey: K.doublerExp) }
            cloudPush()
        }
    }

    static var coinDoublerActive: Bool {
        guard let exp = coinDoublerExpiresAt else { return false }
        return exp.timeIntervalSinceNow > 0
    }

    static var coinDoublerCountdownText: String {
        guard let exp = coinDoublerExpiresAt else { return "" }
        let seconds = Int(exp.timeIntervalSinceNow.rounded(.up))
        guard seconds > 0 else { return "" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(max(1, minutes))m"
    }

    /// Coins to credit after applying the doubler if it's active.
    static func applyCoinDoubler(_ base: Int) -> Int {
        coinDoublerActive ? base * Economy.doublerMultiplier : base
    }

    /// Extends the doubler — adds hours to the current expiry, or starts from
    /// now. Lets a player stack multiple day passes.
    static func extendCoinDoubler(hours: Int = Economy.doublerHoursPerPurchase) {
        guard hours > 0 else { return }
        let from = (coinDoublerExpiresAt ?? Date()).timeIntervalSinceNow > 0
            ? (coinDoublerExpiresAt ?? Date())
            : Date()
        coinDoublerExpiresAt = from.addingTimeInterval(TimeInterval(hours) * 3600)
    }

    // MARK: - StoreKit delivery ledger

    static func hasDeliveredStoreKitTransaction(_ id: String) -> Bool {
        guard !isResetLocked else { return false }
        return deliveredStoreKitTransactionIDs.contains(id)
    }

    static func markStoreKitTransactionDelivered(_ id: String) {
        var ids = deliveredStoreKitTransactionIDs
        guard ids.insert(id).inserted else { return }
        d.set(Array(ids).sorted(), forKey: K.storeKitDeliveredTransactions)
        cloudPush()
    }

    private static var deliveredStoreKitTransactionIDs: Set<String> {
        guard !isResetLocked else { return [] }
        return Set(d.stringArray(forKey: K.storeKitDeliveredTransactions) ?? [])
    }

    static var deliveredStoreKitTransactionIDList: [String] {
        Array(deliveredStoreKitTransactionIDs).sorted()
    }

    private static func storedBool(_ key: String, default fallback: Bool) -> Bool {
        if d.object(forKey: key) == nil { return fallback }
        return d.bool(forKey: key)
    }

    static var soundEnabled: Bool {
        get { storedBool(K.sound, default: true) }
        set { d.set(newValue, forKey: K.sound) }
    }
    static var musicEnabled: Bool {
        get { storedBool(K.music, default: true) }
        set { d.set(newValue, forKey: K.music) }
    }
    static var hapticsEnabled: Bool {
        get { storedBool(K.haptics, default: true) }
        set { d.set(newValue, forKey: K.haptics) }
    }
    static var reduceMotion: Bool {
        get { storedBool(K.reduceMotion, default: false) || UIAccessibility.isReduceMotionEnabled }
        set { d.set(newValue, forKey: K.reduceMotion) }
    }
    static var highContrast: Bool {
        get { storedBool(K.highContrast, default: false) || UIAccessibility.isDarkerSystemColorsEnabled }
        set { d.set(newValue, forKey: K.highContrast) }
    }
    static var largeText: Bool {
        get { storedBool(K.largeText, default: false) || UIAccessibility.isBoldTextEnabled }
        set { d.set(newValue, forKey: K.largeText) }
    }
    static var candyLabels: Bool {
        get { storedBool(K.candyLabels, default: false) }
        set { d.set(newValue, forKey: K.candyLabels) }
    }
    /// Geometric pattern overlay per color (color-blind aid). Independent of
    /// high-contrast/large-text — patterns are about identifying *which* color
    /// rather than reading text.
    static var colorBlindPatterns: Bool {
        get { storedBool(K.colorBlindPatterns, default: false) }
        set { d.set(newValue, forKey: K.colorBlindPatterns) }
    }
    /// Faded outline of tiles that would clear on release of the current drag.
    /// Defaults on — helps new players see the cause/effect of a swap. Veterans
    /// can disable from Settings.
    static var ghostPreview: Bool {
        get { storedBool(K.ghostPreview, default: true) }
        set { d.set(newValue, forKey: K.ghostPreview) }
    }
    /// When true, hide the dark rectangular board backdrop so the level scene
    /// shows through the empty corners on irregular layouts.
    static var shapedBoard: Bool {
        get { storedBool(K.shapedBoard, default: true) }
        set { d.set(newValue, forKey: K.shapedBoard) }
    }

    // MARK: - Per-level stars

    /// Returns 0...3 stars earned on the given level (0 = never won).
    static func starsForLevel(_ n: Int) -> Int {
        guard !isResetLocked else { return 0 }
        return storedInt(K.starsPrefix + "\(n)", default: 0)
    }

    /// Records stars only if the new value is strictly better than what's stored.
    static func recordStars(_ stars: Int, for level: Int) {
        let current = starsForLevel(level)
        if stars > current {
            d.set(stars, forKey: K.starsPrefix + "\(level)")
            cloudPush()
        }
    }

    /// Total best stars earned across the whole campaign (0...3 per level).
    static var totalStars: Int {
        guard !isResetLocked else { return 0 }
        return (1...max(1, Levels.count)).reduce(0) { $0 + starsForLevel($1) }
    }

    /// Long-term star reward track: every `starMilestoneStep` total stars pays a
    /// coin bonus, giving 3-starring a lasting purpose beyond the leaderboard.
    static let starMilestoneStep = 25
    static var claimedStarMilestone: Int {
        get { storedInt(K.claimedStarMilestone, default: 0) }
        set { d.set(newValue, forKey: K.claimedStarMilestone); cloudPush() }
    }

    // MARK: - Per-level mastery medals

    struct MedalSet: Equatable {
        var noBoosters: Bool
        var movesToSpare: Bool
        var overshotGoal: Bool

        static let none = MedalSet(noBoosters: false, movesToSpare: false, overshotGoal: false)

        var count: Int {
            (noBoosters ? 1 : 0) + (movesToSpare ? 1 : 0) + (overshotGoal ? 1 : 0)
        }

        var bitmask: Int {
            (noBoosters    ? 1 : 0)
            | (movesToSpare ? 2 : 0)
            | (overshotGoal ? 4 : 0)
        }

        init(noBoosters: Bool, movesToSpare: Bool, overshotGoal: Bool) {
            self.noBoosters = noBoosters
            self.movesToSpare = movesToSpare
            self.overshotGoal = overshotGoal
        }

        init(bitmask: Int) {
            self.noBoosters    = (bitmask & 1) != 0
            self.movesToSpare  = (bitmask & 2) != 0
            self.overshotGoal  = (bitmask & 4) != 0
        }
    }

    static func medalsForLevel(_ n: Int) -> MedalSet {
        guard !isResetLocked else { return .none }
        return MedalSet(bitmask: storedInt(K.medalsPrefix + "\(n)", default: 0))
    }

    /// Merges any newly-earned medals into the stored set (bitwise OR), so
    /// a one-off no-booster win is preserved even if a later attempt used one.
    static func recordMedals(_ medals: MedalSet, for level: Int) {
        let current = medalsForLevel(level)
        let merged = MedalSet(noBoosters:   current.noBoosters   || medals.noBoosters,
                              movesToSpare: current.movesToSpare || medals.movesToSpare,
                              overshotGoal: current.overshotGoal || medals.overshotGoal)
        if merged != current {
            d.set(merged.bitmask, forKey: K.medalsPrefix + "\(level)")
            cloudPush()
        }
    }

    // MARK: - Per-level rating (thumbs up/down)

    enum LevelRating: Int {
        case thumbsUp = 1
        case thumbsDown = 2
    }

    static func ratingForLevel(_ n: Int) -> LevelRating? {
        guard !isResetLocked else { return nil }
        let raw = storedInt(K.ratingPrefix + "\(n)", default: 0)
        return LevelRating(rawValue: raw)
    }

    static func recordRating(_ rating: LevelRating, for level: Int) {
        d.set(rating.rawValue, forKey: K.ratingPrefix + "\(level)")
        cloudPush()
    }

    /// Highest level the player can play. Equals max(currentLevel, 1 + highest level with stars).
    /// All N <= this value are unlocked; N > this value are locked.
    static var highestUnlockedLevel: Int {
        var hi = currentLevel
        for n in 1...Levels.count {
            if starsForLevel(n) > 0 {
                hi = max(hi, n + 1)
            }
        }
        return hi
    }

    static func hasSeenHint(_ key: String) -> Bool {
        storedBool(K.hintPrefix + key, default: false)
    }

    static func markHintSeen(_ key: String) {
        d.set(true, forKey: K.hintPrefix + key)
    }

    static func hasClaimedMilestoneReward(for level: Int) -> Bool {
        guard !isResetLocked else { return false }
        return storedBool(K.rewardPrefix + "\(level)", default: false)
    }

    static func markMilestoneRewardClaimed(for level: Int) {
        d.set(true, forKey: K.rewardPrefix + "\(level)")
        cloudPush()
    }

    static func hasClaimedThreeStarReward(for level: Int) -> Bool {
        guard !isResetLocked else { return false }
        return storedBool(K.threeStarPrefix + "\(level)", default: false)
    }

    static func markThreeStarRewardClaimed(for level: Int) {
        d.set(true, forKey: K.threeStarPrefix + "\(level)")
        cloudPush()
    }

    static func hasClaimedBossReward(for level: Int) -> Bool {
        guard !isResetLocked else { return false }
        return storedBool(K.bossRewardPrefix + "\(level)", default: false)
    }

    static func markBossRewardClaimed(for level: Int) {
        d.set(true, forKey: K.bossRewardPrefix + "\(level)")
        cloudPush()
    }

    static func hasClaimedEventReward(_ eventID: String) -> Bool {
        guard !isResetLocked else { return false }
        return storedBool(K.eventRewardPrefix + eventID, default: false)
    }

    static func markEventRewardClaimed(_ eventID: String) {
        d.set(true, forKey: K.eventRewardPrefix + eventID)
        cloudPush()
    }

    static func claimedEventRewardIDs() -> [String] {
        guard !isResetLocked else { return [] }
        return d.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(K.eventRewardPrefix) && d.bool(forKey: $0) }
            .map { String($0.dropFirst(K.eventRewardPrefix.count)) }
            .sorted()
    }

    static func threeStarLevelCount() -> Int {
        (1...Levels.count).filter { starsForLevel($0) == 3 }.count
    }

    static func crownLevelCount() -> Int {
        (100...Levels.count).filter { starsForLevel($0) > 0 }.count
    }

    static func grantDesignerBoosters() {
        cash += 5_000
        lives = max(lives, 6)
        shuffleCount += 10
        hammerCount += 10
        swapCount += 10
        cloudPush()
    }

    static func resetDailyAndEventState() {
        for key in d.dictionaryRepresentation().keys where key.hasPrefix(K.eventRewardPrefix) {
            d.removeObject(forKey: key)
        }
        d.removeObject(forKey: K.dailyReward)
        d.removeObject(forKey: K.dailyAdBonus)
        d.removeObject(forKey: K.rewardedAdDate)
        d.removeObject(forKey: K.rewardedAdCount)
        d.removeObject(forKey: K.rewardedAdNextAt)
        d.removeObject(forKey: K.dailyStreak)
        cloudPush()
    }

    static func hasClaimedDailyReward(_ dateKey: String) -> Bool {
        guard !isResetLocked else { return false }
        return d.string(forKey: K.dailyReward) == dateKey
    }

    static func markDailyRewardClaimed(_ dateKey: String) {
        updateDailyStreak(for: dateKey)
        d.set(dateKey, forKey: K.dailyReward)
        cloudPush()
    }

    static func hasClaimedDailyAdBonus(_ dateKey: String) -> Bool {
        guard !isResetLocked else { return false }
        return d.string(forKey: K.dailyAdBonus) == dateKey
    }

    static func markDailyAdBonusClaimed(_ dateKey: String) {
        d.set(dateKey, forKey: K.dailyAdBonus)
        cloudPush()
    }

    struct RewardedAdGate {
        let watchedToday: Int
        let secondsRemaining: TimeInterval
        let progress: CGFloat

        var isAvailable: Bool { secondsRemaining <= 0 }
        var countdownText: String { Persistence.compactDuration(secondsRemaining) }
    }

    static func rewardedAdGate(now: Date = Date()) -> RewardedAdGate {
        normalizeRewardedAdGate(now: now)
        let watched = max(0, d.integer(forKey: K.rewardedAdCount))
        let nextAt = d.object(forKey: K.rewardedAdNextAt) as? Date
        let remaining = max(0, nextAt?.timeIntervalSince(now) ?? 0)
        let cooldown = max(1, Monetization.rewardedAdCooldown(afterWatchCount: watched))
        let progress = remaining <= 0
            ? 1
            : CGFloat(max(0.04, min(0.98, 1 - remaining / cooldown)))
        return RewardedAdGate(watchedToday: watched,
                              secondsRemaining: remaining,
                              progress: progress)
    }

    static func recordRewardedAdWatched(now: Date = Date()) {
        normalizeRewardedAdGate(now: now)
        let watched = max(0, d.integer(forKey: K.rewardedAdCount)) + 1
        let cooldown = Monetization.rewardedAdCooldown(afterWatchCount: watched)
        let resetAt = nextDailyReset(after: now)
        let rawNextAt = now.addingTimeInterval(cooldown)
        let nextAt = rawNextAt < resetAt ? rawNextAt : resetAt
        d.set(dateKey(for: now), forKey: K.rewardedAdDate)
        d.set(watched, forKey: K.rewardedAdCount)
        d.set(nextAt, forKey: K.rewardedAdNextAt)
        cloudPush()
    }

    static func secondsUntilDailyReset(now: Date = Date()) -> TimeInterval {
        max(0, nextDailyReset(after: now).timeIntervalSince(now))
    }

    static func dailyResetCountdownText(now: Date = Date()) -> String {
        compactDuration(secondsUntilDailyReset(now: now))
    }

    static func dailyResetProgress(now: Date = Date()) -> CGFloat {
        let remaining = secondsUntilDailyReset(now: now)
        let day = max(1, nextDailyReset(after: now).timeIntervalSince(Calendar.current.startOfDay(for: now)))
        return CGFloat(max(0.04, min(0.98, 1 - remaining / day)))
    }

    static var dailyStreak: Int {
        guard !isResetLocked else { return 0 }
        return storedInt(K.dailyStreak, default: 0)
    }

    static func unlockTheme(_ name: String) {
        var themes = Set(unlockedThemes())
        themes.insert(name)
        d.set(Array(themes).sorted(), forKey: K.themes)
        cloudPush()
    }

    static func unlockedThemes() -> [String] {
        guard !isResetLocked else { return [] }
        return d.stringArray(forKey: K.themes) ?? []
    }

    private static func updateDailyStreak(for dateKey: String) {
        guard d.string(forKey: K.dailyReward) != dateKey else { return }
        let previous = d.string(forKey: K.dailyReward)
        let nextStreak: Int
        if let previous,
           let previousDate = dailyFormatter.date(from: previous),
           let currentDate = dailyFormatter.date(from: dateKey),
           Calendar.current.isDate(previousDate, inSameDayAs: Calendar.current.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate) {
            nextStreak = max(1, dailyStreak) + 1
        } else {
            nextStreak = 1
        }
        d.set(nextStreak, forKey: K.dailyStreak)
    }

    private static func normalizeRewardedAdGate(now: Date = Date()) {
        let today = dateKey(for: now)
        guard d.string(forKey: K.rewardedAdDate) != today else { return }
        d.set(today, forKey: K.rewardedAdDate)
        d.set(0, forKey: K.rewardedAdCount)
        d.removeObject(forKey: K.rewardedAdNextAt)
    }

    private static func dateKey(for date: Date) -> String {
        dailyFormatter.string(from: date)
    }

    private static func nextDailyReset(after date: Date) -> Date {
        Calendar.current.date(byAdding: .day,
                              value: 1,
                              to: Calendar.current.startOfDay(for: date)) ?? date.addingTimeInterval(24 * 60 * 60)
    }

    private static func compactDuration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        if minutes > 0 {
            return "\(minutes)m \(secs)s"
        }
        return "\(secs)s"
    }

    private static var dailyFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar.current
        return formatter
    }

    /// Wipes progress (level, cash, lives, etc.) but preserves user prefs
    /// (sound/music/haptics/reduceMotion).
    static func resetAll() {
        let resetAt = Date().timeIntervalSince1970
        clearLocalProgressValues()
        d.set(1, forKey: K.level)
        d.set(resetAt, forKey: K.lastResetAt)
        d.set(resetAt, forKey: K.backendUpdatedAt)
        d.set(true, forKey: K.resetLockActive)
        Cloud.clearProgress()
        Cloud.push()
        FirebaseBackendService.shared.scheduleProgressSync()
    }

    private static func clearLocalProgressValues() {
        [K.level, K.totalScore, K.cash, K.lives, K.lifeRefAt, K.shuffleCount,
         K.movesQuantity, K.hammerCount, K.swapCount,
         K.piggyCoins, K.doublerExp, K.storeKitDeliveredTransactions]
            .forEach { d.removeObject(forKey: $0) }
        // Also clear per-level stars
        for n in 1...Levels.count {
            d.removeObject(forKey: K.starsPrefix + "\(n)")
            d.removeObject(forKey: K.rewardPrefix + "\(n)")
            d.removeObject(forKey: K.threeStarPrefix + "\(n)")
            d.removeObject(forKey: K.medalsPrefix + "\(n)")
            d.removeObject(forKey: K.ratingPrefix + "\(n)")
        }
        for key in d.dictionaryRepresentation().keys where key.hasPrefix(K.eventRewardPrefix) {
            d.removeObject(forKey: key)
        }
        for key in d.dictionaryRepresentation().keys where key.hasPrefix(K.bossRewardPrefix) {
            d.removeObject(forKey: key)
        }
        d.removeObject(forKey: K.dailyReward)
        d.removeObject(forKey: K.dailyAdBonus)
        d.removeObject(forKey: K.rewardedAdDate)
        d.removeObject(forKey: K.rewardedAdCount)
        d.removeObject(forKey: K.rewardedAdNextAt)
        d.removeObject(forKey: K.dailyStreak)
        d.removeObject(forKey: K.themes)
    }

    // MARK: - Firebase backend snapshots

    struct BackendState: Codable {
        var schemaVersion: Int = 1
        var clientUpdatedAt: TimeInterval
        var currentLevel: Int
        var totalScore: Int
        var cash: Int
        var lives: Int
        var lifeReferenceAt: TimeInterval?
        var shuffleCount: Int
        var movesQuantity: Int
        var hammerCount: Int
        var swapCount: Int
        var piggyCoins: Int
        var coinDoublerExpiresAt: TimeInterval?
        var dailyRewardDate: String?
        var dailyAdBonusDate: String?
        var dailyStreak: Int
        var unlockedThemes: [String]
        var deliveredStoreKitTransactionIDs: [String]
        var stars: [String: Int]
        var claimedRewards: [String: Bool]
        var claimedThreeStarRewards: [String: Bool]
        var claimedEventRewards: [String: Bool]
        var claimedBossRewards: [String: Bool]
        var medals: [String: Int]?
        var ratings: [String: Int]?
    }

    static func exportBackendState() -> BackendState {
        let updatedAt = max(d.double(forKey: K.backendUpdatedAt), Date().timeIntervalSince1970)
        return BackendState(
            clientUpdatedAt: updatedAt,
            currentLevel: currentLevel,
            totalScore: totalScore,
            cash: cash,
            lives: lives,
            lifeReferenceAt: (d.object(forKey: K.lifeRefAt) as? Date)?.timeIntervalSince1970,
            shuffleCount: shuffleCount,
            movesQuantity: movesQuantity,
            hammerCount: hammerCount,
            swapCount: swapCount,
            piggyCoins: piggyCoins,
            coinDoublerExpiresAt: coinDoublerExpiresAt?.timeIntervalSince1970,
            dailyRewardDate: d.string(forKey: K.dailyReward),
            dailyAdBonusDate: d.string(forKey: K.dailyAdBonus),
            dailyStreak: storedInt(K.dailyStreak, default: 0),
            unlockedThemes: (d.stringArray(forKey: K.themes) ?? []).sorted(),
            deliveredStoreKitTransactionIDs: deliveredStoreKitTransactionIDList,
            stars: intMap(prefix: K.starsPrefix),
            claimedRewards: boolMap(prefix: K.rewardPrefix),
            claimedThreeStarRewards: boolMap(prefix: K.threeStarPrefix),
            claimedEventRewards: boolMap(prefix: K.eventRewardPrefix),
            claimedBossRewards: boolMap(prefix: K.bossRewardPrefix),
            medals: intMap(prefix: K.medalsPrefix),
            ratings: intMap(prefix: K.ratingPrefix)
        )
    }

    static func applyBackendState(_ state: BackendState) {
        let localUpdatedAt = d.double(forKey: K.backendUpdatedAt)
        let localResetAt = d.double(forKey: K.lastResetAt)
        if d.bool(forKey: K.resetLockActive), state.clientUpdatedAt <= localResetAt {
            Cloud.push()
            return
        }
        guard state.clientUpdatedAt >= localResetAt else {
            Cloud.push()
            return
        }
        let preferRemoteEconomy = state.clientUpdatedAt >= localUpdatedAt

        d.set(max(currentLevel, state.currentLevel), forKey: K.level)
        d.set(max(totalScore, state.totalScore), forKey: K.totalScore)
        mergeInt(K.cash, remote: state.cash, preferRemote: preferRemoteEconomy)
        mergeInt(K.shuffleCount, remote: state.shuffleCount, preferRemote: preferRemoteEconomy)
        mergeInt(K.movesQuantity, remote: state.movesQuantity, preferRemote: preferRemoteEconomy)
        mergeInt(K.hammerCount, remote: state.hammerCount, preferRemote: preferRemoteEconomy)
        mergeInt(K.swapCount, remote: state.swapCount, preferRemote: preferRemoteEconomy)
        mergeInt(K.piggyCoins, remote: state.piggyCoins, preferRemote: preferRemoteEconomy)
        mergeInt(K.dailyStreak, remote: state.dailyStreak, preferRemote: preferRemoteEconomy)

        let localLives = storedInt(K.lives, default: Economy.livesMax)
        if preferRemoteEconomy || state.lives > localLives {
            d.set(max(0, min(Economy.livesMax, state.lives)), forKey: K.lives)
            if let ref = state.lifeReferenceAt {
                d.set(Date(timeIntervalSince1970: ref), forKey: K.lifeRefAt)
            } else {
                d.removeObject(forKey: K.lifeRefAt)
            }
        }

        if let remoteExp = state.coinDoublerExpiresAt {
            let localExp = (d.object(forKey: K.doublerExp) as? Date)?.timeIntervalSince1970 ?? 0
            if preferRemoteEconomy || remoteExp > localExp {
                d.set(Date(timeIntervalSince1970: remoteExp), forKey: K.doublerExp)
            }
        }

        if preferRemoteEconomy {
            if let date = state.dailyRewardDate { d.set(date, forKey: K.dailyReward) }
            if let date = state.dailyAdBonusDate { d.set(date, forKey: K.dailyAdBonus) }
        }

        let themes = Set(d.stringArray(forKey: K.themes) ?? []).union(state.unlockedThemes)
        d.set(Array(themes).sorted(), forKey: K.themes)

        let transactions = deliveredStoreKitTransactionIDs.union(state.deliveredStoreKitTransactionIDs)
        d.set(Array(transactions).sorted(), forKey: K.storeKitDeliveredTransactions)

        mergeIntMap(prefix: K.starsPrefix, remote: state.stars)
        mergeBoolMap(prefix: K.rewardPrefix, remote: state.claimedRewards)
        mergeBoolMap(prefix: K.threeStarPrefix, remote: state.claimedThreeStarRewards)
        mergeBoolMap(prefix: K.eventRewardPrefix, remote: state.claimedEventRewards)
        mergeBoolMap(prefix: K.bossRewardPrefix, remote: state.claimedBossRewards)
        // Medals are stored as bitmasks; OR them together so each device's earned
        // medals are preserved on sync.
        if let remoteMedals = state.medals {
            for (suffix, value) in remoteMedals {
                let key = K.medalsPrefix + suffix
                d.set(d.integer(forKey: key) | value, forKey: key)
            }
        }
        if let remoteRatings = state.ratings {
            mergeIntMap(prefix: K.ratingPrefix, remote: remoteRatings)
        }

        d.set(max(localUpdatedAt, state.clientUpdatedAt), forKey: K.backendUpdatedAt)
        Cloud.push()
    }

    private static func mergeInt(_ key: String, remote: Int, preferRemote: Bool) {
        let local = storedInt(key, default: 0)
        d.set(preferRemote ? remote : max(local, remote), forKey: key)
    }

    private static func intMap(prefix: String) -> [String: Int] {
        var result: [String: Int] = [:]
        for key in d.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            result[String(key.dropFirst(prefix.count))] = d.integer(forKey: key)
        }
        return result
    }

    private static func boolMap(prefix: String) -> [String: Bool] {
        var result: [String: Bool] = [:]
        for key in d.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            result[String(key.dropFirst(prefix.count))] = d.bool(forKey: key)
        }
        return result
    }

    private static func mergeIntMap(prefix: String, remote: [String: Int]) {
        for (suffix, value) in remote {
            let key = prefix + suffix
            d.set(max(d.integer(forKey: key), value), forKey: key)
        }
    }

    private static func mergeBoolMap(prefix: String, remote: [String: Bool]) {
        for (suffix, value) in remote where value || d.bool(forKey: prefix + suffix) {
            d.set(true, forKey: prefix + suffix)
        }
    }

    // MARK: - iCloud sync

    /// Mirror of progress to NSUbiquitousKeyValueStore. The iCloud KVS calls
    /// are no-ops when the iCloud entitlement isn't enabled in the project, so
    /// it's safe to call these unconditionally — they just don't do anything
    /// until the entitlement is flipped on in the target's capabilities and
    /// the container is configured in App Store Connect.
    enum Cloud {
        private static let kvs = NSUbiquitousKeyValueStore.default
        private static var started = false

        /// Call once on launch (e.g., from AppDelegate). Pulls remote → local
        /// (max-wins on stars, last-write-wins elsewhere), then pushes local
        /// → remote so any new state on this device propagates.
        static func start() {
            guard !started else { return }
            started = true
            NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: kvs,
                queue: .main
            ) { _ in pullFromCloud() }
            kvs.synchronize()
            pullFromCloud()
            pushToCloud()
        }

        /// Force a sync — useful from app foreground or after a save point.
        static func push() {
            guard started else { return }
            pushToCloud()
            kvs.synchronize()
        }

        static func clearProgress() {
            for key in cloudSyncedKeys {
                kvs.removeObject(forKey: key)
            }
            let keys = kvs.dictionaryRepresentation.keys
            for prefix in cloudSyncedPrefixes {
                for key in keys where key.hasPrefix(prefix) {
                    kvs.removeObject(forKey: key)
                }
            }
            if let resetAt = d.object(forKey: K.lastResetAt) {
                kvs.set(resetAt, forKey: K.lastResetAt)
            }
            if let updatedAt = d.object(forKey: K.backendUpdatedAt) {
                kvs.set(updatedAt, forKey: K.backendUpdatedAt)
            }
            kvs.synchronize()
        }

        private static func pushToCloud() {
            for key in cloudSyncedKeys {
                if let v = d.object(forKey: key) {
                    kvs.set(v, forKey: key)
                }
            }
            for prefix in cloudSyncedPrefixes {
                for k in d.dictionaryRepresentation().keys where k.hasPrefix(prefix) {
                    if let v = d.object(forKey: k) {
                        kvs.set(v, forKey: k)
                    }
                }
            }
        }

        /// Merge cloud → local. Stars use max-wins (so a cleared level on
        /// device A doesn't get re-locked when device B catches up). Currency
        /// and toggles are last-write-wins.
        private static func pullFromCloud() {
            let localResetAt = d.double(forKey: K.lastResetAt)
            let remoteResetAt = (kvs.object(forKey: K.lastResetAt) as? TimeInterval) ?? 0
            let remoteUpdatedAt = (kvs.object(forKey: K.backendUpdatedAt) as? TimeInterval) ?? 0

            if d.bool(forKey: K.resetLockActive),
               remoteResetAt <= localResetAt,
               remoteUpdatedAt <= localResetAt {
                clearProgress()
                return
            }

            if localResetAt > remoteResetAt {
                clearProgress()
                return
            }

            if remoteResetAt > localResetAt {
                clearLocalProgressValues()
                d.set(1, forKey: K.level)
                d.set(remoteResetAt, forKey: K.lastResetAt)
                d.set(max(d.double(forKey: K.backendUpdatedAt), remoteResetAt), forKey: K.backendUpdatedAt)
                d.set(true, forKey: K.resetLockActive)
                return
            }

            // Stars: max-wins
            for n in 1...Levels.count {
                let key = K.starsPrefix + "\(n)"
                if let remote = kvs.object(forKey: key) as? Int {
                    let local = d.integer(forKey: key)
                    if remote > local { d.set(remote, forKey: key) }
                }
            }
            // Boolean reward flags: OR-wins
            for prefix in [K.rewardPrefix, K.threeStarPrefix, K.eventRewardPrefix, K.bossRewardPrefix] {
                var allKeys = Set<String>()
                allKeys.formUnion(d.dictionaryRepresentation().keys)
                allKeys.formUnion(kvs.dictionaryRepresentation.keys)
                for k in allKeys where k.hasPrefix(prefix) {
                    let remote = (kvs.object(forKey: k) as? Bool) ?? false
                    let local = d.bool(forKey: k)
                    if remote || local { d.set(true, forKey: k) }
                }
            }
            // Themes: union
            if let remoteThemes = kvs.array(forKey: K.themes) as? [String] {
                let localThemes = Set(d.stringArray(forKey: K.themes) ?? [])
                let union = localThemes.union(remoteThemes)
                if union != localThemes { d.set(Array(union).sorted(), forKey: K.themes) }
            }
            // Currency / lives / dates: last-write-wins (cloud authoritative
            // when remote is non-nil — this matches device-restore semantics).
            for key in [K.cash, K.totalScore, K.shuffleCount, K.hammerCount,
                        K.swapCount, K.movesQuantity, K.dailyStreak, K.piggyCoins,
                        K.rewardedAdCount] {
                if let remote = kvs.object(forKey: key) as? Int {
                    d.set(remote, forKey: key)
                }
            }
            for key in [K.dailyReward, K.dailyAdBonus, K.rewardedAdDate] {
                if let remote = kvs.string(forKey: key) {
                    d.set(remote, forKey: key)
                }
            }
            // Highest unlocked level: max-wins
            if let remoteLevel = kvs.object(forKey: K.level) as? Int {
                let local = d.integer(forKey: K.level)
                if remoteLevel > local { d.set(remoteLevel, forKey: K.level) }
            }
            if let remote = kvs.object(forKey: K.doublerExp) as? Date {
                d.set(remote, forKey: K.doublerExp)
            }
            if let remote = kvs.object(forKey: K.rewardedAdNextAt) as? Date {
                d.set(remote, forKey: K.rewardedAdNextAt)
            }
            // Life state: prefer the remote that grants more lives so device
            // swaps don't *consume* a life.
            if let remoteLives = kvs.object(forKey: K.lives) as? Int {
                let local = d.integer(forKey: K.lives)
                if remoteLives > local { d.set(remoteLives, forKey: K.lives) }
                if let remoteRef = kvs.object(forKey: K.lifeRefAt) as? Date {
                    d.set(remoteRef, forKey: K.lifeRefAt)
                }
            }
        }
    }
}
