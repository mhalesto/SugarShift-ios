import Foundation

struct LevelSimulationSummary: Equatable {
    let level: Int
    let attempts: Int
    let wins: Int
    let averageScore: Int
    let averageStars: Double
    let averageMovesLeft: Double
    let stuckBoardRate: Double
    let warnings: [String]

    var winRate: Double {
        guard attempts > 0 else { return 0 }
        return Double(wins) / Double(attempts)
    }
}

private struct SimulationClearStats {
    var tilesCleared = 0
    var blockersDamaged = 0
    var specialsTriggered = 0
    var objectiveHits = 0
    var depth = 0
    var objectiveEvents: [ObjectiveEvent] = []

    mutating func merge(_ other: SimulationClearStats) {
        tilesCleared += other.tilesCleared
        blockersDamaged += other.blockersDamaged
        specialsTriggered += other.specialsTriggered
        objectiveHits += other.objectiveHits
        depth = max(depth, other.depth)
        objectiveEvents.append(contentsOf: other.objectiveEvents)
    }
}

enum LevelSimulationBot {
    static func simulate(config: LevelConfig,
                         attempts: Int = 20,
                         seed: UInt64 = 0x5EED) -> LevelSimulationSummary {
        let runCount = max(1, attempts)
        var wins = 0
        var scoreTotal = 0
        var starsTotal = 0
        var movesLeftTotal = 0
        var stuckBoardAttempts = 0

        for attempt in 0..<runCount {
            let attemptSeed = LevelSeed.make(level: config.number,
                                             attempt: attempt,
                                             salt: seed)
            var rng = SeededRandomNumberGenerator(seed: attemptSeed)
            var grid = LevelBoardFactory.makeInitialBoard(config: config,
                                                          seed: attemptSeed,
                                                          minimumOpeningMoveScore: 0,
                                                          attempts: 8).grid

            var score = 0
            var movesLeft = config.moves
            var startingBlockers = remainingBlockerCount(in: grid)
            var collectedGoalTiles = 0
            var createdSpecials = 0
            var detonatedBombs = 0
            var collectedIngredients = 0
            var collectedKeys = 0
            var openedChests = 0
            var maxCascadeDepth = 0
            var wasStuck = false
            var bossShieldRemaining = config.isBoss ? (config.number >= 100 ? 3 : 2) : 0
            var bossTurnsUntilPressure = 4
            var smashCharge = 0
            var sugarRushCharged = false
            var flowLevel = 0
            var objectiveTracker = ObjectiveTracker(objectives: config.objectives)

            while movesLeft > 0,
                  !(config.definition != nil ? objectiveTracker.isComplete : (isGoalComplete(config: config,
                                  grid: grid,
                                  score: score,
                                  collectedGoalTiles: collectedGoalTiles,
                                  createdSpecials: createdSpecials,
                                  detonatedBombs: detonatedBombs,
                                  collectedIngredients: collectedIngredients,
                                  collectedKeys: collectedKeys,
                                  openedChests: openedChests) && bossShieldRemaining == 0)) {
                guard let move = chooseMove(in: grid,
                                            for: config,
                                            sugarRushCharged: sugarRushCharged) else {
                    wasStuck = true
                    guard reshuffle(&grid, rng: &rng, ensureMove: true) else { break }
                    continue
                }

                guard let swap = Engine.classifySwap(grid, move.0, move.1) else {
                    wasStuck = true
                    guard reshuffle(&grid, rng: &rng, ensureMove: true) else { break }
                    continue
                }

                grid = swap.grid
                movesLeft -= 1
                let scoreAtTurnStart = score
                let specialsAtTurnStart = createdSpecials
                let bombsBeforeMove = detonatedBombs
                let ingredientsBeforeMove = collectedIngredients
                let keysBeforeMove = collectedKeys
                let shieldBeforeMove = bossShieldRemaining
                var bossDamageThisTurn = 0
                var turnStats = SimulationClearStats()

                var explicitClear: Set<Pos>?
                var explicitChargeMultiplier = 1.0
                let turnIntent: TurnIntent
                switch swap.activation {
                case .normal:
                    turnIntent = .match
                    break
                case .colorBomb(let position, let targetColor):
                    turnIntent = .special
                    explicitChargeMultiplier = 1.18
                    var matches: Set<Pos> = [position]
                    for r in 0..<grid.count {
                        for c in 0..<grid[r].count where grid[r][c]?.color == targetColor {
                            matches.insert(Pos(r: r, c: c))
                        }
                    }
                    explicitClear = Engine.expandMatchesWithSpecials(
                        grid,
                        matches,
                        bigger: config.modifiers.contains(.specialsExplodeBigger),
                        excludingSpecialsAt: [position])
                case .specialCombo(let kind, let first, let second, let targetColor):
                    turnIntent = .specialCombo
                    explicitChargeMultiplier = 1.30
                    bossDamageThisTurn = 2
                    let excluded: Set<Pos> = [move.0, move.1]
                    explicitClear = Engine.resolveSpecialCombo(
                        grid,
                        kind: kind,
                        first: first,
                        second: second,
                        positions: move,
                        targetColor: targetColor,
                        rankedFishTargets: rankedFishTargets(in: grid,
                                                            for: config,
                                                            excluding: excluded),
                        bigger: config.modifiers.contains(.specialsExplodeBigger))
                }

                if let explicitClear {
                    turnStats.merge(resolveExplicitClearDetailed(
                        config: config,
                        grid: &grid,
                        matches: explicitClear,
                        rng: &rng,
                        score: &score,
                        collectedGoalTiles: &collectedGoalTiles,
                        detonatedBombs: &detonatedBombs,
                        collectedIngredients: &collectedIngredients,
                        collectedKeys: &collectedKeys,
                        openedChests: &openedChests,
                        smashCharge: &smashCharge,
                        sugarRushCharged: &sugarRushCharged,
                        sugarRushPreferredAnchor: move.1,
                        chargeMultiplier: explicitChargeMultiplier))
                }

                let cascadeStats = resolveCascadesDetailed(config: config,
                                                           grid: &grid,
                                                           rng: &rng,
                                                           score: &score,
                                                           collectedGoalTiles: &collectedGoalTiles,
                                                           createdSpecials: &createdSpecials,
                                                           detonatedBombs: &detonatedBombs,
                                                           collectedIngredients: &collectedIngredients,
                                                           collectedKeys: &collectedKeys,
                                                           openedChests: &openedChests,
                                                           smashCharge: &smashCharge,
                                                           sugarRushCharged: &sugarRushCharged,
                                                           sugarRushPreferredAnchor: move.1,
                                                           advancesConveyors: true)
                turnStats.merge(cascadeStats)
                var resolvedDepth = cascadeStats.depth
                maxCascadeDepth = max(maxCascadeDepth, resolvedDepth)
                if bossDamageThisTurn == 0,
                   resolvedDepth >= 3 || detonatedBombs > bombsBeforeMove {
                    bossDamageThisTurn = 1
                }
                bossShieldRemaining = max(0, bossShieldRemaining - bossDamageThisTurn)

                let mastery = TurnMasteryPolicy.evaluate(
                    flow: flowLevel,
                    intent: turnIntent,
                    tilesCleared: turnStats.tilesCleared,
                    blockersDamaged: turnStats.blockersDamaged,
                    specialsTriggered: turnStats.specialsTriggered,
                    specialsCreated: max(0, createdSpecials - specialsAtTurnStart),
                    objectiveHits: turnStats.objectiveHits,
                    cascadeDepth: turnStats.depth,
                    scoreEarned: max(0, score - scoreAtTurnStart))
                flowLevel = mastery.flowAfter
                score += mastery.scoreBonus
                smashCharge = min(100, smashCharge + mastery.smashBonus)
                if mastery.chargesSugarRush { sugarRushCharged = true }

                // Model the same player-timed Smash tiers as live gameplay. The
                // greedy bot releases as soon as a tier is available, giving the
                // balance report a conservative, deterministic estimate of the
                // mechanic's power rather than ignoring it entirely.
                if movesLeft > 0,
                   let smashTier = PlayerSmashTier.tier(for: smashCharge),
                   let smashAnalysis = TacticalSmashEvaluator.bestTarget(
                    tier: smashTier,
                    in: grid,
                    config: config,
                    sugarRushCharged: sugarRushCharged) {
                    let smashTarget = smashAnalysis.center
                    movesLeft -= 1
                    smashCharge = max(0, smashCharge - smashTier.chargeCost)
                    let smashScoreStart = score
                    let smashSpecialsStart = createdSpecials
                    var footprint = Engine.playerSmashFootprint(in: grid,
                                                                centeredAt: smashTarget,
                                                                tier: smashTier)
                    footprint = Engine.expandMatchesWithSpecials(
                        grid,
                        footprint,
                        bigger: config.modifiers.contains(.specialsExplodeBigger))
                    var smashStats = resolveExplicitClearDetailed(
                        config: config,
                        grid: &grid,
                        matches: footprint,
                        rng: &rng,
                        score: &score,
                        collectedGoalTiles: &collectedGoalTiles,
                        detonatedBombs: &detonatedBombs,
                        collectedIngredients: &collectedIngredients,
                        collectedKeys: &collectedKeys,
                        openedChests: &openedChests,
                        smashCharge: &smashCharge,
                        sugarRushCharged: &sugarRushCharged,
                        sugarRushPreferredAnchor: smashTarget,
                        chargeMultiplier: 0)
                    let postSmash = resolveCascadesDetailed(
                        config: config,
                        grid: &grid,
                        rng: &rng,
                        score: &score,
                        collectedGoalTiles: &collectedGoalTiles,
                        createdSpecials: &createdSpecials,
                        detonatedBombs: &detonatedBombs,
                        collectedIngredients: &collectedIngredients,
                        collectedKeys: &collectedKeys,
                        openedChests: &openedChests,
                        smashCharge: &smashCharge,
                        sugarRushCharged: &sugarRushCharged,
                        sugarRushPreferredAnchor: smashTarget,
                        chargeMultiplier: 0,
                        advancesConveyors: true)
                    smashStats.merge(postSmash)
                    turnStats.objectiveEvents.append(contentsOf: smashStats.objectiveEvents)
                    let smashMastery = TurnMasteryPolicy.evaluate(
                        flow: flowLevel,
                        intent: .playerSmash,
                        tilesCleared: smashStats.tilesCleared,
                        blockersDamaged: smashStats.blockersDamaged,
                        specialsTriggered: smashStats.specialsTriggered,
                        specialsCreated: max(0, createdSpecials - smashSpecialsStart),
                        objectiveHits: smashStats.objectiveHits,
                        cascadeDepth: smashStats.depth,
                        scoreEarned: max(0, score - smashScoreStart))
                    flowLevel = smashMastery.flowAfter
                    score += smashMastery.scoreBonus
                    resolvedDepth = max(resolvedDepth, postSmash.depth)
                    maxCascadeDepth = max(maxCascadeDepth, postSmash.depth)
                    bossShieldRemaining = max(0, bossShieldRemaining - smashTier.bossDamage)
                }

                let primaryComplete = isGoalComplete(config: config,
                                                     grid: grid,
                                                     score: score,
                                                     collectedGoalTiles: collectedGoalTiles,
                                                     createdSpecials: createdSpecials,
                                                     detonatedBombs: detonatedBombs,
                                                     collectedIngredients: collectedIngredients,
                                                     collectedKeys: collectedKeys,
                                                     openedChests: openedChests)
                if config.isBoss, bossShieldRemaining > 0, !primaryComplete {
                    bossTurnsUntilPressure -= 1
                    if bossTurnsUntilPressure <= 0 {
                        if seedBossPressure(in: &grid, rng: &rng), case .clearBlockers = config.goal {
                            startingBlockers += 1
                        }
                        bossTurnsUntilPressure = bossShieldRemaining == (config.number >= 100 ? 3 : 2) ? 4 : 3
                    }
                }
                for event in turnStats.objectiveEvents { objectiveTracker.consume(event) }
                objectiveTracker.consume(.scoreEarned(max(0, score - scoreAtTurnStart)))
                objectiveTracker.consume(.specialsCreated(count: max(0, createdSpecials - specialsAtTurnStart)))
                objectiveTracker.consume(.bombsDetonated(count: max(0, detonatedBombs - bombsBeforeMove)))
                objectiveTracker.consume(.ingredientsCollected(count: max(0, collectedIngredients - ingredientsBeforeMove)))
                objectiveTracker.consume(.keysCollected(count: max(0, collectedKeys - keysBeforeMove)))
                objectiveTracker.consume(.bossShieldDamaged(count: max(0, shieldBeforeMove - bossShieldRemaining)))
                objectiveTracker.consume(.combo(depth: resolvedDepth))
            }

            let won = config.definition != nil ? objectiveTracker.isComplete : (bossShieldRemaining == 0 && isGoalComplete(config: config,
                                     grid: grid,
                                     score: score,
                                     collectedGoalTiles: collectedGoalTiles,
                                     createdSpecials: createdSpecials,
                                     detonatedBombs: detonatedBombs,
                                     collectedIngredients: collectedIngredients,
                                     collectedKeys: collectedKeys,
                                     openedChests: openedChests))
            let objective = config.definition != nil ? objectiveTracker.progressFraction : LevelScoring.objectiveProgress(for: config,
                                                           score: score,
                                                           startingBlockers: startingBlockers,
                                                           remainingBlockers: remainingBlockerCount(in: grid),
                                                           collectedGoalTiles: collectedGoalTiles,
                                                           createdSpecials: createdSpecials,
                                                           detonatedBombs: detonatedBombs,
                                                           collectedIngredients: collectedIngredients,
                                                           collectedKeys: collectedKeys,
                                                           openedChests: openedChests)
            let performance = LevelAttemptPerformance(score: score,
                                                      movesLeft: movesLeft,
                                                      movesAtStart: config.moves,
                                                      maxCascadeDepth: maxCascadeDepth,
                                                      createdSpecials: createdSpecials,
                                                      detonatedBombs: detonatedBombs,
                                                      objectiveProgress: objective)
            let stars = LevelScoring.stars(for: config, performance: performance, won: won)

            wins += won ? 1 : 0
            scoreTotal += score
            starsTotal += stars
            movesLeftTotal += movesLeft
            stuckBoardAttempts += wasStuck ? 1 : 0
        }

        let averageScore = scoreTotal / runCount
        let averageStars = Double(starsTotal) / Double(runCount)
        let averageMovesLeft = Double(movesLeftTotal) / Double(runCount)
        let stuckRate = Double(stuckBoardAttempts) / Double(runCount)
        let winRate = Double(wins) / Double(runCount)
        var warnings: [String] = []
        if winRate < 0.35 { warnings.append("simulation win rate below 35%") }
        if winRate > 0.98, averageStars > 2.7 { warnings.append("simulation may be too easy") }
        if stuckRate > 0.20 { warnings.append("frequent no-move reshuffles") }

        return LevelSimulationSummary(level: config.number,
                                      attempts: runCount,
                                      wins: wins,
                                      averageScore: averageScore,
                                      averageStars: averageStars,
                                      averageMovesLeft: averageMovesLeft,
                                      stuckBoardRate: stuckRate,
                                      warnings: warnings)
    }

