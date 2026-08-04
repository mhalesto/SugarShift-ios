import Foundation

enum Special: String, Hashable, CaseIterable {
    case stripedRow = "striped-row"
    case stripedCol = "striped-col"
    case wrapped
    case colorBomb = "color-bomb"
    case bomb
    /// Seeker. Created by a 2x2 square match; on activation it targets a goal
    /// tile or blocker (handled by the scene) plus a small local splash.
    case fish
}

/// Canonical result of swapping two specials. The scene owns animation and
/// objective-aware target selection, while this pure classification is shared
/// by resolution, previews, hints, and tests so the combo matrix cannot drift.
enum SpecialComboKind: String, Equatable, CaseIterable {
    case colorColor
    case stripeStripe
    case wrappedStripe
    case bombStripe
    case colorStripe
    case colorWrapped
    case colorBomb
    case colorFish
    case bombBomb
    case wrappedWrapped
    case bombWrapped
    case fishStripe
    case fishWrapped
    case fishBomb
    case fishFish
}

private struct SpecialPair: Hashable {
    let first: String
    let second: String

    init(_ a: Special, _ b: Special) {
        if a.rawValue <= b.rawValue {
            first = a.rawValue
            second = b.rawValue
        } else {
            first = b.rawValue
            second = a.rawValue
        }
    }
}

enum CellKind: Hashable {
    case normal
    case ingredient
    case key
}

enum BlockerType: Hashable {
    case ice
    case lock
    case jelly
    case crate
    case colorLock
    /// Opens when a nearby match hits it or when a collected key reaches the
    /// bottom of the board. Rewards coins or stocked boosters.
    case chest
    /// Rope/vine tie. A direct match or hammer cuts it before the tile can play
    /// normally, creating local pressure without needing another fruit asset.
    case vine
    /// Chocolate tile. Single-hit to clear. Spreads to one orthogonal neighbor
    /// at the end of every player turn, *unless* the player damaged a
    /// chocolate that turn (i.e., adjacent matching keeps it in check).
    case chocolate
    /// Sticky syrup coating. Single-hit to clear. Applied to tiles by the
    /// rising syrup-line mechanic; the line climbs one row every N moves and
    /// coats every playable tile on the new row. Pressure mechanic — push
    /// the player to keep momentum instead of stalling.
    case syrup
    /// Ticking fuse. Counts down one each player turn; at zero it drains a move
    /// and re-arms. Defused by a direct match like other single-hit blockers.
    case countdown
}

struct Blocker {
    var type: BlockerType
    var hits: Int
    var requiredColor: String? = nil
    /// Turns left for a `.countdown` fuse before it detonates. Nil for others.
    var countdown: Int? = nil
}

struct Cell {
    let id: String
    var color: String
    var special: Special?
    var kind: CellKind
    var blocker: Blocker? = nil
}

struct Pos: Hashable {
    let r: Int
    let c: Int
}

typealias Grid = [[Cell?]]

struct ClearResult {
    let cleared: Set<Pos>
    let damagedBlockers: Set<Pos>

    var affectedCount: Int { cleared.count + damagedBlockers.count }
}

struct SugarRushResolution: Equatable {
    let positions: Set<Pos>
    let anchor: Pos?
}

struct SpecialSpawn: Equatable {
    let position: Pos
    let special: Special
}

enum SwapActivation: Equatable {
    case normal
    case colorBomb(position: Pos, targetColor: String)
    case specialCombo(kind: SpecialComboKind,
                      first: Special,
                      second: Special,
                      targetColor: String?)
}

struct ClassifiedSwap {
    let grid: Grid
    let activation: SwapActivation
}

enum Engine {
    /// Exhaustive unordered special-pair table. Adding a new special requires
    /// adding its pairings here; the matrix coverage test enforces that rule.
    private static let specialComboRules: [SpecialPair: SpecialComboKind] = [
        SpecialPair(.stripedRow, .stripedRow): .stripeStripe,
        SpecialPair(.stripedRow, .stripedCol): .stripeStripe,
        SpecialPair(.stripedCol, .stripedCol): .stripeStripe,
        SpecialPair(.wrapped, .stripedRow): .wrappedStripe,
        SpecialPair(.wrapped, .stripedCol): .wrappedStripe,
        SpecialPair(.bomb, .stripedRow): .bombStripe,
        SpecialPair(.bomb, .stripedCol): .bombStripe,
        SpecialPair(.colorBomb, .stripedRow): .colorStripe,
        SpecialPair(.colorBomb, .stripedCol): .colorStripe,
        SpecialPair(.fish, .stripedRow): .fishStripe,
        SpecialPair(.fish, .stripedCol): .fishStripe,
        SpecialPair(.wrapped, .wrapped): .wrappedWrapped,
        SpecialPair(.wrapped, .colorBomb): .colorWrapped,
        SpecialPair(.wrapped, .bomb): .bombWrapped,
        SpecialPair(.wrapped, .fish): .fishWrapped,
        SpecialPair(.colorBomb, .colorBomb): .colorColor,
        SpecialPair(.colorBomb, .bomb): .colorBomb,
        SpecialPair(.colorBomb, .fish): .colorFish,
        SpecialPair(.bomb, .bomb): .bombBomb,
        SpecialPair(.bomb, .fish): .fishBomb,
        SpecialPair(.fish, .fish): .fishFish
    ]

    static func specialComboKind(_ first: Special, _ second: Special) -> SpecialComboKind? {
        specialComboRules[SpecialPair(first, second)]
    }

