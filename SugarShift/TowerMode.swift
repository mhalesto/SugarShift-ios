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

    /// How many times one perk can be drafted in a run. Without a cap, taking
    /// Sugar Legs every time it appears outruns the escalation curve — by the
    /// high floors the move budget grows faster than the target does, so the
    /// tower gets *easier* the higher you climb and the draft collapses into
    /// one correct answer. Capping stacks keeps the ladder rising and makes the
    /// draft a real choice between going deeper and going wider.
    static let maxStacks = 3

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
    /// Set once the player commits a move on `floor`, cleared when the floor
    /// resolves. If it survives into the next session the floor was walked out
    /// on, which counts as a loss — see `resume()`.
    var floorInProgress: Bool = false
}

/// Outcome of picking the climb back up. Leaving a floor mid-play is a loss,
/// so resuming can end the previous run before handing back a fresh one.
struct TowerResume: Equatable {
    /// The run to continue, or nil when there is no active climb.
    let run: TowerRun?
    /// Non-nil when this resume ended a run because its floor was abandoned.
    let abandonedFloor: Int?
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
        // Stacks are capped here rather than at draft time so a run saved by an
        // older build cannot keep an over-stacked advantage.
        func stacks(of perk: TowerPerk) -> Int {
            min(TowerPerk.maxStacks, perks.filter { $0 == perk }.count)
        }

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
        colors = max(4, colors - stacks(of: .sweetSimplicity))

        // Targets and objective sizes key off the *base* budget, never the
        // perked one — otherwise drafting Sugar Legs would raise the bar it
        // was bought to clear and the perk would buy nothing.
        let baseMoves = max(16, 23 - floor / 3)
        let moves = baseMoves + 3 * stacks(of: .extraMoves)

        // The climb escalates through *mechanics* — more colours, more
        // blockers, syrup, chocolate, fuses — not through arithmetic. The old
        // curve grew the target 450 a floor while the move budget shrank
        // toward 14, so by floor 20 a score floor demanded ~700 points a move
        // and simply could not be cleared; simulated floors 10, 11, 15, 16 and
        // 20 all sat at a 0% win rate.
        //
        // Because the tower has no last floor, the demand has to plateau
        // rather than merely grow more slowly: any per-floor increase against
        // a floored move budget eventually becomes impossible again. So
        // points-per-move ramps to a ceiling the board can actually produce
        // and stays there, and the floors above that get harder through their
        // mechanic bands and their shrinking move budget instead.
        let pointsPerMove = min(250, 55 + floor * 14)
        let target = baseMoves * pointsPerMove

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
                                 startingBombs: stacks(of: .startBomb),
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
        // Objective floors keep the score thresholds below: `LevelScoring`
        // grades a non-score goal off mastery, so `target` stays a scoring
        // reference rather than becoming a second win condition.
        let goal = floorGoal(floor: floor, layout: layout, colors: colors, moves: baseMoves)
        _ = rng.next() // reserved for future per-floor variety rolls

