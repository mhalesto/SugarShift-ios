import Foundation

/// Sugar Tower — the roguelite gauntlet. One run = climb floors until you
/// lose. Every cleared floor pays coins and offers a draft of one run-long
/// perk; a single loss ends the run. Floors are seeded from the ISO week so
/// every player climbs the identical tower each week and best-floor scores
/// are comparable. Boosters are locked inside the tower and there is no
/// continue: the tension is the point.

enum TowerPerk: String, CaseIterable, Equatable {
    /// +3 moves on every remaining floor. Stacks.
    case extraMoves
    /// Every floor starts with a bomb already on the board. Stacks.
    case startBomb
    /// One fewer fruit colour in the mix (never below 4). Stacks.
    case sweetSimplicity
    /// Bombs and wrapped specials blast wider (the level modifier).
    case biggerBlasts
    /// Every floor starts with 40% Smash charge banked. Stacks.
    case headStart
    /// Tower coin rewards +50%. Stacks.
    case goldRush

    var title: String {
        switch self {
        case .extraMoves:      return String(localized: "Sugar Legs")
        case .startBomb:       return String(localized: "Bomb Pocket")
        case .sweetSimplicity: return String(localized: "Sweet Simplicity")
        case .biggerBlasts:    return String(localized: "Bigger Blasts")
        case .headStart:       return String(localized: "Head Start")
        case .goldRush:        return String(localized: "Gold Rush")
        }
    }

    var summary: String {
        switch self {
        case .extraMoves:      return String(localized: "+3 moves on every floor")
        case .startBomb:       return String(localized: "Each floor starts with a bomb")
        case .sweetSimplicity: return String(localized: "One fewer fruit colour")
        case .biggerBlasts:    return String(localized: "Specials blast a wider area")
        case .headStart:       return String(localized: "Start floors with Smash charge")
        case .goldRush:        return String(localized: "Tower coins +50%")
        }
    }

    var emoji: String {
        switch self {
        case .extraMoves:      return "🦵"
        case .startBomb:       return "💣"
        case .sweetSimplicity: return "🍭"
        case .biggerBlasts:    return "💥"
        case .headStart:       return "⚡️"
        case .goldRush:        return "💰"
        }
    }
}

/// State of the climb in progress. `floor` is the floor about to be (or
/// being) played, 1-based. Persisted so a run survives app relaunches.
struct TowerRun: Equatable {
    var weekKey: String
    var floor: Int
    var perks: [TowerPerk]
    var coinsEarned: Int
}

enum TowerMode {