    static func simulate(levelRange: ClosedRange<Int>,
                         attemptsPerLevel: Int = 12,
                         seed: UInt64 = 0x5EED) -> [LevelSimulationSummary] {
        levelRange.map { level in
            simulate(config: Levels.config(for: level),
                     attempts: attemptsPerLevel,
                     seed: seed)
        }
    }

    private static func chooseMove(in grid: Grid,
                                   for config: LevelConfig,
                                   sugarRushCharged: Bool) -> (Pos, Pos)? {
        TacticalMoveEvaluator.rankedMoves(in: grid,
                                          config: config,
                                          sugarRushCharged: sugarRushCharged).first?.move
    }

    private static func simulationObjectiveImpact(config: LevelConfig,
                                                  preClear: [Pos: Cell],
                                                  clear: ClearResult) -> Int {
        switch config.goal {
        case .clearBlockers:
            return clear.damagedBlockers.count
        case .collectColor(let index, _):
            let palette = config.pieceTypes.map(\.legacyToken)
            let target = palette[max(0, index) % max(1, palette.count)].lowercased()
            return clear.cleared.filter { preClear[$0]?.color.lowercased() == target }.count
        case .openChests:
            return clear.damagedBlockers.filter { preClear[$0]?.blocker?.type == .chest }.count
        case .detonateBombs:
            return clear.cleared.filter { preClear[$0]?.special == .bomb }.count
        default:
            return 0
        }
    }