    /// Pure footprint resolver for a classified special pair. The caller
    /// supplies objective-ranked fish targets; everything else is derived from
    /// immutable grid state. Both gameplay and drag previews consume this exact
    /// result, and the consumed pair is excluded from incidental re-triggering.
    static func resolveSpecialCombo(_ grid: Grid,
                                    kind: SpecialComboKind,
                                    first: Special,
                                    second: Special,
                                    positions: (Pos, Pos),
                                    targetColor: String?,
                                    rankedFishTargets: [Pos],
                                    bigger: Bool) -> Set<Pos> {
        let rows = grid.count
        let cols = rows > 0 ? grid[0].count : 0
        guard rows > 0, cols > 0 else { return [] }
        var affected = Set<Pos>()
        let center = positions.1

        func add(_ row: Int, _ column: Int) {
            guard row >= 0, row < rows, column >= 0, column < cols,
                  grid[row][column]?.kind == .normal else { return }
            affected.insert(Pos(r: row, c: column))
        }
        func addRow(_ row: Int) { for c in 0..<cols { add(row, c) } }
        func addColumn(_ column: Int) { for r in 0..<rows { add(r, column) } }
        func addThreeRows(around row: Int) {
            let count = min(3, rows)
            let start = min(max(0, row - 1), max(0, rows - count))
            for value in start..<(start + count) { addRow(value) }
        }
        func addThreeColumns(around column: Int) {
            let count = min(3, cols)
            let start = min(max(0, column - 1), max(0, cols - count))
            for value in start..<(start + count) { addColumn(value) }
        }
        func addSquare(_ point: Pos, radius: Int) {
            for dr in -radius...radius {
                for dc in -radius...radius { add(point.r + dr, point.c + dc) }
            }
        }
        func colorPositions() -> [Pos] {
            guard let targetColor else { return [] }
            var out: [Pos] = []
            for r in 0..<rows {
                for c in 0..<cols where grid[r][c]?.color == targetColor {
                    out.append(Pos(r: r, c: c))
                }
            }
            return out
        }
        func postSwapPosition(for special: Special, isFirst: Bool) -> Pos {
            isFirst ? positions.1 : positions.0
        }
        func stripeAndPosition() -> (Special, Pos)? {
            if first == .stripedRow || first == .stripedCol {
                return (first, postSwapPosition(for: first, isFirst: true))
            }
            if second == .stripedRow || second == .stripedCol {
                return (second, postSwapPosition(for: second, isFirst: false))
            }
            return nil
        }
        func addRankedFish(count: Int, radius: Int, lane: Special? = nil) {
            for target in rankedFishTargets.prefix(count) {
                addSquare(target, radius: radius)
                if lane == .stripedRow { addRow(target.r) }
                if lane == .stripedCol { addColumn(target.c) }
            }
        }

        let bombRadius = bigger ? 2 : 1
        let wrappedRadius = bigger ? 3 : 2
        switch kind {
        case .colorColor:
            for r in 0..<rows { for c in 0..<cols { add(r, c) } }
        case .stripeStripe:
            let firstPosition = postSwapPosition(for: first, isFirst: true)
            let secondPosition = postSwapPosition(for: second, isFirst: false)
            if first == .stripedRow, second == .stripedRow {
                addThreeRows(around: center.r)
            } else if first == .stripedCol, second == .stripedCol {
                addThreeColumns(around: center.c)
            } else {
                if first == .stripedRow { addRow(firstPosition.r) } else { addColumn(firstPosition.c) }
                if second == .stripedRow { addRow(secondPosition.r) } else { addColumn(secondPosition.c) }
            }
        case .wrappedStripe:
            addThreeRows(around: center.r)
            addThreeColumns(around: center.c)
        case .bombStripe:
            if let (stripe, position) = stripeAndPosition() {
                stripe == .stripedRow
                    ? addThreeRows(around: position.r)
                    : addThreeColumns(around: position.c)
            }
            addSquare(center, radius: bombRadius)
        case .colorStripe:
            let stripe = stripeAndPosition()?.0 ?? .stripedRow
            for p in colorPositions() {
                stripe == .stripedRow ? addRow(p.r) : addColumn(p.c)
            }
        case .colorWrapped:
            for p in colorPositions() { addSquare(p, radius: wrappedRadius) }
        case .colorBomb:
            for p in colorPositions() { addSquare(p, radius: bombRadius) }
        case .colorFish:
            let matches = colorPositions()
            affected.formUnion(matches)
            addRankedFish(count: min(8, max(4, matches.count / 2)), radius: 1)
        case .bombBomb:
            addSquare(center, radius: bigger ? 3 : 2)
        case .wrappedWrapped:
            addSquare(positions.0, radius: wrappedRadius)
            addSquare(positions.1, radius: wrappedRadius)
        case .bombWrapped:
            addSquare(center, radius: bigger ? 4 : 3)
        case .fishStripe:
            addRankedFish(count: 4, radius: 0, lane: stripeAndPosition()?.0)
        case .fishWrapped:
            addRankedFish(count: 3, radius: wrappedRadius)
        case .fishBomb:
            addRankedFish(count: 5, radius: bombRadius)
        case .fishFish:
            addRankedFish(count: 4, radius: 1)
        }

        affected.insert(positions.0)
        affected.insert(positions.1)
        return expandMatchesWithSpecials(grid,
                                         affected,
                                         bigger: bigger,
                                         excludingSpecialsAt: [positions.0, positions.1])
    }