    /// ISO week key ("2026-W28"). A run keeps the week it started in so its
    /// remaining floors stay consistent even across the weekly rollover.
    static func weekKey(for date: Date = Date()) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone.current
        let year = calendar.component(.yearForWeekOfYear, from: date)
        let week = calendar.component(.weekOfYear, from: date)
        return String(format: "%04d-W%02d", year, week)
    }

    /// Deterministic board seed — identical for every player on the same
    /// week + floor, same FNV path as the daily challenge.
    static func floorSeed(weekKey: String, floor: Int) -> UInt64 {
        LevelSeed.dailySeed(dateKey: weekKey, level: 5_000 + floor)
    }

    // MARK: - Floor generation

    /// The escalation curve. Pure in (weekKey, floor, perks) so gameplay,
    /// previews, and tests all see the same tower.
    static func floorConfig(weekKey: String, floor: Int, perks: [TowerPerk]) -> LevelConfig {
        let floor = max(1, floor)
        var rng = SeededRandomNumberGenerator(seed: floorSeed(weekKey: weekKey, floor: floor) ^ 0x70B3)

        let (rows, cols): (Int, Int)
        switch floor {
        case ..<4:   (rows, cols) = (7, 7)
        case 4...8:  (rows, cols) = (8, 8)
        default:     (rows, cols) = (9, 9)
        }

        var colors: Int
        switch floor {
        case ..<3:   colors = 4
        case 3...7:  colors = 5
        default:     colors = 6
        }
        colors = max(4, colors - perks.filter { $0 == .sweetSimplicity }.count)

        let moves = max(14, 23 - floor / 2)
            + 3 * perks.filter { $0 == .extraMoves }.count

        let target = 900 + floor * 450

        // One or two signature mechanics per floor so each feels distinct.
        // Counts scale gently; the pressure floors (every 5th) add syrup.
        var ice = 0, jelly = 0, crates = 0, vines = 0, locks = 0
        var chocolate = 0, fuses = 0
        var syrupTick: Int? = nil
        if floor >= 2 {
            switch floor % 4 {
            case 0:  crates = min(6, 1 + floor / 3); ice = min(6, floor / 2)
            case 1:  jelly = min(9, 2 + floor / 2)
            case 2:  vines = min(6, 2 + floor / 4); locks = min(4, floor / 4)
            default: ice = min(8, 2 + floor / 2)
            }
        }
        if floor >= 6, floor % 4 == 3 { chocolate = min(3, floor / 6) }
        if floor >= 12 { fuses = 2 }
        if floor >= 5, floor.isMultiple(of: 5) { syrupTick = max(3, 6 - floor / 10) }

        let layout = LevelLayout(mask: nil,
                                 iceCount: ice,
                                 lockCount: locks,
                                 jellyCount: jelly,
                                 crateCount: crates,
                                 colorLockCount: 0,
                                 vineCount: vines,
                                 startingBombs: perks.filter { $0 == .startBomb }.count,
                                 portalPairs: [],
                                 conveyorBelts: [],
                                 chocolateCount: chocolate,
                                 syrupTickEvery: syrupTick,
                                 countdownCount: fuses)

        var modifiers: [LevelModifier] = [.noBoosters]
        if perks.contains(.biggerBlasts) { modifiers.append(.specialsExplodeBigger) }
        if floor >= 8, floor % 3 == 2 { modifiers.append(.bananaScoreDouble) }

        let difficulty: LevelDifficulty
        switch floor {
        case ..<5:    difficulty = .normal
        case 5...9:   difficulty = .hard
        case 10...14: difficulty = .superHard
        default:      difficulty = .crownChallenge
        }

        let skins: [BoardSkin] = [.sherbet, .lagoon, .sunset, .berry, .citrine, .glacier, .mint, .midnight]
        let skin = skins[min(skins.count - 1, (floor - 1) / 3)]
        _ = rng.next() // reserved for future per-floor variety rolls

        return LevelConfig(number: Levels.towerLevel,
                           rows: rows, cols: cols, colors: colors,
                           moves: moves, target: target,
                           archetype: .combo,
                           difficulty: difficulty,
                           skin: skin,
                           layout: layout,
                           goal: .score,
                           starThresholds: (one: target,
                                            two: Int(Double(target) * 1.6),
                                            three: Int(Double(target) * 2.4)),
                           bombSpawnRunLength: 5,
                           blurb: String(localized: "Sugar Tower — Floor \(floor)"),
                           modifiers: modifiers,
                           isBoss: false)
    }

    /// Three distinct perks offered after clearing `floor`, deterministic per
    /// week so climbs are comparable and replannable.
    static func perkChoices(weekKey: String, floor: Int) -> [TowerPerk] {
        var rng = SeededRandomNumberGenerator(seed: floorSeed(weekKey: weekKey, floor: floor) ^ 0x9E4B)
        return Array(TowerPerk.allCases.shuffled(using: &rng).prefix(3))
    }

    /// Coins paid for clearing `floor`. Milestone floors (every 5th) pay a
    /// chest bonus; Gold Rush stacks add +50% each.
    static func coinReward(floor: Int, perks: [TowerPerk]) -> Int {
        var coins = 30 + floor * 10
        if floor.isMultiple(of: 5) { coins += 100 }
        let goldStacks = perks.filter { $0 == .goldRush }.count
        if goldStacks > 0 {
            coins += coins * goldStacks / 2
        }
        return coins
    }

    // MARK: - Run persistence

    static func activeRun() -> TowerRun? {
        let d = UserDefaults.standard
        let floor = d.integer(forKey: Persistence.K.towerFloor)
        guard floor >= 1 else { return nil }
        let week = d.string(forKey: Persistence.K.towerWeek) ?? weekKey()
        let perkNames = d.stringArray(forKey: Persistence.K.towerPerks) ?? []
        return TowerRun(weekKey: week,
                        floor: floor,
                        perks: perkNames.compactMap(TowerPerk.init(rawValue:)),
                        coinsEarned: d.integer(forKey: Persistence.K.towerRunCoins))
    }

    static func save(_ run: TowerRun) {
        let d = UserDefaults.standard
        d.set(run.floor, forKey: Persistence.K.towerFloor)
        d.set(run.weekKey, forKey: Persistence.K.towerWeek)
        d.set(run.perks.map(\.rawValue), forKey: Persistence.K.towerPerks)
        d.set(run.coinsEarned, forKey: Persistence.K.towerRunCoins)
    }

    @discardableResult
    static func startNewRun(on date: Date = Date()) -> TowerRun {
        let run = TowerRun(weekKey: weekKey(for: date), floor: 1, perks: [], coinsEarned: 0)
        save(run)
        Analytics.track("tower_run_started", properties: ["week": run.weekKey])
        return run
    }

    /// Records the best floor cleared and clears the active run.
    static func endRun(_ run: TowerRun) {
        let cleared = run.floor - 1
        if cleared > Persistence.towerBestFloor {
            Persistence.towerBestFloor = cleared
        }
        let d = UserDefaults.standard
        d.removeObject(forKey: Persistence.K.towerFloor)
        d.removeObject(forKey: Persistence.K.towerPerks)
        d.removeObject(forKey: Persistence.K.towerRunCoins)
        d.removeObject(forKey: Persistence.K.towerWeek)
        Analytics.track("tower_run_ended",
                        properties: ["week": run.weekKey,
                                     "floors_cleared": "\(cleared)",
                                     "coins": "\(run.coinsEarned)"])
        GameCenterService.shared.submitTowerBestFloor(Persistence.towerBestFloor)
    }
}