    static func resolveCascades<R: RandomNumberGenerator>(config: LevelConfig,
                                                         grid: inout Grid,
                                                         rng: inout R,
                                                         score: inout Int,
                                                         collectedGoalTiles: inout Int,
                                                         createdSpecials: inout Int,
                                                         detonatedBombs: inout Int,
                                                         collectedIngredients: inout Int,
                                                         collectedKeys: inout Int,
                                                         openedChests: inout Int) -> Int {
        var smashCharge = 0
        var sugarRushCharged = false
        return resolveCascadesDetailed(config: config,
                                       grid: &grid,
                                       rng: &rng,
                                       score: &score,
                                       collectedGoalTiles: &collectedGoalTiles,
                                       createdSpecials: &createdSpecials,
                                       detonatedBombs: &detonatedBombs,
                                       collectedIngredients: &collectedIngredients,
                                       collectedKeys: &collectedKeys,
                                       openedChests: &openedChests,
                                       smashCharge: &smashCharge,
                                       sugarRushCharged: &sugarRushCharged,
                                       advancesConveyors: true).depth
    }

    private static func resolveCascadesDetailed<R: RandomNumberGenerator>(
        config: LevelConfig,
        grid: inout Grid,
        rng: inout R,
        score: inout Int,
        collectedGoalTiles: inout Int,
        createdSpecials: inout Int,
        detonatedBombs: inout Int,
        collectedIngredients: inout Int,
        collectedKeys: inout Int,
        openedChests: inout Int,
        smashCharge: inout Int,
        sugarRushCharged: inout Bool,
        sugarRushPreferredAnchor: Pos? = nil,
        chargeMultiplier: Double = 1,
        advancesConveyors: Bool = false
    ) -> SimulationClearStats {
        var depth = 0
        var chocolateDamaged = false
        var stats = SimulationClearStats()
        var conveyorPending = advancesConveyors

        while depth < 24 {
            let groups = Engine.findMatchGroups(grid)
            let squares = Engine.findSquares(grid)
            guard !(groups.isEmpty && squares.isEmpty) else {
                if conveyorPending {
                    conveyorPending = false
                    grid = Engine.applyConveyors(grid, belts: config.layout.conveyorBelts)
                    settle(config: config, grid: &grid, rng: &rng, depth: depth,
                           collectedIngredients: &collectedIngredients,
                           collectedKeys: &collectedKeys, openedChests: &openedChests)
                    if !Engine.findMatches(grid).isEmpty || !Engine.findSquares(grid).isEmpty { continue }
                }
                if !chocolateDamaged {
                    let spreads = config.modifiers.contains(.chocolateSpreadsFaster) ? 2 : 1
                    for _ in 0..<spreads {
                        let spread = Engine.spreadChocolate(grid, rng: &rng)
                        grid = spread.0
                        if spread.1 == nil { break }
                    }
                }
                break
            }

            depth += 1
            var matches = Set<Pos>()
            for group in groups { matches.formUnion(group) }
            matches = Engine.expandMatchesWithSpecials(grid,
                                                       matches,
                                                       bigger: config.modifiers.contains(.specialsExplodeBigger))
            let fishCount = matches.reduce(into: 0) { count, p in
                if grid[p.r][p.c]?.special == .fish { count += 1 }
            }
            if fishCount > 0 {
                matches.formUnion(rankedFishTargets(in: grid,
                                                    for: config,
                                                    excluding: matches)
                    .prefix(fishCount))
            }
            for square in squares { matches.formUnion(square) }
            if depth == 1, sugarRushCharged {
                let rush = Engine.sugarRushResolution(
                    in: grid,
                    base: matches,
                    preferredAnchor: sugarRushPreferredAnchor)
                if rush.anchor != nil {
                    matches = rush.positions
                }
                sugarRushCharged = false
            }
            var spawn = Engine.specialSpawn(from: groups,
                                            bombRunLength: config.bombSpawnRunLength)
            if let square = squares.first,
               spawn == nil || spawn?.special == .stripedRow || spawn?.special == .stripedCol {
                spawn = SpecialSpawn(position: square[0], special: .fish)
            }
            let spawnColor = spawn.flatMap { grid[$0.position.r][$0.position.c]?.color }
            let preClear = cellSnapshot(grid, positions: matches)
            let triggeredBombs = triggeredBombCount(in: grid, positions: matches)
            let triggeredSpecials = matches.filter { preClear[$0]?.special != nil }.count
            let clear = Engine.clearMatches(&grid, matches: matches,
                                             context: triggeredSpecials > 0 ? .special : .normal)
            guard clear.affectedCount > 0 else { break }
            stats.objectiveEvents.append(contentsOf: objectiveEvents(preClear: preClear, clear: clear, grid: grid))

            score += scoreForClear(config: config, preClear: preClear, clear: clear, depth: depth)
            recordGoalProgress(config: config,
                               palette: config.pieceTypes.map(\.legacyToken),
                               preClear: preClear,
                               cleared: clear.cleared,
                               detonatedBombsThisClear: triggeredBombs,
                               collectedGoalTiles: &collectedGoalTiles,
                               detonatedBombs: &detonatedBombs)
            openedChests += openedChestCount(preClear: preClear, clear: clear)
            chocolateDamaged = chocolateDamaged ||
                clear.damagedBlockers.contains { preClear[$0]?.blocker?.type == .chocolate }
            stats.tilesCleared += clear.cleared.count
            stats.blockersDamaged += clear.damagedBlockers.count
            stats.specialsTriggered += triggeredSpecials
            stats.depth = max(stats.depth, depth)
            let objectiveHits = simulationObjectiveImpact(config: config,
                                                           preClear: preClear,
                                                           clear: clear)
            stats.objectiveHits += objectiveHits
            smashCharge = min(100, smashCharge + GameScene.smashChargeGain(
                tilesCleared: clear.cleared.count,
                blockersDamaged: clear.damagedBlockers.count,
                specialsTriggered: triggeredSpecials,
                multiplier: (depth == 1 ? 1.0 : 0.50) * max(0, chargeMultiplier),
                objectiveHits: objectiveHits))
            if depth >= 3 { sugarRushCharged = true }

            if let spawn, clear.cleared.contains(spawn.position) {
                let color = spawnColor ?? config.pieceTypes.map(\.legacyToken).randomElement(using: &rng) ?? Theme.colors[0]
                grid[spawn.position.r][spawn.position.c]?.piece = Piece(id: "sim-special-\(rng.next())",
                                                                       legacyColorToken: color,
                                                                       special: spawn.special)
                createdSpecials += 1
            }

            settle(config: config,
                   grid: &grid,
                   rng: &rng,
                   depth: depth,
                   collectedIngredients: &collectedIngredients,
                   collectedKeys: &collectedKeys,
                   openedChests: &openedChests)
        }

        return stats
    }