    private static func uid() -> String {
        let t = String(Int(Date().timeIntervalSince1970 * 1000), radix: 36)
        let r = String(Int.random(in: 0..<Int(pow(36.0, 5))), radix: 36)
        return "\(t)_\(r)"
    }

    private static func uid<R: RandomNumberGenerator>(rng: inout R) -> String {
        String(rng.next(), radix: 36)
    }

    static func createInitialGrid(rows: Int, cols: Int, colors: [String], mask: [[Bool]]? = nil) -> Grid {
        var rng = SystemRandomNumberGenerator()
        return createInitialGrid(rows: rows, cols: cols, colors: colors, mask: mask, rng: &rng)
    }

    static func createInitialGrid<R: RandomNumberGenerator>(rows: Int,
                                                            cols: Int,
                                                            colors: [String],
                                                            mask: [[Bool]]? = nil,
                                                            rng: inout R) -> Grid {
        var g: Grid = Array(repeating: Array(repeating: nil, count: cols), count: rows)
        for r in 0..<rows {
            for c in 0..<cols {
                if let m = mask, !m[r][c] { continue }
                var color: String = colors[0]
                var tries = 0
                repeat {
                    color = colors.randomElement(using: &rng)!
                    tries += 1
                } while tries < 12 && wouldMakeInitialMatch(g, r: r, c: c, color: color)
                g[r][c] = Cell(id: uid(rng: &rng), color: color, special: nil, kind: .normal)
            }
        }
        return g
    }

    static func findMatches(_ grid: Grid) -> Set<Pos> {
        var out = Set<Pos>()
        for group in findMatchGroups(grid) { out.formUnion(group) }
        return out
    }

    /// Returns each contiguous match run as its own array of positions.
    /// Lets callers detect special creation patterns.
    static func findMatchGroups(_ grid: Grid) -> [[Pos]] {
        let rows = grid.count
        let cols = grid[0].count
        var groups: [[Pos]] = []

        // Horizontal runs
        for r in 0..<rows {
            var c = 0
            while c < cols {
                guard let cell = grid[r][c], cell.kind == .normal else { c += 1; continue }
                let color = cell.color
                var k = c + 1
                while k < cols,
                      grid[r][k]?.kind == .normal,
                      grid[r][k]?.color == color { k += 1 }
                if k - c >= 3 {
                    var run: [Pos] = []
                    for x in c..<k { run.append(Pos(r: r, c: x)) }
                    groups.append(run)
                }
                c = k
            }
        }
        // Vertical runs
        for c in 0..<cols {
            var r = 0
            while r < rows {
                guard let cell = grid[r][c], cell.kind == .normal else { r += 1; continue }
                let color = cell.color
                var k = r + 1
                while k < rows,
                      grid[k][c]?.kind == .normal,
                      grid[k][c]?.color == color { k += 1 }
                if k - r >= 3 {
                    var run: [Pos] = []
                    for y in r..<k { run.append(Pos(r: y, c: c)) }
                    groups.append(run)
                }
                r = k
            }
        }
        return groups
    }

    static func specialSpawn(from groups: [[Pos]],
                             bombRunLength: Int? = nil,
                             preferredPositions: [Pos] = [],
                             eligiblePositions: Set<Pos>? = nil) -> SpecialSpawn? {
        let hugeRun = max(6, bombRunLength ?? 6)

        func spawnPosition(in positions: [Pos], fallback: Pos) -> Pos? {
            let eligible = positions.filter { eligiblePositions?.contains($0) ?? true }
            guard !eligible.isEmpty else { return nil }
            return preferredPositions.first(where: eligible.contains)
                ?? (eligible.contains(fallback) ? fallback : eligible[eligible.count / 2])
        }

        if let group = groups.filter({ $0.count >= hugeRun }).max(by: { $0.count < $1.count }),
           let position = spawnPosition(in: group, fallback: group[group.count / 2]) {
            return SpecialSpawn(position: position,
                                special: .bomb)
        }

        let memberships = groupMemberships(groups)
        let intersections = memberships
            .filter { $0.value.count >= 2 }
            .map { pos, indexes -> (position: Pos, combined: [Pos]) in
                var combined = Set<Pos>()
                for i in indexes { combined.formUnion(groups[i]) }
                return (pos, combined.sorted {
                    if $0.r != $1.r { return $0.r < $1.r }
                    return $0.c < $1.c
                })
            }
            .filter { $0.combined.count >= 5 }
            .sorted {
                if $0.combined.count != $1.combined.count {
                    return $0.combined.count > $1.combined.count
                }
                if $0.position.r != $1.position.r { return $0.position.r < $1.position.r }
                return $0.position.c < $1.position.c
            }

        if let wrapped = intersections.first,
           let position = spawnPosition(in: wrapped.combined, fallback: wrapped.position) {
            return SpecialSpawn(position: position,
                                special: .wrapped)
        }

        if let group = groups.filter({ $0.count >= 5 }).max(by: { $0.count < $1.count }),
           let position = spawnPosition(in: group, fallback: group[group.count / 2]) {
            return SpecialSpawn(position: position,
                                special: .colorBomb)
        }

        if let group = groups.first(where: { $0.count == 4 }),
           let position = spawnPosition(in: group, fallback: group[group.count / 2]) {
            return SpecialSpawn(position: position,
                                special: isHorizontal(group) ? .stripedRow : .stripedCol)
        }

        return nil
    }

