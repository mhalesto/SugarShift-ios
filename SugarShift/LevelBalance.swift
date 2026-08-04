import Foundation

struct LevelBalanceSnapshot: Equatable {
    let level: Int
    let playableCells: Int
    let moves: Int
    let target: Int
    let estimatedScoreCapacity: Int
    let openingMoveScore: Int
    let goal: LevelGoal
    let difficulty: LevelDifficulty
    let warnings: [String]
}

enum LevelBalanceAnalyzer {
    static func snapshot(for config: LevelConfig) -> LevelBalanceSnapshot {
        let playable = playableCells(for: config)
        let blockerPenalty = (config.layout.iceCount * 80)
            + (config.layout.lockCount * 55)
            + (config.layout.jellyCount * 45)
            + (config.layout.crateCount * 120)
            + (config.layout.colorLockCount * 70)
            + (config.layout.chestCount * 65)
            + (config.layout.vineCount * 45)
        let bombBoost = config.layout.startingBombs * 420
        let movementBoost = (config.layout.portalPairs.count + config.layout.conveyorBelts.count) * 180
        let shapeRatio = Double(playable) / Double(max(1, config.rows * config.cols))
        let shapeFactor = min(1.0, max(0.78, 0.72 + shapeRatio * 0.28))
        let colorFactor = config.colors >= 6 ? 0.90 : 1.0
        let baseCapacity = Int(Double(config.moves)
            * estimatedPointsPerMove(for: config)
            * shapeFactor
            * colorFactor)
        let estimated = max(1, baseCapacity + bombBoost + movementBoost - blockerPenalty)
        let openingMoveScore = LevelBoardFactory
            .makeInitialBoard(config: config,
                              seed: LevelSeed.make(level: config.number, salt: 0xBADA55),
                              minimumOpeningMoveScore: 0,
                              attempts: 24)
            .openingMoveScore

        var warnings: [String] = []
        if playable <= 0 {
            warnings.append("level has no playable cells")
        }
        if config.number <= 20, config.target > estimated {
            warnings.append("early target above estimate")
        }
        if seededHazards(config) > playable {
            warnings.append("seeded hazards exceed playable cells")
        }
        if !goalLooksFeasible(config, playable: playable) {
            warnings.append("goal may be infeasible")
        }
        if openingMoveScore <= 0 {
            warnings.append("opening board has no legal moves")
        }
        if config.isBoss, config.moves < 8 {
            warnings.append("boss shield has too few moves")
        }
        let drops = config.layout.ingredientCount + config.layout.keyCount
        if drops > 0,
           ingredientExitColumns(for: config) < drops {
            warnings.append("not enough drop-item exit columns")
        }

        return LevelBalanceSnapshot(level: config.number,
                                    playableCells: playable,
                                    moves: config.moves,
                                    target: config.target,
                                    estimatedScoreCapacity: estimated,
                                    openingMoveScore: openingMoveScore,
                                    goal: config.goal,
                                    difficulty: config.difficulty,
                                    warnings: warnings)
    }

    static func warnings(for config: LevelConfig) -> [String] {
        snapshot(for: config).warnings
    }

    static func estimatedWinRate(for config: LevelConfig) -> Double {
        let snap = snapshot(for: config)
        let ratio = Double(snap.estimatedScoreCapacity) / Double(max(1, config.target))
        let goalDrag: Double
        switch config.goal {
        case .score:
            goalDrag = 0
        case .createSpecials, .detonateBombs:
            goalDrag = 0.06
        case .collectColor, .clearBlockers:
            goalDrag = 0.08
        case .collectIngredients, .collectKeys, .openChests, .collectIngredientsAndKeys:
            goalDrag = 0.10
        }
        let effectiveGoalDrag = config.number <= 25 ? 0 : goalDrag
        // Early bosses are teaching set-pieces with generous move budgets; the
        // shield difficulty drag begins only after the onboarding campaign.
        let bossDrag = config.isBoss && config.number > 25 ? 0.05 : 0
        let raw = 0.42 + (ratio - 0.82) * 0.55 - effectiveGoalDrag - bossDrag
        return min(0.96, max(0.18, raw))
    }