    private static func resolveExplicitClearDetailed<R: RandomNumberGenerator>(
        config: LevelConfig,
        grid: inout Grid,
        matches: Set<Pos>,
        rng: inout R,
        score: inout Int,
        collectedGoalTiles: inout Int,
        detonatedBombs: inout Int,
        collectedIngredients: inout Int,
        collectedKeys: inout Int,
        openedChests: inout Int,
        smashCharge: inout Int,
        sugarRushCharged: inout Bool,
        sugarRushPreferredAnchor: Pos? = nil,
        chargeMultiplier: Double
    ) -> SimulationClearStats {
        var resolvedMatches = matches
        if sugarRushCharged {
            let rush = Engine.sugarRushResolution(in: grid,
                                                  base: matches,
                                                  preferredAnchor: sugarRushPreferredAnchor)
            if rush.anchor != nil {
                resolvedMatches = rush.positions
                sugarRushCharged = false
            }
        }
        let preClear = cellSnapshot(grid, positions: resolvedMatches)
        let triggeredBombs = triggeredBombCount(in: grid, positions: resolvedMatches)
        let triggeredSpecials = resolvedMatches.filter { preClear[$0]?.special != nil }.count
        let clear = Engine.clearMatches(&grid, matches: resolvedMatches,
                                        context: chargeMultiplier == 0 ? .hammer : .combo)
        guard clear.affectedCount > 0 else { return SimulationClearStats() }
        score += scoreForClear(config: config, preClear: preClear, clear: clear, depth: 1)
        recordGoalProgress(config: config,
                           palette: config.pieceTypes.map(\.legacyToken),
                           preClear: preClear,
                           cleared: clear.cleared,
                           detonatedBombsThisClear: triggeredBombs,
                           collectedGoalTiles: &collectedGoalTiles,
                           detonatedBombs: &detonatedBombs)
        openedChests += openedChestCount(preClear: preClear, clear: clear)
        let objectiveHits = simulationObjectiveImpact(config: config,
                                                       preClear: preClear,
                                                       clear: clear)
        smashCharge = min(100, smashCharge + GameScene.smashChargeGain(
            tilesCleared: clear.cleared.count,
            blockersDamaged: clear.damagedBlockers.count,
            specialsTriggered: triggeredSpecials,
            multiplier: chargeMultiplier,
            objectiveHits: objectiveHits))
        settle(config: config,
               grid: &grid,
               rng: &rng,
               depth: 1,
               collectedIngredients: &collectedIngredients,
               collectedKeys: &collectedKeys,
               openedChests: &openedChests)
        return SimulationClearStats(tilesCleared: clear.cleared.count,
                                    blockersDamaged: clear.damagedBlockers.count,
                                    specialsTriggered: triggeredSpecials,
                                    objectiveHits: objectiveHits,
                                    depth: 1,
                                    objectiveEvents: objectiveEvents(preClear: preClear, clear: clear, grid: grid))
    }