    /// Walks every match position and, if the cell is special, expands the
    /// cleared set with whatever the special triggers (3×3 for bomb, etc.).
    static func expandMatchesWithSpecials(_ grid: Grid,
                                          _ matches: Set<Pos>,
                                          bigger: Bool = false,
                                          excludingSpecialsAt excluded: Set<Pos>? = nil) -> Set<Pos> {
        let rows = grid.count, cols = grid[0].count
        var out = Set(matches.filter { p in
            p.r >= 0 && p.r < rows && p.c >= 0 && p.c < cols
                && grid[p.r][p.c]?.kind == .normal
        })
        var queue = Array(out)
        var triggered = Set<Pos>()
        func add(_ r: Int, _ c: Int) {
            guard r >= 0, r < rows, c >= 0, c < cols,
                  grid[r][c]?.kind == .normal else { return }
            let p = Pos(r: r, c: c)
            if out.insert(p).inserted { queue.append(p) }
        }

        while let p = queue.popLast() {
            guard excluded?.contains(p) != true,
                  triggered.insert(p).inserted,
                  let cell = grid[p.r][p.c],
                  let sp = cell.special else { continue }
            switch sp {
            case .bomb:
                let radius = bigger ? 2 : 1
                for dr in -radius...radius {
                    for dc in -radius...radius { add(p.r + dr, p.c + dc) }
                }
            case .stripedRow:
                for c in 0..<cols { add(p.r, c) }
            case .stripedCol:
                for r in 0..<rows { add(r, p.c) }
            case .wrapped:
                // Wrapped now clears a wider blast than a bomb's 3x3 to feel
                // like the genre's double-detonation.
                let radius = bigger ? 3 : 2
                for dr in -radius...radius {
                    for dc in -radius...radius { add(p.r + dr, p.c + dc) }
                }
            case .colorBomb:
                let target = cell.color
                for r in 0..<rows {
                    for c in 0..<cols {
                        if grid[r][c]?.color == target { add(r, c) }
                    }
                }
            case .fish:
                // Local splash; the goal-seeking target is added by the scene,
                // which knows the level objective.
                add(p.r, p.c)
                add(p.r - 1, p.c); add(p.r + 1, p.c)
                add(p.r, p.c - 1); add(p.r, p.c + 1)
            }
        }
        return out
    }

    @discardableResult
    static func openAdjacentChests(_ grid: inout Grid, near positions: Set<Pos>) -> Set<Pos> {
        let rows = grid.count
        let cols = rows > 0 ? grid[0].count : 0
        var opened = Set<Pos>()
        for p in positions {
            for n in orthogonalNeighbors(of: p, rows: rows, cols: cols) {
                guard var cell = grid[n.r][n.c],
                      cell.blocker?.type == .chest else { continue }
                cell.blocker = nil
                grid[n.r][n.c] = cell
                opened.insert(n)
            }
        }
        return opened
    }

    @discardableResult
    static func openFirstChest(_ grid: inout Grid) -> Pos? {
        for r in 0..<grid.count {
            for c in 0..<grid[r].count {
                guard var cell = grid[r][c],
                      cell.blocker?.type == .chest else { continue }
                cell.blocker = nil
                grid[r][c] = cell
                return Pos(r: r, c: c)
            }
        }
        return nil
    }

    @discardableResult
    static func clearMatches(_ grid: inout Grid, matches: Set<Pos>) -> ClearResult {
        var cleared = Set<Pos>()
        var damaged = Set<Pos>()
        for p in matches {
            guard var cell = grid[p.r][p.c] else { continue }
            if var blocker = cell.blocker {
                if blocker.type == .colorLock,
                   let required = blocker.requiredColor,
                   required.lowercased() != cell.color.lowercased() {
                    grid[p.r][p.c] = cell
                    continue
                }
                blocker.hits -= 1
                damaged.insert(p)
                if blocker.hits > 0 {
                    cell.blocker = blocker
                } else {
                    cell.blocker = nil
                }
                grid[p.r][p.c] = cell
            } else if cell.kind == .normal {
                grid[p.r][p.c] = nil
                cleared.insert(p)
            }
        }
        return ClearResult(cleared: cleared, damagedBlockers: damaged)
    }

    /// Drop existing tiles down, then fill empties at the top with new colors.
    /// `cascadeBoost` (0…1) biases the new tile colors so they're more likely to
    /// land on a colour that already pairs with what's beneath/beside them — used
    /// in early levels to manufacture cascades and cinematic combos.
    static func collapseAndRefill(_ grid: Grid,
                                   colors: [String],
                                   mask: [[Bool]]? = nil,
                                   cascadeBoost: Double = 0) -> Grid {
        var rng = SystemRandomNumberGenerator()
        return collapseAndRefill(grid,
                                 colors: colors,
                                 mask: mask,
                                 cascadeBoost: cascadeBoost,
                                 rng: &rng)
    }

    static func collapseAndRefill<R: RandomNumberGenerator>(_ grid: Grid,
                                                            colors: [String],
                                                            mask: [[Bool]]? = nil,
                                                            cascadeBoost: Double = 0,
                                                            rng: inout R) -> Grid {
        let rows = grid.count
        let cols = grid[0].count
        var g = grid
        for c in 0..<cols {
            var playable: [Int] = []
            for r in stride(from: rows - 1, through: 0, by: -1) {
                if let m = mask, !m[r][c] { g[r][c] = nil; continue }
                playable.append(r)
            }
            var stack: [Cell] = []
            for r in playable { if let cell = g[r][c] { stack.append(cell) } }
            var idx = 0
            for r in playable {
                if idx < stack.count {
                    g[r][c] = stack[idx]
                    idx += 1
                } else {
                    var picked = colors.randomElement(using: &rng)!
                    if cascadeBoost > 0, Double.random(in: 0...1, using: &rng) < cascadeBoost,
                       let biased = biasedRefillColor(g, r: r, c: c) {
                        picked = biased
                    }
                    g[r][c] = Cell(id: uid(rng: &rng), color: picked, special: nil, kind: .normal)
                }
            }
        }
        return g
    }

