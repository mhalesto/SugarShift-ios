import Foundation

struct LevelBoardBuild {
    let grid: Grid
    let seed: UInt64
    let openingMoveScore: Int
}

enum LevelBoardFactory {
    static func makeInitialBoard(config: LevelConfig,
                                 seed: UInt64,
                                 minimumOpeningMoveScore: Int = 0,
                                 attempts: Int = 24) -> LevelBoardBuild {
        let palette = Array(Theme.colors.prefix(config.colors))
        var bestGrid: Grid = []
        var bestSeed = seed
        var bestScore = -1

        let requestedAttempts = max(1, attempts)
        let safetyAttemptLimit = max(requestedAttempts, 128)
        for attempt in 0..<safetyAttemptLimit {
            let attemptSeed = seed &+ UInt64(attempt) &* 0x9E3779B97F4A7C15
            var rng = SeededRandomNumberGenerator(seed: attemptSeed)
            var grid = Engine.createInitialGrid(rows: config.rows,
                                                cols: config.cols,
                                                colors: palette,
                                                mask: config.layout.mask,
                                                rng: &rng)
            seedBlockers(layout: config.layout, grid: &grid, rng: &rng)
            seedAdvancedMechanics(layout: config.layout, grid: &grid, palette: palette, rng: &rng)
            seedIngredients(layout: config.layout, grid: &grid, rng: &rng)
            seedKeys(layout: config.layout, grid: &grid, rng: &rng)
            seedStartingBombs(layout: config.layout, grid: &grid, rng: &rng)
            guard Engine.findMatches(grid).isEmpty,
                  Engine.findSquares(grid).isEmpty else { continue }

            let score = Engine.bestMoveScore(grid)
            if score > bestScore {
                bestGrid = grid
                bestSeed = attemptSeed
                bestScore = score
            }
            if score >= minimumOpeningMoveScore || attempt + 1 >= requestedAttempts {
                break
            }
        }

        if bestScore <= 0, let repaired = repairOpeningMove(in: bestGrid, palette: palette) {
            bestGrid = repaired
            bestScore = Engine.bestMoveScore(repaired)
        }

        return LevelBoardBuild(grid: bestGrid,
                               seed: bestSeed,
                               openingMoveScore: max(0, bestScore))
    }

    static func playablePositions(in grid: Grid, includeBlockers: Bool = true) -> [Pos] {
        var positions: [Pos] = []
        for r in 0..<grid.count {
            for c in 0..<grid[r].count {
                guard let cell = grid[r][c] else { continue }
                if includeBlockers || cell.blocker == nil {
                    positions.append(Pos(r: r, c: c))
                }
            }
        }
        return positions
    }

    private static func seedBlockers<R: RandomNumberGenerator>(layout: LevelLayout,
                                                               grid: inout Grid,
                                                               rng: inout R) {
        guard layout.iceCount > 0 || layout.lockCount > 0 else { return }
        var candidates = playablePositions(in: grid)
        candidates.shuffle(using: &rng)

        for p in candidates.prefix(layout.iceCount) {
            grid[p.r][p.c]?.blocker = Blocker(type: .ice, hits: 2)
        }

        let lockSlice = candidates.dropFirst(layout.iceCount).prefix(layout.lockCount)
        for p in lockSlice {
            grid[p.r][p.c]?.blocker = Blocker(type: .lock, hits: 1)
        }
    }

    private static func seedAdvancedMechanics<R: RandomNumberGenerator>(layout: LevelLayout,
                                                                        grid: inout Grid,
                                                                        palette: [String],
                                                                        rng: inout R) {
        guard layout.jellyCount > 0 ||
              layout.crateCount > 0 ||
              layout.colorLockCount > 0 ||
              layout.chocolateCount > 0 ||
              layout.chestCount > 0 ||
              layout.vineCount > 0 ||
              layout.countdownCount > 0 else { return }

        var candidates = playablePositions(in: grid, includeBlockers: false)
        candidates.shuffle(using: &rng)

        var index = 0
        func nextPosition() -> Pos? {
            guard index < candidates.count else { return nil }
            defer { index += 1 }
            return candidates[index]
        }

        for _ in 0..<layout.jellyCount {
            guard let p = nextPosition() else { break }
            grid[p.r][p.c]?.blocker = Blocker(type: .jelly, hits: 1)
        }

        for _ in 0..<layout.crateCount {
            guard let p = nextPosition() else { break }
            grid[p.r][p.c]?.blocker = Blocker(type: .crate, hits: 3)
        }

        for i in 0..<layout.colorLockCount {
            guard let p = nextPosition() else { break }
            let required = palette[i % max(1, palette.count)]
            let color = safeColorLockColor(at: p,
                                           in: grid,
                                           palette: palette,
                                           preferred: required)
            grid[p.r][p.c]?.color = color
            grid[p.r][p.c]?.blocker = Blocker(type: .colorLock,
                                              hits: 1,
                                              requiredColor: color)
        }

        for _ in 0..<layout.chocolateCount {
            guard let p = nextPosition() else { break }
            grid[p.r][p.c]?.blocker = Blocker(type: .chocolate, hits: 1)
        }

        for _ in 0..<layout.chestCount {
            guard let p = nextPosition() else { break }
            grid[p.r][p.c]?.blocker = Blocker(type: .chest, hits: 1)
        }

        for _ in 0..<layout.vineCount {
            guard let p = nextPosition() else { break }
            grid[p.r][p.c]?.blocker = Blocker(type: .vine, hits: 1)
        }

        for _ in 0..<layout.countdownCount {
            guard let p = nextPosition() else { break }
            // Generous opening fuse so the first encounter is teachable; it
            // re-arms shorter after each detonation.
            grid[p.r][p.c]?.blocker = Blocker(type: .countdown, hits: 1, countdown: 9)
        }
    }