    private static func objectiveEvents(preClear: [Pos: Cell], clear: ClearResult, grid: Grid) -> [ObjectiveEvent] {
        var events: [ObjectiveEvent] = clear.cleared.compactMap { position in
            preClear[position]?.piece.map { .piecesCleared(color: $0.color, count: 1) }
        }
        for position in clear.damagedBlockers {
            if let blocker = preClear[position]?.blocker, grid[position.r][position.c]?.blocker == nil {
                events.append(.blockerDestroyed(type: blocker.type, count: 1))
            }
        }
        return events
    }

    private static func settle<R: RandomNumberGenerator>(config: LevelConfig,
                                                        grid: inout Grid,
                                                        rng: inout R,
                                                        depth: Int,
                                                        collectedIngredients: inout Int,
                                                        collectedKeys: inout Int,
                                                        openedChests: inout Int) {
        grid = Engine.collapseAndRefill(grid,
                                        colors: config.pieceTypes.map(\.legacyToken),
                                        mask: config.layout.mask,
                                        cascadeBoost: cascadeBoost(for: config, depth: depth),
                                        portals: config.layout.portalPairs,
                                        spawnWeights: config.spawnWeights,
                                        rng: &rng)
        let ingredientResult = Engine.collectIngredientsAtBottom(grid,
                                                                 mask: config.layout.mask)
        grid = ingredientResult.0
        collectedIngredients += ingredientResult.1.count
        let keyResult = Engine.collectKeysAtBottom(grid,
                                                   mask: config.layout.mask)
        grid = keyResult.0
        collectedKeys += keyResult.1.count
        for _ in keyResult.1 {
            if Engine.openFirstChest(&grid) != nil {
                openedChests += 1
            }
        }
    }