    static func estimatedAverageStars(for config: LevelConfig) -> Double {
        let winRate = estimatedWinRate(for: config)
        switch winRate {
        case 0.88...:
            return 2.6
        case 0.72..<0.88:
            return 2.1
        case 0.55..<0.72:
            return 1.6
        default:
            return 1.1
        }
    }

    static func balanceLabel(winRate: Double, averageStars: Double) -> String {
        if winRate < 0.56 || averageStars < 1.35 { return "Too hard" }
        if winRate > 0.90 && averageStars > 2.45 { return "Too easy" }
        return "Fair"
    }

    private static func playableCells(for config: LevelConfig) -> Int {
        if let mask = config.layout.mask {
            return mask.flatMap { $0 }.filter { $0 }.count
        }
        return config.rows * config.cols
    }

    private static func estimatedPointsPerMove(for config: LevelConfig) -> Double {
        let base: Double
        switch config.number {
        case ...10:
            base = 180
        case 11...25:
            base = 285
        case 26...50:
            base = 305
        case 51...100:
            base = 335
        case 101...150:
            base = 360
        default:
            base = 385
        }

        let difficultyFactor: Double
        switch config.difficulty {
        case .normal:
            difficultyFactor = 1.00
        case .hard:
            difficultyFactor = 1.10
        case .superHard:
            difficultyFactor = 1.22
        case .crownChallenge:
            difficultyFactor = 1.28
        }

        let archetypeFactor: Double
        switch config.archetype {
        case .starter:
            archetypeFactor = 1.00
        case .combo:
            archetypeFactor = 1.08
        case .bombRush:
            archetypeFactor = 1.12
        case .crowded:
            archetypeFactor = 0.96
        case .ice, .lock:
            archetypeFactor = 0.92
        case .finale:
            archetypeFactor = 1.16
        }

        return base * difficultyFactor * archetypeFactor
    }

    private static func seededHazards(_ config: LevelConfig) -> Int {
        config.layout.blockerCount + config.layout.startingBombs + config.layout.ingredientCount + config.layout.keyCount
    }

    private static func goalLooksFeasible(_ config: LevelConfig, playable: Int) -> Bool {
        switch config.goal {
        case .score:
            return config.target > 0
        case .clearBlockers:
            // Rising syrup coats a fresh row every N moves, so "clear every
            // blocker" can be undone by the tick after the player empties the
            // board — the goal has to stop moving before it can be closed.
            return config.layout.blockerCount > 0 && config.layout.syrupTickEvery == nil
        case .collectColor(_, let count):
            return count <= max(playable, config.moves * 4)
        case .createSpecials(let count):
            return count <= max(1, config.moves / 4)
        case .detonateBombs(let count):
            return count <= max(1, config.layout.startingBombs + config.moves / 8)
        case .collectIngredients(let count):
            return count <= max(1, config.layout.ingredientCount)
                && count <= max(1, config.moves)
        case .collectKeys(let count):
            return count <= max(1, config.layout.keyCount)
                && count <= max(1, config.moves)
        case .openChests(let count):
            return count <= max(1, config.layout.chestCount)
                && (config.layout.keyCount > 0 || config.moves >= count)
        case .collectIngredientsAndKeys(let ingredients, let keys):
            return ingredients <= max(1, config.layout.ingredientCount)
                && keys <= max(1, config.layout.keyCount)
                && ingredients + keys <= max(1, config.moves)
        }
    }

    private static func ingredientExitColumns(for config: LevelConfig) -> Int {
        guard let mask = config.layout.mask else { return config.cols }
        var columns = 0
        for c in 0..<config.cols {
            if (0..<config.rows).contains(where: { r in mask[r][c] }) {
                columns += 1
            }
        }
        return columns
    }
}

struct LevelAttemptPerformance {
    let score: Int
    let movesLeft: Int
    let movesAtStart: Int
    let maxCascadeDepth: Int
    let createdSpecials: Int
    let detonatedBombs: Int
    let objectiveProgress: Double
}