    static func applyPortals(_ grid: Grid, pairs: [LevelPortal]) -> Grid {
        guard !pairs.isEmpty else { return grid }
        var g = grid
        let rows = g.count
        let cols = g[0].count

        func valid(_ p: Pos) -> Bool {
            p.r >= 0 && p.r < rows && p.c >= 0 && p.c < cols && g[p.r][p.c] != nil
        }

        for pair in pairs {
            let from = pair.from
            let to = pair.to
            guard valid(from), valid(to) else { continue }
            let tmp = g[from.r][from.c]
            g[from.r][from.c] = g[to.r][to.c]
            g[to.r][to.c] = tmp
        }
        return g
    }

    /// Returns positions of all chocolate tiles on the board.
    static func chocolatePositions(_ grid: Grid) -> [Pos] {
        var out: [Pos] = []
        let rows = grid.count
        let cols = rows > 0 ? grid[0].count : 0
        for r in 0..<rows {
            for c in 0..<cols {
                if grid[r][c]?.blocker?.type == .chocolate {
                    out.append(Pos(r: r, c: c))
                }
            }
        }
        return out
    }

    /// Picks one chocolate to spread to one of its orthogonal non-blocker
    /// neighbors. Returns the new grid and the spread position (nil when no
    /// spread happened — board is full of chocolate or blockers, or there are
    /// no chocolates left). Caller passes a `seedPicker` for deterministic
    /// tests; in production the default RNG is fine.
    static func spreadChocolate(_ grid: Grid,
                                 picker: @escaping (Int) -> Int = { Int.random(in: 0..<$0) }) -> (Grid, Pos?) {
        var sources = chocolatePositions(grid)
        guard !sources.isEmpty else { return (grid, nil) }
        let rows = grid.count
        let cols = grid[0].count

        sources.shuffle()
        var g = grid
        for src in sources {
            let neighbors: [Pos] = [
                Pos(r: src.r - 1, c: src.c),
                Pos(r: src.r + 1, c: src.c),
                Pos(r: src.r, c: src.c - 1),
                Pos(r: src.r, c: src.c + 1)
            ].filter { p in
                p.r >= 0 && p.r < rows && p.c >= 0 && p.c < cols &&
                g[p.r][p.c] != nil &&
                g[p.r][p.c]?.blocker == nil
            }
            guard !neighbors.isEmpty else { continue }
            let target = neighbors[picker(neighbors.count)]
            if var cell = g[target.r][target.c] {
                cell.blocker = Blocker(type: .chocolate, hits: 1)
                cell.special = nil
                g[target.r][target.c] = cell
                return (g, target)
            }
        }
        return (g, nil)
    }

    static func spreadChocolate<R: RandomNumberGenerator>(_ grid: Grid,
                                                          rng: inout R) -> (Grid, Pos?) {
        var sources = chocolatePositions(grid)
        guard !sources.isEmpty else { return (grid, nil) }
        let rows = grid.count
        let cols = grid[0].count

        sources.shuffle(using: &rng)
        var g = grid
        for src in sources {
            let neighbors: [Pos] = [
                Pos(r: src.r - 1, c: src.c),
                Pos(r: src.r + 1, c: src.c),
                Pos(r: src.r, c: src.c - 1),
                Pos(r: src.r, c: src.c + 1)
            ].filter { p in
                p.r >= 0 && p.r < rows && p.c >= 0 && p.c < cols &&
                g[p.r][p.c] != nil &&
                g[p.r][p.c]?.blocker == nil
            }
            guard !neighbors.isEmpty else { continue }
            let target = neighbors[Int.random(in: 0..<neighbors.count, using: &rng)]
            if var cell = g[target.r][target.c] {
                cell.blocker = Blocker(type: .chocolate, hits: 1)
                cell.special = nil
                g[target.r][target.c] = cell
                return (g, target)
            }
        }
        return (g, nil)
    }

    /// Removes any ingredient cells that have fallen to the bottom-most playable
    /// row of their column. Returns the new grid and the positions of the
    /// collected ingredients so the scene can animate the rescue effect.
    static func collectIngredientsAtBottom(_ grid: Grid,
                                           mask: [[Bool]]? = nil) -> (Grid, Set<Pos>) {
        collectKindAtBottom(grid, kind: .ingredient, mask: mask)
    }

    static func collectKeysAtBottom(_ grid: Grid,
                                    mask: [[Bool]]? = nil) -> (Grid, Set<Pos>) {
        collectKindAtBottom(grid, kind: .key, mask: mask)
    }

    private static func collectKindAtBottom(_ grid: Grid,
                                            kind: CellKind,
                                            mask: [[Bool]]? = nil) -> (Grid, Set<Pos>) {
        let rows = grid.count
        guard rows > 0 else { return (grid, []) }
        let cols = grid[0].count
        var g = grid
        var collected = Set<Pos>()

        for c in 0..<cols {
            // Lowest playable row in this column. With a mask, this might not be rows-1.
            var bottom = -1
            for r in stride(from: rows - 1, through: 0, by: -1) {
                if let m = mask, !m[r][c] { continue }
                bottom = r
                break
            }
            guard bottom >= 0 else { continue }
            if let cell = g[bottom][c], cell.kind == kind {
                g[bottom][c] = nil
                collected.insert(Pos(r: bottom, c: c))
            }
        }
        return (g, collected)
    }