    private static func reshuffle<R: RandomNumberGenerator>(_ grid: inout Grid,
                                                            rng: inout R,
                                                            ensureMove: Bool) -> Bool {
        guard let candidate = Engine.shuffledPlayableGrid(grid, rng: &rng) else { return false }
        grid = candidate
        return true
    }

    private static func seedBossPressure<R: RandomNumberGenerator>(in grid: inout Grid,
                                                                    rng: inout R) -> Bool {
        var candidates: [Pos] = []
        for r in 0..<grid.count {
            for c in 0..<grid[r].count {
                guard let cell = grid[r][c],
                      cell.kind == .normal,
                      cell.blocker == nil,
                      cell.special == nil else { continue }
                candidates.append(Pos(r: r, c: c))
            }
        }
        guard let target = candidates.randomElement(using: &rng) else { return false }
        grid[target.r][target.c]?.blocker = Blocker(type: .vine, hits: 1)
        return true
    }

    private static func rankedFishTargets(in grid: Grid,
                                          for config: LevelConfig,
                                          excluding: Set<Pos>) -> [Pos] {
        TacticalMoveEvaluator.rankedTargets(in: grid,
                                            config: config,
                                            excluding: excluding)
    }

    private static func recordGoalProgress(config: LevelConfig,
                                           palette: [String],
                                           preClear: [Pos: Cell],
                                           cleared: Set<Pos>,
                                           detonatedBombsThisClear: Int,
                                           collectedGoalTiles: inout Int,
                                           detonatedBombs: inout Int) {
        if case .collectColor(let index, _) = config.goal {
            let targetColor = palette[max(0, index) % max(1, palette.count)].lowercased()
            collectedGoalTiles += cleared.filter {
                preClear[$0]?.color.lowercased() == targetColor
            }.count
        }

        detonatedBombs += detonatedBombsThisClear
    }