        return LevelConfig(number: Levels.towerLevel,
                           rows: rows, cols: cols, colors: colors,
                           moves: moves, target: target,
                           archetype: .combo,
                           difficulty: difficulty,
                           skin: skin,
                           layout: layout,
                           goal: goal,
                           starThresholds: (one: target,
                                            two: Int(Double(target) * 1.6),
                                            three: Int(Double(target) * 2.4)),
                           bombSpawnRunLength: 5,
                           blurb: String(localized: "Sugar Tower — Floor \(floor)"),
                           modifiers: modifiers,
                           isBoss: false)
    }

    /// The floor's win condition. Pure in the values `floorConfig` already
    /// computed so the goal can never ask for something the board does not
    /// seed. Rotating these is what stops a 20-floor climb from being twenty
    /// rounds of "reach a score".
    ///
    /// `clearBlockers` is withheld from three kinds of floor: syrup floors
    /// keep coating fresh tiles and chocolate floors keep spreading, so "clear
    /// every blocker" there is a target that never settles; and crate floors
    /// cost three hits each, which the tower's shrinking `moves` cannot pay.
    static func floorGoal(floor: Int,
                          layout: LevelLayout,
                          colors: Int,
                          moves: Int) -> LevelGoal {
        // Floors 1-2 teach the ladder itself; keep them a plain score climb.
        guard floor >= 3 else { return .score }

        let hazardsKeepSpawning = layout.syrupTickEvery != nil || layout.chocolateCount > 0
        let blockersAreClearable = layout.blockerCount > 0
            && layout.crateCount == 0
            && !hazardsKeepSpawning

        // Objective sizes are pegged to the move budget, using the rate the
        // simulated bot actually sustains on these boards (a little over two
        // target tiles a move, a special roughly every second move). Asking
        // for less than that finishes the floor with a third of the budget
        // untouched, which is what the first tuning pass measured.
        switch floor % 5 {
        case 1 where blockersAreClearable:
            return .clearBlockers
        case 2:
            return .collectColor(index: floor % max(1, colors),
                                 count: max(10, Int(Double(moves) * 1.6)))
        case 3:
            // Still capped by the move budget the way the campaign caps it —
            // high floors shrink `moves`, so the ask shrinks with them.
            return .createSpecials(count: max(2, min(8, min(1 + floor / 3, moves / 3))))
        case 4 where blockersAreClearable:
            return .clearBlockers
        case 4:
            return .collectColor(index: (floor + 2) % max(1, colors),
                                 count: max(10, Int(Double(moves) * 1.3)))
        default:
            // Includes every 5th floor — the syrup pressure floors, where a
            // score attack against a rising tide is the intended fight.
            return .score
        }
    }

    /// Three distinct perks offered after clearing `floor`, deterministic per
    /// week so climbs are comparable and replannable.
    ///
    /// Perks the run has already maxed out drop off the table, which is what
    /// pushes a long climb toward a broad build instead of three copies of the
    /// same card. If every perk is maxed the table reopens rather than handing
    /// back an empty draft.
    static func perkChoices(weekKey: String, floor: Int, owned: [TowerPerk] = []) -> [TowerPerk] {
        var rng = SeededRandomNumberGenerator(seed: floorSeed(weekKey: weekKey, floor: floor) ^ 0x9E4B)
        let available = TowerPerk.allCases.filter {
            perk in owned.filter { $0 == perk }.count < TowerPerk.maxStacks
        }
        let table = available.isEmpty ? TowerPerk.allCases : available
        return Array(table.shuffled(using: &rng).prefix(3))
    }

    /// Coins paid for clearing `floor`. Milestone floors (every 5th) pay a
    /// chest bonus; Gold Rush stacks add +50% each.
    static func coinReward(floor: Int, perks: [TowerPerk]) -> Int {
        var coins = 30 + floor * 10
        if floor.isMultiple(of: 5) { coins += 100 }
        let goldStacks = min(TowerPerk.maxStacks, perks.filter { $0 == .goldRush }.count)
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
                        coinsEarned: d.integer(forKey: Persistence.K.towerRunCoins),
                        floorInProgress: d.bool(forKey: Persistence.K.towerFloorLive))
    }

    static func save(_ run: TowerRun) {
        let d = UserDefaults.standard
        d.set(run.floor, forKey: Persistence.K.towerFloor)
        d.set(run.weekKey, forKey: Persistence.K.towerWeek)
        d.set(run.perks.map(\.rawValue), forKey: Persistence.K.towerPerks)
        d.set(run.coinsEarned, forKey: Persistence.K.towerRunCoins)
        d.set(run.floorInProgress, forKey: Persistence.K.towerFloorLive)
    }

    /// Picks the climb back up, enforcing the mode's one-loss rule across app
    /// sessions: a floor the player started but never resolved is a loss, so
    /// force-quitting a doomed floor can no longer dodge it. Between floors the
    /// flag is clear, which is what keeps "Take a break (run saved)" honest.
    static func resume() -> TowerResume {
        guard let run = activeRun() else { return TowerResume(run: nil, abandonedFloor: nil) }
        guard run.floorInProgress else { return TowerResume(run: run, abandonedFloor: nil) }
        Analytics.track("tower_floor_abandoned",
                        properties: ["week": run.weekKey,
                                     "floor": "\(run.floor)"])
        endRun(run)
        return TowerResume(run: nil, abandonedFloor: run.floor)
    }

    /// Called when the player commits their first move on a tower floor. From
    /// here on, leaving without resolving the floor ends the run.
    static func markFloorInProgress() {
        guard var run = activeRun(), !run.floorInProgress else { return }
        run.floorInProgress = true
        save(run)
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
        d.removeObject(forKey: Persistence.K.towerFloorLive)
        Analytics.track("tower_run_ended",
                        properties: ["week": run.weekKey,
                                     "floors_cleared": "\(cleared)",
                                     "coins": "\(run.coinsEarned)"])
        GameCenterService.shared.submitTowerBestFloor(Persistence.towerBestFloor)
    }
}