    private static func seedIngredients<R: RandomNumberGenerator>(layout: LevelLayout,
                                                                  grid: inout Grid,
                                                                  rng: inout R) {
        seedDropItems(count: layout.ingredientCount, kind: .ingredient, grid: &grid, rng: &rng)
    }

    private static func seedKeys<R: RandomNumberGenerator>(layout: LevelLayout,
                                                           grid: inout Grid,
                                                           rng: inout R) {
        seedDropItems(count: layout.keyCount, kind: .key, grid: &grid, rng: &rng)
    }

    private static func seedDropItems<R: RandomNumberGenerator>(count: Int,
                                                                kind: CellKind,
                                                                grid: inout Grid,
                                                                rng: inout R) {
        guard count > 0 else { return }
        let rows = grid.count
        let cols = rows > 0 ? grid[0].count : 0
        var columns = Array(0..<cols).filter { c in
            (0..<rows).contains { r in
                grid[r][c] != nil &&
                grid[r][c]?.blocker == nil &&
                grid[r][c]?.kind == .normal
            }
        }
        columns.shuffle(using: &rng)

        var seeded = 0
        for col in columns where seeded < count {
            var topRow = -1
            for r in 0..<rows
                where grid[r][col] != nil &&
                grid[r][col]?.blocker == nil &&
                grid[r][col]?.kind == .normal {
                topRow = r
                break
            }
            guard topRow >= 0 else { continue }
            grid[topRow][col]?.kind = kind
            grid[topRow][col]?.special = nil
            seeded += 1
        }
    }

    private static func seedStartingBombs<R: RandomNumberGenerator>(layout: LevelLayout,
                                                                    grid: inout Grid,
                                                                    rng: inout R) {
        guard layout.startingBombs > 0 else { return }
        var candidates = playablePositions(in: grid, includeBlockers: false)
        candidates.shuffle(using: &rng)
        for p in candidates.prefix(layout.startingBombs) {
            grid[p.r][p.c]?.special = .bomb
        }
    }

    private static func safeColorLockColor(at position: Pos,
                                           in grid: Grid,
                                           palette: [String],
                                           preferred: String) -> String {
        let current = grid[position.r][position.c]?.color
        let options = ([preferred] + [current].compactMap { $0 } + palette)
            .reduce(into: [String]()) { result, color in
                if !result.contains(color) { result.append(color) }
            }
        for color in options {
            var candidate = grid
            candidate[position.r][position.c]?.color = color
            if Engine.findMatches(candidate).isEmpty,
               Engine.findSquares(candidate).isEmpty {
                return color
            }
        }
        return current ?? preferred
    }

    private static func repairOpeningMove(in grid: Grid, palette: [String]) -> Grid? {
        guard palette.count >= 2 else { return nil }
        let rows = grid.count
        let cols = rows > 0 ? grid[0].count : 0

        func canUse(_ p: Pos, in candidate: Grid) -> Bool {
            guard let cell = candidate[p.r][p.c] else { return false }
            return cell.blocker == nil && cell.special == nil
        }

        func repaired(_ positions: [Pos], primary: String, secondary: String) -> Grid? {
            var candidate = grid
            for (index, p) in positions.enumerated() {
                candidate[p.r][p.c]?.color = index == 2 ? secondary : primary
                candidate[p.r][p.c]?.special = nil
            }
            guard Engine.findMatches(candidate).isEmpty,
                  Engine.findSquares(candidate).isEmpty else { return nil }
            return Engine.swapIfValid(candidate, positions[2], positions[3]).didSwap ? candidate : nil
        }

        for r in 0..<rows {
            guard cols >= 4 else { continue }
            for c in 0...(cols - 4) {
                let positions = (0..<4).map { Pos(r: r, c: c + $0) }
                guard positions.allSatisfy({ canUse($0, in: grid) }) else { continue }
                for primary in palette {
                    for secondary in palette where secondary != primary {
                        if let candidate = repaired(positions, primary: primary, secondary: secondary) {
                            return candidate
                        }
                    }
                }
            }
        }

        for c in 0..<cols {
            guard rows >= 4 else { continue }
            for r in 0...(rows - 4) {
                let positions = (0..<4).map { Pos(r: r + $0, c: c) }
                guard positions.allSatisfy({ canUse($0, in: grid) }) else { continue }
                for primary in palette {
                    for secondary in palette where secondary != primary {
                        if let candidate = repaired(positions, primary: primary, secondary: secondary) {
                            return candidate
                        }
                    }
                }
            }
        }

        return nil
    }
}
