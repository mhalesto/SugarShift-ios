import Foundation

/// Three rotating daily missions — light, session-spanning goals ("create 4
/// power-ups", "win 2 levels") that pay coins on claim. Selection is
/// deterministic per calendar day, seeded the same way as the daily
/// challenge, and every kind can be progressed on any level so a day's slate
/// is never unachievable.
struct DailyMission: Equatable, Identifiable {
    enum Kind: String, CaseIterable {
        case clearTiles
        case createSpecials
        case triggerSpecials
        case deepCascades
        case winLevels
        case earnScore
    }

    /// Stable per-day identifier, e.g. "2026-07-12-createSpecials".
    let id: String
    let kind: Kind
    let target: Int
    let rewardCoins: Int

    var title: String {
        switch kind {
        case .clearTiles:      return String(localized: "Clear \(target) fruits")
        case .createSpecials:  return String(localized: "Create \(target) power-ups")
        case .triggerSpecials: return String(localized: "Set off \(target) power-ups")
        case .deepCascades:    return String(localized: "Trigger \(target) chain reactions")
        case .winLevels:       return String(localized: "Win \(target) levels")
        case .earnScore:       return String(localized: "Score \(target) points in total")
        }
    }
}

enum DailyMissions {

    /// Gameplay events that can advance a mission. GameScene reports these;
    /// the mapping onto the day's missions stays pure and testable.
    enum Event {
        case tilesCleared(Int)
        case specialsCreated(Int)
        case specialsTriggered(Int)
        /// Fired once per cascade chain that reaches depth 3.
        case chainReaction
        case levelWon
        case scoreEarned(Int)
    }

    static let missionsPerDay = 3

    static func missions(on date: Date = Date()) -> [DailyMission] {
        let key = Levels.dailyChallenge(on: date).dateKey
        // Salt keeps the mission roll independent of the daily-challenge
        // board seed for the same date.
        var rng = SeededRandomNumberGenerator(seed: LevelSeed.dailySeed(dateKey: key,
                                                                        level: 777))
        let kinds = DailyMission.Kind.allCases.shuffled(using: &rng).prefix(missionsPerDay)
        return kinds.map { kind in
            let (target, coins) = roll(kind, using: &rng)
            return DailyMission(id: "\(key)-\(kind.rawValue)",
                                kind: kind,
                                target: target,
                                rewardCoins: coins)
        }
    }

    private static func roll(_ kind: DailyMission.Kind,
                             using rng: inout SeededRandomNumberGenerator) -> (target: Int, coins: Int) {
        switch kind {
        case .clearTiles:      return (Int.random(in: 8...14, using: &rng) * 10, 50)
        case .createSpecials:  return (Int.random(in: 3...6, using: &rng), 60)
        case .triggerSpecials: return (Int.random(in: 3...6, using: &rng), 60)
        case .deepCascades:    return (Int.random(in: 2...4, using: &rng), 70)
        case .winLevels:       return (Int.random(in: 1...3, using: &rng), 80)
        case .earnScore:       return (Int.random(in: 3...8, using: &rng) * 1_000, 50)
        }
    }

    /// Pure mapping of one gameplay event onto the day's missions.
    static func contributions(for event: Event,
                              missions: [DailyMission]) -> [(id: String, amount: Int)] {
        missions.compactMap { mission in
            let amount: Int
            switch (event, mission.kind) {
            case (.tilesCleared(let n), .clearTiles):          amount = n
            case (.specialsCreated(let n), .createSpecials):   amount = n
            case (.specialsTriggered(let n), .triggerSpecials): amount = n
            case (.chainReaction, .deepCascades):              amount = 1
            case (.levelWon, .winLevels):                      amount = 1
            case (.scoreEarned(let n), .earnScore):            amount = n
            default:                                           return nil
            }
            return amount > 0 ? (mission.id, amount) : nil
        }
    }

    static func record(_ events: [Event], on date: Date = Date()) {
        let todays = missions(on: date)
        for event in events {
            for c in contributions(for: event, missions: todays) {
                Persistence.addMissionProgress(id: c.id, amount: c.amount)
            }
        }
    }

    static func isComplete(_ mission: DailyMission) -> Bool {
        Persistence.missionProgress(id: mission.id) >= mission.target
    }

    /// Missions completed today, claimed or not — drives the map strip badge.
    static func completedCount(on date: Date = Date()) -> Int {
        missions(on: date).filter { isComplete($0) }.count
    }

    /// Claims a completed mission once and credits coins (doubler applies).
    /// Returns the coins credited, or nil if not claimable.
    @discardableResult
    static func claim(_ mission: DailyMission) -> Int? {
        guard isComplete(mission),
              !Persistence.hasClaimedMission(id: mission.id) else { return nil }
        Persistence.markMissionClaimed(id: mission.id)
        let coins = Persistence.applyCoinDoubler(mission.rewardCoins)
        Persistence.cash += coins
        Analytics.track("mission_claimed",
                        properties: ["mission": mission.kind.rawValue,
                                     "coins": "\(coins)"])
        return coins
    }
}