    static func applyConveyors(_ grid: Grid, belts: [ConveyorBelt]) -> Grid {
        guard !belts.isEmpty else { return grid }
        var g = grid
        let rows = g.count
        let cols = g[0].count

        for belt in belts {
            guard belt.row >= 0, belt.row < rows else { continue }
            var positions: [Pos] = []
            var cells: [Cell] = []
            for c in 0..<cols {
                if let cell = g[belt.row][c] {
                    positions.append(Pos(r: belt.row, c: c))
                    cells.append(cell)
                }
            }
            guard positions.count > 1 else { continue }

            let shift = belt.direction >= 0 ? 1 : -1
            for (index, pos) in positions.enumerated() {
                let sourceIndex = (index - shift + positions.count) % positions.count
                g[pos.r][pos.c] = cells[sourceIndex]
            }
        }
        return g
    }

    /// If nearby tiles already form a near-match, return that colour so a refill
    /// can complete the run. This is used only by early-level cascade bias and
    /// capped by the scene's cascade depth, so bridge patterns are safe here.
    private static func biasedRefillColor(_ g: Grid, r: Int, c: Int) -> String? {
        let rows = g.count
        let cols = g[0].count
        if r - 1 >= 0, r + 1 < rows,
           let a = g[r - 1][c]?.color,
           let b = g[r + 1][c]?.color,
           a == b { return a }
        if c - 1 >= 0, c + 1 < cols,
           let a = g[r][c - 1]?.color,
           let b = g[r][c + 1]?.color,
           a == b { return a }
        if r + 2 < rows,
           let a = g[r + 1][c]?.color,
           let b = g[r + 2][c]?.color,
           a == b { return a }
        if r - 2 >= 0,
           let a = g[r - 1][c]?.color,
           let b = g[r - 2][c]?.color,
           a == b { return a }
        if c >= 2,
           let a = g[r][c - 1]?.color,
           let b = g[r][c - 2]?.color,
           a == b { return a }
        if c + 2 < cols,
           let a = g[r][c + 1]?.color,
           let b = g[r][c + 2]?.color,
           a == b { return a }
        return nil
    }

    /// Returns the swapped grid only if the swap creates a match at either position.
    static func swapIfValid(_ grid: Grid, _ a: Pos, _ b: Pos) -> (didSwap: Bool, grid: Grid) {
        guard let classified = classifySwap(grid, a, b) else { return (false, grid) }
        return (true, classified.grid)
    }

    /// Single source of truth for whether an adjacent swap is legal and which
    /// activation it represents.
    static func classifySwap(_ grid: Grid, _ a: Pos, _ b: Pos) -> ClassifiedSwap? {
        var g = grid
        let rows = g.count, cols = g[0].count
        guard a.r >= 0, a.r < rows, a.c >= 0, a.c < cols,
              b.r >= 0, b.r < rows, b.c >= 0, b.c < cols,
              abs(a.r - b.r) + abs(a.c - b.c) == 1,
              g[a.r][a.c] != nil, g[b.r][b.c] != nil else {
            return nil
        }
        let cellA = g[a.r][a.c]!
        let cellB = g[b.r][b.c]!
        let tmp = g[a.r][a.c]
        g[a.r][a.c] = g[b.r][b.c]
        g[b.r][b.c] = tmp

        if let first = cellA.special,
           let second = cellB.special,
           let kind = specialComboKind(first, second) {
            let targetColor: String?
            if first == .colorBomb { targetColor = cellB.color }
            else if second == .colorBomb { targetColor = cellA.color }
            else { targetColor = nil }
            return ClassifiedSwap(grid: g,
                                  activation: .specialCombo(kind: kind,
                                                            first: first,
                                                            second: second,
                                                            targetColor: targetColor))
        }
        if cellA.special == .colorBomb {
            return ClassifiedSwap(grid: g,
                                  activation: .colorBomb(position: b,
                                                         targetColor: cellB.color))
        }
        if cellB.special == .colorBomb {
            return ClassifiedSwap(grid: g,
                                  activation: .colorBomb(position: a,
                                                         targetColor: cellA.color))
        }
        let createsNewMatch = (createsMatch(g, at: a) && !createsMatch(grid, at: a))
            || (createsMatch(g, at: b) && !createsMatch(grid, at: b))
        let createsNewSquare = (createsSquare(g, at: a) && !createsSquare(grid, at: a))
            || (createsSquare(g, at: b) && !createsSquare(grid, at: b))
        if createsNewMatch || createsNewSquare {
            return ClassifiedSwap(grid: g, activation: .normal)
        }
        return nil
    }

    static func hasAnyMoves(_ grid: Grid) -> Bool {
        let rows = grid.count, cols = grid[0].count
        for r in 0..<rows {
            for c in 0..<cols {
                let here = Pos(r: r, c: c)
                if c + 1 < cols, swapIfValid(grid, here, Pos(r: r, c: c + 1)).didSwap { return true }
                if r + 1 < rows, swapIfValid(grid, here, Pos(r: r + 1, c: c)).didSwap { return true }
            }
        }
        return false
    }