enum LevelScoring {
    static func objectiveProgress(for config: LevelConfig,
                                  score: Int,
                                  startingBlockers: Int,
                                  remainingBlockers: Int,
                                  collectedGoalTiles: Int,
                                  createdSpecials: Int,
                                  detonatedBombs: Int,
                                  collectedIngredients: Int,
                                  collectedKeys: Int = 0,
                                  openedChests: Int = 0) -> Double {
        switch config.goal {
        case .score:
            return ratio(score, config.target)
        case .clearBlockers:
            return ratio(max(0, startingBlockers - remainingBlockers),
                         max(1, startingBlockers))
        case .collectColor(_, let count):
            return ratio(collectedGoalTiles, count)
        case .createSpecials(let count):
            return ratio(createdSpecials, count)
        case .detonateBombs(let count):
            return ratio(detonatedBombs, count)
        case .collectIngredients(let count):
            return ratio(collectedIngredients, count)
        case .collectKeys(let count):
            return ratio(collectedKeys, count)
        case .openChests(let count):
            return ratio(openedChests, count)
        case .collectIngredientsAndKeys(let ingredients, let keys):
            let collected = min(collectedIngredients, ingredients) + min(collectedKeys, keys)
            return ratio(collected, ingredients + keys)
        }
    }

    static func stars(for config: LevelConfig,
                      performance: LevelAttemptPerformance,
                      won: Bool) -> Int {
        guard won else { return 0 }

        if case .score = config.goal {
            let t = config.starThresholds
            if performance.score >= t.three { return 3 }
            if performance.score >= t.two { return 2 }
            return 1
        }

        let mastery = masteryScore(for: config, performance: performance)
        if mastery >= 0.72 { return 3 }
        if mastery >= 0.50 { return 2 }
        return 1
    }

    static func meterProgress(for config: LevelConfig,
                              performance: LevelAttemptPerformance,
                              objectiveComplete: Bool) -> Double {
        if case .score = config.goal {
            return ratio(performance.score, config.starThresholds.three)
        }

        let objectiveBand = min(0.34, max(0, performance.objectiveProgress) * 0.34)
        guard objectiveComplete else { return objectiveBand }

        let mastery = masteryScore(for: config, performance: performance)
        return min(1, 0.34 + mastery * 0.66)
    }

    static func nextStarText(for config: LevelConfig,
                             performance: LevelAttemptPerformance,
                             objectiveComplete: Bool) -> String {
        if case .score = config.goal {
            let t = config.starThresholds
            if performance.score < t.one { return "1 star at \(t.one)" }
            if performance.score < t.two { return "Next star \(t.two)" }
            if performance.score < t.three { return "Next star \(t.three)" }
            return "3 star score reached"
        }

        guard objectiveComplete else { return "1 star: finish objective" }
        let stars = stars(for: config, performance: performance, won: true)
        if stars < 2 { return "2 stars: save moves or combo" }
        if stars < 3 { return "3 stars: big combo finish" }
        return "3 star mastery reached"
    }

    static func previewSummary(for config: LevelConfig) -> String {
        if case .score = config.goal {
            return "1★ \(config.starThresholds.one)  2★ \(config.starThresholds.two)  3★ \(config.starThresholds.three)"
        }
        return "1★ objective  2★ efficient clear  3★ combo mastery"
    }

    private static func masteryScore(for config: LevelConfig,
                                     performance: LevelAttemptPerformance) -> Double {
        let moveRatio = ratio(performance.movesLeft, max(1, performance.movesAtStart))
        let scoreRatio = min(1, Double(performance.score) / Double(max(1, config.starThresholds.two)))
        let cascadeRatio = min(1, Double(max(0, performance.maxCascadeDepth - 1)) / 3.0)
        let specialNeed = max(3, config.moves / 7)
        let specialRatio = min(1, Double(performance.createdSpecials + performance.detonatedBombs) / Double(specialNeed))
        let comboRatio = max(cascadeRatio, specialRatio)

        return min(1,
                   max(0, performance.objectiveProgress) * 0.18 +
                   moveRatio * 0.36 +
                   scoreRatio * 0.20 +
                   comboRatio * 0.26)
    }

    private static func ratio(_ value: Int, _ target: Int) -> Double {
        guard target > 0 else { return 1 }
        return min(1, max(0, Double(value) / Double(target)))
    }
}