    private static func isGoalComplete(config: LevelConfig,
                                       grid: Grid,
                                       score: Int,
                                       collectedGoalTiles: Int,
                                       createdSpecials: Int,
                                       detonatedBombs: Int,
                                       collectedIngredients: Int,
                                       collectedKeys: Int,
                                       openedChests: Int) -> Bool {
        switch config.goal {
        case .score:
            return score >= config.target
        case .clearBlockers:
            return remainingBlockerCount(in: grid) == 0
        case .collectColor(_, let count):
            return collectedGoalTiles >= count
        case .createSpecials(let count):
            return createdSpecials >= count
        case .detonateBombs(let count):
            return detonatedBombs >= count
        case .collectIngredients(let count):
            return collectedIngredients >= count
        case .collectKeys(let count):
            return collectedKeys >= count
        case .openChests(let count):
            return openedChests >= count
        case .collectIngredientsAndKeys(let ingredients, let keys):
            return collectedIngredients >= ingredients && collectedKeys >= keys
        }
    }

    private static func openedChestCount(preClear: [Pos: Cell], clear: ClearResult) -> Int {
        clear.damagedBlockers.filter { pos in
            preClear[pos]?.blocker?.type == .chest &&
                (preClear[pos]?.blocker?.hits ?? 0) <= 1
        }.count
    }