    /// Returns a valid swap on the board that the UI can highlight when the
    /// player is stuck. Ranks candidates so the hint teaches a *good* play
    /// instead of just any legal one:
    ///   1. swap that activates an existing special (color-bomb pair, etc.)
    ///   2. swap that creates a new special (5-run > T/L > 4-run)
    ///   3. swap that produces the longest match
    ///   4. any valid swap
    static func findHintMove(_ grid: Grid) -> (Pos, Pos)? {
        scoredLegalMoves(grid).first?.move
    }

    static func scoredLegalMoves(_ grid: Grid) -> [(move: (Pos, Pos), score: Int)] {
        let rows = grid.count, cols = grid[0].count
        var moves: [(move: (Pos, Pos), score: Int)] = []

        let consider: (Pos, Pos) -> Void = { a, b in
            guard let result = classifySwap(grid, a, b) else { return }
            let score = scoreSwapForHint(grid: grid,
                                         swappedGrid: result.grid,
                                         activation: result.activation,
                                         a: a,
                                         b: b)
            moves.append(((a, b), score))
        }

        for r in 0..<rows {
            for c in 0..<cols {
                let here = Pos(r: r, c: c)
                if c + 1 < cols { consider(here, Pos(r: r, c: c + 1)) }
                if r + 1 < rows { consider(here, Pos(r: r + 1, c: c)) }
            }
        }
        return moves.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.move.0.r != rhs.move.0.r { return lhs.move.0.r < rhs.move.0.r }
            if lhs.move.0.c != rhs.move.0.c { return lhs.move.0.c < rhs.move.0.c }
            if lhs.move.1.r != rhs.move.1.r { return lhs.move.1.r < rhs.move.1.r }
            return lhs.move.1.c < rhs.move.1.c
        }
    }

    /// Scores the best legal move currently available. This is not player-facing
    /// score; it is a designer/balancer signal for whether a board has an
    /// interesting play available instead of only low-value 3-matches.
    static func bestMoveScore(_ grid: Grid) -> Int {
        scoredLegalMoves(grid).first?.score ?? 0
    }

    static func hasUsefulMove(_ grid: Grid, minimumScore: Int) -> Bool {
        bestMoveScore(grid) >= minimumScore
    }

    /// Expands an already-legal clear into Sugar Rush's cross. The preferred
    /// anchor is normally the tile the player moved, so Rush rewards choosing
    /// *where* to act instead of attaching itself to an arbitrary sorted match.
    /// If that tile is outside the resolved footprint, the nearest affected
    /// tile is selected with deterministic row/column tie-breaking.
    static func sugarRushResolution(in grid: Grid,
                                    base: Set<Pos>,
                                    preferredAnchor: Pos?) -> SugarRushResolution {
        guard !base.isEmpty else {
            return SugarRushResolution(positions: base, anchor: nil)
        }
        let valid = base.filter { position in
            position.r >= 0 && position.r < grid.count
                && position.c >= 0 && position.c < grid[position.r].count
                && grid[position.r][position.c] != nil
        }
        guard !valid.isEmpty else {
            return SugarRushResolution(positions: base, anchor: nil)
        }

        let anchor: Pos
        if let preferredAnchor, valid.contains(preferredAnchor) {
            anchor = preferredAnchor
        } else {
            anchor = valid.sorted { lhs, rhs in
                if let preferredAnchor {
                    let leftDistance = abs(lhs.r - preferredAnchor.r) + abs(lhs.c - preferredAnchor.c)
                    let rightDistance = abs(rhs.r - preferredAnchor.r) + abs(rhs.c - preferredAnchor.c)
                    if leftDistance != rightDistance { return leftDistance < rightDistance }
                }
                if lhs.r != rhs.r { return lhs.r < rhs.r }
                return lhs.c < rhs.c
            }.first!
        }

        var positions = base
        for c in 0..<grid[anchor.r].count where grid[anchor.r][c] != nil {
            positions.insert(Pos(r: anchor.r, c: c))
        }
        for r in 0..<grid.count
            where anchor.c < grid[r].count && grid[r][anchor.c] != nil {
            positions.insert(Pos(r: r, c: anchor.c))
        }
        return SugarRushResolution(positions: positions, anchor: anchor)
    }

    /// Canonical, hole-safe footprint for a player-targeted Smash. Special
    /// chaining is deliberately applied by the caller so analysis and live
    /// resolution can inspect the same base shape first.
    static func playerSmashFootprint(in grid: Grid,
                                     centeredAt center: Pos,
                                     tier: PlayerSmashTier) -> Set<Pos> {
        var positions = Set<Pos>()
        func add(_ row: Int, _ column: Int) {
            guard row >= 0, row < grid.count,
                  column >= 0, column < grid[row].count,
                  grid[row][column]?.kind == .normal else { return }
            positions.insert(Pos(r: row, c: column))
        }

        if tier == .focused || tier == .mega {
            for dr in -1...1 {
                for dc in -1...1 { add(center.r + dr, center.c + dc) }
            }
        }
        if tier == .cross || tier == .mega {
            guard center.r >= 0, center.r < grid.count else { return positions }
            for column in 0..<grid[center.r].count { add(center.r, column) }
            for row in 0..<grid.count where center.c < grid[row].count {
                add(row, center.c)
            }
        }
        return positions
    }

    /// Higher score = better hint to teach. Combines special-activation,
    /// special-creation, and match length so a 4-run swap that lights up an
    /// existing color bomb beats a plain 3-run swap on a barren patch.
    private static func scoreSwapForHint(grid: Grid,
                                         swappedGrid: Grid,
                                         activation: SwapActivation,
                                         a: Pos,
                                         b: Pos) -> Int {
        let groups = findMatchGroups(swappedGrid)
        let matchedPositions = Set(groups.flatMap { $0 })
        let activatesSpecial: Bool
        switch activation {
        case .colorBomb, .specialCombo:
            activatesSpecial = true
        case .normal:
            activatesSpecial = matchedPositions.contains { p in
                swappedGrid[p.r][p.c]?.special != nil
            }
        }
        let createdSpawn = specialSpawn(from: groups)
        let createsFish = findSquares(swappedGrid).contains { square in
            (square.contains(a) || square.contains(b))
                && !isUniformPlainSquare(grid, square)
        }
        let longestRun = groups.map(\.count).max() ?? 0

        var score = 0
        if activatesSpecial { score += 1_000 }
        if createsFish { score += 250 }
        if let spawn = createdSpawn {
            switch spawn.special {
            case .bomb:        score += 500
            case .colorBomb:   score += 400
            case .wrapped:     score += 300
            case .stripedRow,
                 .stripedCol:  score += 200
            case .fish:        score += 250
            }
        }
        score += longestRun * 10
        return score
    }

    // MARK: - helpers

    private static func groupMemberships(_ groups: [[Pos]]) -> [Pos: [Int]] {
        var out: [Pos: [Int]] = [:]
        for (index, group) in groups.enumerated() {
            for p in group { out[p, default: []].append(index) }
        }
        return out
    }

    private static func isHorizontal(_ group: [Pos]) -> Bool {
        guard let first = group.first else { return true }
        return group.allSatisfy { $0.r == first.r }
    }

    private static func orthogonalNeighbors(of pos: Pos, rows: Int, cols: Int) -> [Pos] {
        [
            Pos(r: pos.r - 1, c: pos.c),
            Pos(r: pos.r + 1, c: pos.c),
            Pos(r: pos.r, c: pos.c - 1),
            Pos(r: pos.r, c: pos.c + 1)
        ].filter { $0.r >= 0 && $0.r < rows && $0.c >= 0 && $0.c < cols }
    }

    private static func wouldMakeInitialMatch(_ g: Grid, r: Int, c: Int, color: String) -> Bool {
        if c >= 2, g[r][c - 1]?.color == color, g[r][c - 2]?.color == color { return true }
        if r >= 2, g[r - 1][c]?.color == color, g[r - 2][c]?.color == color { return true }
        return false
    }

    private static func createsMatch(_ g: Grid, at p: Pos) -> Bool {
        let rows = g.count, cols = g[0].count
        guard let here = g[p.r][p.c], here.kind == .normal else { return false }
        let color = here.color

        var cnt = 1
        var x = p.c - 1
        while x >= 0, g[p.r][x]?.kind == .normal, g[p.r][x]?.color == color { cnt += 1; x -= 1 }
        x = p.c + 1
        while x < cols, g[p.r][x]?.kind == .normal, g[p.r][x]?.color == color { cnt += 1; x += 1 }
        if cnt >= 3 { return true }

        cnt = 1
        var y = p.r - 1
        while y >= 0, g[y][p.c]?.kind == .normal, g[y][p.c]?.color == color { cnt += 1; y -= 1 }
        y = p.r + 1
        while y < rows, g[y][p.c]?.kind == .normal, g[y][p.c]?.color == color { cnt += 1; y += 1 }
        return cnt >= 3
    }

    /// A 2x2 block of identical-colour plain tiles — a new match type that
    /// spawns a Fish special.
    private static func isUniformPlainSquare(_ g: Grid, _ quad: [Pos]) -> Bool {
        guard let first = g[quad[0].r][quad[0].c],
              first.blocker == nil, first.kind == .normal, first.special == nil else { return false }
        for p in quad.dropFirst() {
            guard let cell = g[p.r][p.c],
                  cell.blocker == nil, cell.kind == .normal, cell.special == nil,
                  cell.color == first.color else { return false }
        }
        return true
    }

    /// Every 2x2 same-colour plain square on the board (each as four positions).
    static func findSquares(_ grid: Grid) -> [[Pos]] {
        let rows = grid.count
        let cols = rows > 0 ? grid[0].count : 0
        guard rows > 1, cols > 1 else { return [] }
        var squares: [[Pos]] = []
        for r in 0..<(rows - 1) {
            for c in 0..<(cols - 1) {
                let quad = [Pos(r: r, c: c), Pos(r: r, c: c + 1),
                            Pos(r: r + 1, c: c), Pos(r: r + 1, c: c + 1)]
                if isUniformPlainSquare(grid, quad) { squares.append(quad) }
            }
        }
        return squares
    }

    /// Whether `p` is part of any 2x2 same-colour plain square — lets a swap that
    /// forms a square count as a valid move.
    static func createsSquare(_ g: Grid, at p: Pos) -> Bool {
        let rows = g.count
        let cols = rows > 0 ? g[0].count : 0
        for dr in -1...0 {
            for dc in -1...0 {
                let r = p.r + dr, c = p.c + dc
                guard r >= 0, c >= 0, r + 1 < rows, c + 1 < cols else { continue }
                let quad = [Pos(r: r, c: c), Pos(r: r, c: c + 1),
                            Pos(r: r + 1, c: c), Pos(r: r + 1, c: c + 1)]
                if isUniformPlainSquare(g, quad) { return true }
            }
        }
        return false
    }
}
