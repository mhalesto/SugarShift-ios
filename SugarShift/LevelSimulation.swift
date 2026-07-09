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
            let startingBlockers = remainingBlockerCount(in: grid)
            var collectedGoalTiles = 0
            var createdSpecials = 0
            var detonatedBombs = 0
            var collectedIngredients = 0
            var collectedKeys = 0
            var openedChests = 0
            var maxCascadeDepth = 0
            var wasStuck = false

            while movesLeft > 0,
                  !isGoalComplete(config: config,
                                  grid: grid,
                                  score: score,
                                  collectedGoalTiles: collectedGoalTiles,
                                  createdSpecials: createdSpecials,
                                  detonatedBombs: detonatedBombs,
                                  collectedIngredients: collectedIngredients,
                                  collectedKeys: collectedKeys,
                                  openedChests: openedChests) {
                guard let move = chooseMove(in: grid, for: config) else {
                    wasStuck = true
                    guard reshuffle(&grid, rng: &rng, ensureMove: true) else { break }
                    continue
                }

                let originalGrid = grid
                let swap = Engine.swapIfValid(grid, move.0, move.1)
                guard swap.didSwap else {
                    wasStuck = true
                    guard reshuffle(&grid, rng: &rng, ensureMove: true) else { break }
                    continue
                }

                grid = swap.grid
                movesLeft -= 1

                if let colorBombClear = colorBombClearPositions(beforeSwap: originalGrid,
                                                                afterSwap: grid,
                                                                move: move) {
                    resolveExplicitClear(config: config,
                                         grid: &grid,
                                         matches: colorBombClear,
                                         rng: &rng,
                                         score: &score,
                                         collectedGoalTiles: &collectedGoalTiles,
                                         detonatedBombs: &detonatedBombs,
                                         collectedIngredients: &collectedIngredients,
                                         collectedKeys: &collectedKeys,
                                         openedChests: &openedChests)
                }

                let resolvedDepth = resolveCascades(config: config,
                                                    grid: &grid,
                                                    rng: &rng,
                                                    score: &score,
                                                    collectedGoalTiles: &collectedGoalTiles,
                                                    createdSpecials: &createdSpecials,
                                                    detonatedBombs: &detonatedBombs,
                                                    collectedIngredients: &collectedIngredients,
                                                    collectedKeys: &collectedKeys,
                                                    openedChests: &openedChests)
                maxCascadeDepth = max(maxCascadeDepth, resolvedDepth)
            }

            let won = isGoalComplete(config: config,
                                     grid: grid,
                                     score: score,
                                     collectedGoalTiles: collectedGoalTiles,
                                     createdSpecials: createdSpecials,
                                     detonatedBombs: detonatedBombs,
                                     collectedIngredients: collectedIngredients,
                                     collectedKeys: collectedKeys,
                                     openedChests: openedChests)
            let objective = LevelScoring.objectiveProgress(for: config,
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

    private static func chooseMove(in grid: Grid, for config: LevelConfig) -> (Pos, Pos)? {
        let moves = Engine.scoredLegalMoves(grid)
        guard !moves.isEmpty else { return nil }

        return moves.max { lhs, rhs in
            weightedMoveScore(lhs, grid: grid, config: config) <
                weightedMoveScore(rhs, grid: grid, config: config)
        }?.move
    }

    private static func weightedMoveScore(_ scoredMove: (move: (Pos, Pos), score: Int),
                                          grid: Grid,
                                          config: LevelConfig) -> Int {
        let a = scoredMove.move.0
        let b = scoredMove.move.1
        var score = scoredMove.score

        switch config.goal {
        case .score:
            break
        case .clearBlockers:
            score += blockerPressure(near: a, in: grid) * 35
            score += blockerPressure(near: b, in: grid) * 35
        case .collectColor(let index, _):
            let palette = Array(Theme.colors.prefix(config.colors))
            let target = palette[max(0, index) % max(1, palette.count)].lowercased()
            if grid[a.r][a.c]?.color.lowercased() == target { score += 25 }
            if grid[b.r][b.c]?.color.lowercased() == target { score += 25 }
        case .createSpecials, .detonateBombs:
            score += scoredMove.score >= 200 ? 80 : 0
        case .collectIngredients, .collectKeys, .collectIngredientsAndKeys:
            score += ingredientPressure(near: a, in: grid) * 30
            score += ingredientPressure(near: b, in: grid) * 30
        case .openChests:
            score += blockerPressure(near: a, in: grid) * 30
            score += blockerPressure(near: b, in: grid) * 30
        }

        return score
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
        var depth = 0
        var chocolateDamaged = false

        while depth < 24 {
            let groups = Engine.findMatchGroups(grid)
            let squares = Engine.findSquares(grid)
            guard !(groups.isEmpty && squares.isEmpty) else {
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
            for square in squares { matches.formUnion(square) }
            var spawn = Engine.specialSpawn(from: groups,
                                            bombRunLength: config.bombSpawnRunLength)
            if let square = squares.first,
               spawn == nil || spawn?.special == .stripedRow || spawn?.special == .stripedCol {
                spawn = SpecialSpawn(position: square[0], special: .fish)
            }
            let spawnColor = spawn.flatMap { grid[$0.position.r][$0.position.c]?.color }
            let preClear = cellSnapshot(grid, positions: matches)
            let triggeredBombs = triggeredBombCount(in: grid, positions: matches)
            let clear = Engine.clearMatches(&grid, matches: matches)
            guard clear.affectedCount > 0 else { break }

            score += scoreForClear(config: config, preClear: preClear, clear: clear, depth: depth)
            recordGoalProgress(config: config,
                               palette: Array(Theme.colors.prefix(config.colors)),
                               preClear: preClear,
                               cleared: clear.cleared,
                               detonatedBombsThisClear: triggeredBombs,
                               collectedGoalTiles: &collectedGoalTiles,
                               detonatedBombs: &detonatedBombs)
            openedChests += openedChestCount(preClear: preClear, clear: clear)
            let openedAdjacent = Engine.openAdjacentChests(&grid,
                                                           near: clear.cleared.union(clear.damagedBlockers))
            openedChests += openedAdjacent.count
            chocolateDamaged = chocolateDamaged ||
                clear.damagedBlockers.contains { preClear[$0]?.blocker?.type == .chocolate }

            if let spawn, clear.cleared.contains(spawn.position) {
                let color = spawnColor ?? Array(Theme.colors.prefix(config.colors)).randomElement(using: &rng) ?? Theme.colors[0]
                grid[spawn.position.r][spawn.position.c] = Cell(id: "sim-special-\(rng.next())",
                                                                color: color,
                                                                special: spawn.special,
                                                                kind: .normal)
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

        return depth
    }

    private static func resolveExplicitClear<R: RandomNumberGenerator>(config: LevelConfig,
                                                                       grid: inout Grid,
                                                                       matches: Set<Pos>,
                                                                       rng: inout R,
                                                                       score: inout Int,
                                                                       collectedGoalTiles: inout Int,
                                                                       detonatedBombs: inout Int,
                                                                       collectedIngredients: inout Int,
                                                                       collectedKeys: inout Int,
                                                                       openedChests: inout Int) {
        let preClear = cellSnapshot(grid, positions: matches)
        let triggeredBombs = triggeredBombCount(in: grid, positions: matches)
        let clear = Engine.clearMatches(&grid, matches: matches)
        guard clear.affectedCount > 0 else { return }
        score += scoreForClear(config: config, preClear: preClear, clear: clear, depth: 1)
        recordGoalProgress(config: config,
                           palette: Array(Theme.colors.prefix(config.colors)),
                           preClear: preClear,
                           cleared: clear.cleared,
                           detonatedBombsThisClear: triggeredBombs,
                           collectedGoalTiles: &collectedGoalTiles,
                           detonatedBombs: &detonatedBombs)
        openedChests += openedChestCount(preClear: preClear, clear: clear)
        openedChests += Engine.openAdjacentChests(&grid, near: clear.cleared.union(clear.damagedBlockers)).count
        settle(config: config,
               grid: &grid,
               rng: &rng,
               depth: 1,
               collectedIngredients: &collectedIngredients,
               collectedKeys: &collectedKeys,
               openedChests: &openedChests)
    }

    private static func settle<R: RandomNumberGenerator>(config: LevelConfig,
                                                        grid: inout Grid,
                                                        rng: inout R,
                                                        depth: Int,
                                                        collectedIngredients: inout Int,
                                                        collectedKeys: inout Int,
                                                        openedChests: inout Int) {
        grid = Engine.collapseAndRefill(grid,
                                        colors: Array(Theme.colors.prefix(config.colors)),
                                        mask: config.layout.mask,
                                        cascadeBoost: cascadeBoost(for: config, depth: depth),
                                        rng: &rng)
        grid = Engine.applyPortals(grid, pairs: config.layout.portalPairs)
        grid = Engine.applyConveyors(grid, belts: config.layout.conveyorBelts)
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
        var positions: [Pos] = []
        var cells: [Cell] = []
        for r in 0..<grid.count {
            for c in 0..<grid[r].count {
                if let cell = grid[r][c], cell.blocker == nil, cell.special == nil {
                    positions.append(Pos(r: r, c: c))
                    cells.append(cell)
                }
            }
        }
        guard !positions.isEmpty else { return false }

        var best = grid
        for attempt in 0..<30 {
            var candidate = grid
            let shuffled = cells.shuffled(using: &rng)
            for (index, pos) in positions.enumerated() {
                candidate[pos.r][pos.c]?.color = shuffled[index].color
                candidate[pos.r][pos.c]?.special = shuffled[index].special
                candidate[pos.r][pos.c]?.kind = shuffled[index].kind
            }
            best = candidate
            if !ensureMove || Engine.hasAnyMoves(candidate) || attempt == 29 {
                break
            }
        }

        grid = best
        return !ensureMove || Engine.hasAnyMoves(best)
    }

    private static func colorBombClearPositions(beforeSwap: Grid,
                                                afterSwap: Grid,
                                                move: (Pos, Pos)) -> Set<Pos>? {
        let a = move.0
        let b = move.1
        let aBefore = beforeSwap[a.r][a.c]
        let bBefore = beforeSwap[b.r][b.c]
        let aIsBomb = aBefore?.special == .colorBomb
        let bIsBomb = bBefore?.special == .colorBomb
        guard aIsBomb || bIsBomb else { return nil }

        let targetColor = aIsBomb ? bBefore?.color : aBefore?.color
        guard let targetColor else { return Set([a, b]) }
        var matches = Set([a, b])
        for r in 0..<afterSwap.count {
            for c in 0..<afterSwap[r].count {
                if afterSwap[r][c]?.color == targetColor {
                    matches.insert(Pos(r: r, c: c))
                }
            }
        }
        return matches
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
        for p in positions {
            if let cell = grid[p.r][p.c] {
                snapshot[p] = cell
            }
        }
        return snapshot
    }

    private static func triggeredBombCount(in grid: Grid, positions: Set<Pos>) -> Int {
        positions.reduce(0) { total, p in
            total + (grid[p.r][p.c]?.special == .bomb ? 1 : 0)
        }
    }

    private static func blockerPressure(near pos: Pos, in grid: Grid) -> Int {
        neighbors(of: pos, in: grid).filter { grid[$0.r][$0.c]?.blocker != nil }.count +
            (grid[pos.r][pos.c]?.blocker != nil ? 1 : 0)
    }

    private static func ingredientPressure(near pos: Pos, in grid: Grid) -> Int {
        neighbors(of: pos, in: grid).filter { grid[$0.r][$0.c]?.kind == .ingredient }.count +
            (grid[pos.r][pos.c]?.kind == .ingredient ? 1 : 0)
    }

    private static func neighbors(of pos: Pos, in grid: Grid) -> [Pos] {
        let rows = grid.count
        let cols = rows > 0 ? grid[0].count : 0
        return [
            Pos(r: pos.r - 1, c: pos.c),
            Pos(r: pos.r + 1, c: pos.c),
            Pos(r: pos.r, c: pos.c - 1),
            Pos(r: pos.r, c: pos.c + 1)
        ].filter { $0.r >= 0 && $0.r < rows && $0.c >= 0 && $0.c < cols }
    }

    private static func cascadeBoost(for config: LevelConfig, depth: Int) -> Double {
        guard depth <= 2 else { return 0 }

        let rangeBase: Double
        switch config.number {
        case 1...5: rangeBase = 0.24
        case 6...10: rangeBase = 0.20
        case 11...15: rangeBase = 0.16
        case 16...20: rangeBase = 0.13
        case 21...25: rangeBase = 0.10
        case 26...50: rangeBase = 0.08
        case 51...100: rangeBase = 0.06
        case 101...150: rangeBase = 0.05
        default: rangeBase = 0.04
        }

        let archetypeBoost: Double
        switch config.archetype {
        case .starter: archetypeBoost = 0.02
        case .combo: archetypeBoost = 0.03
        case .bombRush: archetypeBoost = 0.02
        case .crowded: archetypeBoost = 0.01
        case .ice, .lock, .finale: archetypeBoost = 0
        }

        let difficultyDrag: Double
        switch config.difficulty {
        case .normal: difficultyDrag = 0
        case .hard: difficultyDrag = 0.03
        case .superHard: difficultyDrag = 0.05
        case .crownChallenge: difficultyDrag = 0.06
        }

        return min(0.30, max(0, rangeBase + archetypeBoost - difficultyDrag))
    }
}