    private static func scoreForClear(config: LevelConfig,
                                      preClear: [Pos: Cell],
                                      clear: ClearResult,
                                      depth: Int) -> Int {
        let base = clear.affectedCount * 10 * depth
        guard config.modifiers.contains(.bananaScoreDouble) else { return base }
        let bananaBonus = clear.cleared.filter { pos in
            guard let color = preClear[pos]?.color else { return false }
            return Theme.fruitIndex(forColor: color) == 4
        }.count * 10 * depth
        return base + bananaBonus
    }

    private static func remainingBlockerCount(in grid: Grid) -> Int {
        grid.reduce(0) { partial, row in
            partial + row.filter { $0?.blocker != nil }.count
        }
    }

    private static func cellSnapshot(_ grid: Grid, positions: Set<Pos>) -> [Pos: Cell] {
        var snapshot: [Pos: Cell] = [:]
        for r in grid.indices {
            for c in grid[r].indices {
                if let cell = grid[r][c] { snapshot[Pos(r: r, c: c)] = cell }
            }
        }
        return snapshot
    }

    private static func triggeredBombCount(in grid: Grid, positions: Set<Pos>) -> Int {
        positions.reduce(0) { total, p in
            total + (grid[p.r][p.c]?.special == .bomb ? 1 : 0)
        }
    }

    private static func cascadeBoost(for config: LevelConfig, depth: Int) -> Double {
        guard depth <= 2 else { return 0 }

        let rangeBase: Double
        switch config.number {
        case 1...5: rangeBase = 0.12
        case 6...10: rangeBase = 0.10
        case 11...25: rangeBase = 0.07
        case 26...50: rangeBase = 0.05
        case 51...100: rangeBase = 0.035
        case 101...150: rangeBase = 0.025
        default: rangeBase = 0.02
        }

        let archetypeBoost: Double
        switch config.archetype {
        case .starter: archetypeBoost = 0.01
        case .combo: archetypeBoost = 0.02
        case .bombRush: archetypeBoost = 0.01
        case .crowded: archetypeBoost = 0.005
        case .ice, .lock, .finale: archetypeBoost = 0
        }

        let difficultyDrag: Double
        switch config.difficulty {
        case .normal: difficultyDrag = 0
        case .hard: difficultyDrag = 0.03
        case .superHard: difficultyDrag = 0.05
        case .crownChallenge: difficultyDrag = 0.06
        }

        return min(0.20, max(0, rangeBase + archetypeBoost - difficultyDrag))
    }
}
