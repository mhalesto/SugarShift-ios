import Foundation

enum Special: String, Hashable, CaseIterable, Codable {
    case stripedRow = "striped-row"
    case stripedCol = "striped-col"
    case wrapped
    case colorBomb = "color-bomb"
    case bomb
    /// Seeker. Created by a 2x2 square match; on activation it targets a goal
    /// tile or blocker (handled by the scene) plus a small local splash.
    case fish
    case lineBlast = "line-blast"
    case rocket
    case ufo
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
    /// Deterministic pairing involving line-blast, rocket, or UFO. The staged
    /// resolver reports the constituent activations without multiplying chains.
    case advanced
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

struct Pos: Hashable {
    let r: Int
    let c: Int
}

typealias Grid = [[Cell?]]

struct ClearResult {
    let cleared: Set<Pos>
    let damagedBlockers: Set<Pos>
    var presentationEvents: [GamePresentationEvent] = []

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
    private static let specialComboRules: [SpecialPair: SpecialComboKind] = {
        var rules: [SpecialPair: SpecialComboKind] = [
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
        for firstIndex in Special.allCases.indices {
            for secondIndex in firstIndex..<Special.allCases.count {
                let pair = SpecialPair(Special.allCases[firstIndex], Special.allCases[secondIndex])
                if rules[pair] == nil { rules[pair] = .advanced }
            }
        }
        return rules
    }()

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
        func addRay(from origin: Pos, dr: Int, dc: Int) {
            var r = origin.r + dr
            var c = origin.c + dc
            while r >= 0, r < rows, c >= 0, c < cols {
                guard let cell = grid[r][c] else { break }
                add(r, c)
                if cell.blocker?.type.rules.blocksBlast == true { break }
                r += dr
                c += dc
            }
        }
        func addRow(_ row: Int, from column: Int? = nil) {
            guard row >= 0, row < rows else { return }
            let origin = Pos(r: row, c: min(max(0, column ?? center.c), cols - 1))
            add(origin.r, origin.c)
            addRay(from: origin, dr: 0, dc: -1)
            addRay(from: origin, dr: 0, dc: 1)
        }
        func addColumn(_ column: Int, from row: Int? = nil) {
            guard column >= 0, column < cols else { return }
            let origin = Pos(r: min(max(0, row ?? center.r), rows - 1), c: column)
            add(origin.r, origin.c)
            addRay(from: origin, dr: -1, dc: 0)
            addRay(from: origin, dr: 1, dc: 0)
        }
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
                if lane == .stripedRow { addRow(target.r, from: target.c) }
                if lane == .stripedCol { addColumn(target.c, from: target.r) }
            }
        }

        let bombRadius = bigger ? 2 : 1
        let wrappedRadius = bigger ? 3 : 2
        switch kind {
        case .colorColor:
            for r in 0..<rows { for c in 0..<cols { add(r, c) } }
        case .stripeStripe:
            // Every striped pair is the genre-standard cross. Orientation only
            // affects its animation; it must not inflate into three lanes.
            addRow(center.r, from: center.c)
            addColumn(center.c, from: center.r)
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
                stripe == .stripedRow ? addRow(p.r, from: p.c) : addColumn(p.c, from: p.r)
            }
        case .colorWrapped:
            for p in colorPositions() { addSquare(p, radius: bigger ? 2 : 1) }
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
        case .advanced:
            let staged = resolveAdvancedComboBase(grid,
                                                  first: first,
                                                  second: second,
                                                  positions: positions,
                                                  targetColor: targetColor,
                                                  rankedFishTargets: rankedFishTargets,
                                                  bigger: bigger)
            affected.formUnion(staged.positions)
        }

        affected.insert(positions.0)
        affected.insert(positions.1)
        return expandMatchesWithSpecials(grid,
                                         affected,
                                         bigger: bigger,
                                         excludingSpecialsAt: [positions.0, positions.1],
                                         rankedTargets: rankedFishTargets)
    }

    /// Staged pure activation result for presentation and deterministic tests.
    /// `positions` is authoritative gameplay output; stages only describe timing.
    static func resolveSpecialActivationStaged(_ grid: Grid,
                                               special: Special,
                                               at origin: Pos,
                                               targetColor: String? = nil,
                                               rankedTargets: [Pos] = [],
                                               bigger: Bool = false,
                                               excludingSpecialsAt excluded: Set<Pos> = []) -> SpecialActivationResolution {
        let stages = activationStagesBase(grid,
                                          special: special,
                                          at: origin,
                                          targetColor: targetColor,
                                          rankedTargets: rankedTargets,
                                          bigger: bigger)
        let base = stages.reduce(into: Set<Pos>([origin])) { $0.formUnion($1.positions) }
        let chained = expandMatchesWithSpecials(grid,
                                                base,
                                                bigger: bigger,
                                                excludingSpecialsAt: excluded.union([origin]),
                                                rankedTargets: rankedTargets)
        return SpecialActivationResolution(positions: chained, stages: stages)
    }

    static func resolveSpecialComboStaged(_ grid: Grid,
                                          kind: SpecialComboKind,
                                          first: Special,
                                          second: Special,
                                          positions: (Pos, Pos),
                                          targetColor: String?,
                                          rankedFishTargets: [Pos],
                                          bigger: Bool) -> SpecialActivationResolution {
        if kind == .advanced {
            let base = resolveAdvancedComboBase(grid,
                                                first: first,
                                                second: second,
                                                positions: positions,
                                                targetColor: targetColor,
                                                rankedFishTargets: rankedFishTargets,
                                                bigger: bigger)
            let chained = expandMatchesWithSpecials(
                grid,
                base.positions.union([positions.0, positions.1]),
                bigger: bigger,
                excludingSpecialsAt: [positions.0, positions.1],
                rankedTargets: rankedFishTargets)
            return SpecialActivationResolution(positions: chained, stages: base.stages)
        }
        let resolved = resolveSpecialCombo(grid,
                                           kind: kind,
                                           first: first,
                                           second: second,
                                           positions: positions,
                                           targetColor: targetColor,
                                           rankedFishTargets: rankedFishTargets,
                                           bigger: bigger)
        let stageCount = kind == .wrappedWrapped || kind == .colorWrapped ? 2 : 1
        return SpecialActivationResolution(positions: resolved,
            stages: (0..<stageCount).map { index in
                SpecialActivationStage(index: index, origin: positions.1,
                                       special: second, positions: resolved)
            })
    }

    private static func resolveAdvancedComboBase(_ grid: Grid,
                                                 first: Special,
                                                 second: Special,
                                                 positions: (Pos, Pos),
                                                 targetColor: String?,
                                                 rankedFishTargets: [Pos],
                                                 bigger: Bool) -> SpecialActivationResolution {
        var stages: [SpecialActivationStage] = []
        let firstOrigin = positions.1
        let secondOrigin = positions.0
        if first == .colorBomb || second == .colorBomb {
            let converted = first == .colorBomb ? second : first
            let fallbackColor = first == .colorBomb
                ? grid[secondOrigin.r][secondOrigin.c]?.color
                : grid[firstOrigin.r][firstOrigin.c]?.color
            let color = targetColor ?? fallbackColor
            var index = 0
            for r in 0..<grid.count {
                for c in 0..<grid[r].count where grid[r][c]?.color == color {
                    let origin = Pos(r: r, c: c)
                    let conversion = activationStagesBase(grid,
                                                          special: converted,
                                                          at: origin,
                                                          targetColor: color,
                                                          rankedTargets: rankedFishTargets,
                                                          bigger: bigger)
                    for stage in conversion {
                        stages.append(SpecialActivationStage(index: index,
                                                             origin: stage.origin,
                                                             special: stage.special,
                                                             positions: stage.positions))
                        index += 1
                    }
                }
            }
        } else {
            let activations = [(first, firstOrigin), (second, secondOrigin)]
            for (special, origin) in activations {
                let next = activationStagesBase(grid,
                                                special: special,
                                                at: origin,
                                                targetColor: targetColor,
                                                rankedTargets: rankedFishTargets,
                                                bigger: bigger)
                for stage in next {
                    stages.append(SpecialActivationStage(index: stages.count,
                                                         origin: stage.origin,
                                                         special: stage.special,
                                                         positions: stage.positions))
                }
            }
        }
        let positions = stages.reduce(into: Set<Pos>()) { $0.formUnion($1.positions) }
        return SpecialActivationResolution(positions: positions, stages: stages)
    }

    private static func activationStagesBase(_ grid: Grid,
                                             special: Special,
                                             at origin: Pos,
                                             targetColor: String?,
                                             rankedTargets: [Pos],
                                             bigger: Bool) -> [SpecialActivationStage] {
        guard isValid(origin, in: grid) else { return [] }
        let radius = bigger ? 2 : 1
        func stage(_ index: Int, _ positions: Set<Pos>, origin: Pos = origin) -> SpecialActivationStage {
            SpecialActivationStage(index: index, origin: origin, special: special, positions: positions)
        }
        switch special {
        case .stripedRow:
            return [stage(0, linePositions(in: grid, origin: origin, dr: 0, dc: 1))]
        case .stripedCol, .rocket:
            return [stage(0, linePositions(in: grid, origin: origin, dr: 1, dc: 0))]
        case .lineBlast:
            let cross = linePositions(in: grid, origin: origin, dr: 0, dc: 1)
                .union(linePositions(in: grid, origin: origin, dr: 1, dc: 0))
            return [stage(0, cross)]
        case .bomb:
            return [stage(0, squarePositions(in: grid, center: origin, radius: radius))]
        case .wrapped:
            let footprint = squarePositions(in: grid, center: origin, radius: radius)
            return [stage(0, footprint), stage(1, footprint)]
        case .colorBomb:
            let color = targetColor ?? grid[origin.r][origin.c]?.color
            var positions: Set<Pos> = [origin]
            for r in 0..<grid.count {
                for c in 0..<grid[r].count where grid[r][c]?.color == color {
                    positions.insert(Pos(r: r, c: c))
                }
            }
            return [stage(0, positions)]
        case .fish, .ufo:
            let targets = rankedTargets.isEmpty ? [origin] : Array(rankedTargets.prefix(special == .ufo ? 3 : 1))
            return targets.enumerated().map { index, target in
                stage(index,
                      squarePositions(in: grid,
                                      center: target,
                                      radius: special == .ufo ? radius : 0),
                      origin: target)
            }
        }
    }

    private static func squarePositions(in grid: Grid, center: Pos, radius: Int) -> Set<Pos> {
        var positions: Set<Pos> = []
        for dr in -radius...radius {
            for dc in -radius...radius {
                let p = Pos(r: center.r + dr, c: center.c + dc)
                if isPlayablePieceSlot(p, in: grid) { positions.insert(p) }
            }
        }
        return positions
    }

    private static func linePositions(in grid: Grid,
                                      origin: Pos,
                                      dr: Int,
                                      dc: Int) -> Set<Pos> {
        var positions: Set<Pos> = []
        if isPlayablePieceSlot(origin, in: grid) { positions.insert(origin) }
        for sign in [-1, 1] {
            var p = Pos(r: origin.r + dr * sign, c: origin.c + dc * sign)
            while isValid(p, in: grid), let cell = grid[p.r][p.c] {
                if cell.kind == .normal { positions.insert(p) }
                if cell.blocker?.type.rules.blocksBlast == true { break }
                p = Pos(r: p.r + dr * sign, c: p.c + dc * sign)
            }
        }
        return positions
    }

    private static func isValid(_ position: Pos, in grid: Grid) -> Bool {
        position.r >= 0 && position.r < grid.count
            && position.c >= 0 && position.c < grid[position.r].count
    }

    private static func isPlayablePieceSlot(_ position: Pos, in grid: Grid) -> Bool {
        isValid(position, in: grid) && grid[position.r][position.c]?.kind == .normal
    }

    private static func uid() -> String {
        let t = String(Int(Date().timeIntervalSince1970 * 1000), radix: 36)
        let r = String(Int.random(in: 0..<Int(pow(36.0, 5))), radix: 36)
        return "\(t)_\(r)"
    }

    private static func uid<R: RandomNumberGenerator>(rng: inout R) -> String {
        String(rng.next(), radix: 36)
    }

    static func createInitialGrid(rows: Int, cols: Int, colors: [String], mask: [[Bool]]? = nil,
                                  spawnWeights: [PieceColor: Double] = [:]) -> Grid {
        var rng = SystemRandomNumberGenerator()
        return createInitialGrid(rows: rows, cols: cols, colors: colors, mask: mask,
                                 spawnWeights: spawnWeights, rng: &rng)
    }

    static func createInitialGrid<R: RandomNumberGenerator>(rows: Int,
                                                            cols: Int,
                                                            colors: [String],
                                                            mask: [[Bool]]? = nil,
                                                            spawnWeights: [PieceColor: Double] = [:],
                                                            rng: inout R) -> Grid {
        guard rows > 0, cols > 0, !colors.isEmpty else { return [] }
        var g: Grid = Array(repeating: Array(repeating: nil, count: cols), count: rows)
        for r in 0..<rows {
            for c in 0..<cols {
                if let m = mask, !m[r][c] { continue }
                let candidates = colors.filter { !wouldMakeInitialMatch(g, r: r, c: c, color: $0) }
                let color = weightedColor(candidates.isEmpty ? colors : candidates,
                                          weights: spawnWeights, rng: &rng)
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
        let cols = grid.first?.count ?? 0
        var groups: [[Pos]] = []

        // Horizontal runs
        for r in 0..<rows {
            var c = 0
            while c < cols {
                guard let cell = grid[r][c], cell.isMatchable else { c += 1; continue }
                let color = cell.color
                var k = c + 1
                while k < cols,
                      grid[r][k]?.isMatchable == true,
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
                guard let cell = grid[r][c], cell.isMatchable else { r += 1; continue }
                let color = cell.color
                var k = r + 1
                while k < rows,
                      grid[k][c]?.isMatchable == true,
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
            let center = wrapped.position
            let arms = [Pos(r: center.r - 1, c: center.c), Pos(r: center.r + 1, c: center.c),
                        Pos(r: center.r, c: center.c - 1), Pos(r: center.r, c: center.c + 1)]
            return SpecialSpawn(position: position,
                                special: arms.allSatisfy(wrapped.combined.contains) ? .lineBlast : .wrapped)
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
                                          excludingSpecialsAt excluded: Set<Pos>? = nil,
                                          rankedTargets: [Pos] = []) -> Set<Pos> {
        let rows = grid.count, cols = grid.first?.count ?? 0
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
            let stages = activationStagesBase(grid, special: sp, at: p,
                                             targetColor: cell.color, rankedTargets: rankedTargets, bigger: bigger)
            for stage in stages {
                for point in stage.positions { add(point.r, point.c) }
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
                guard var cell = grid[n.r][n.c], var blocker = cell.blocker,
                      blocker.type == .chest, (blocker.requiredKeys ?? 0) <= 0 else { continue }
                blocker.hits -= 1
                blocker.layer = max(0, blocker.layer - 1)
                cell.blocker = blocker.hits > 0 ? blocker : nil
                grid[n.r][n.c] = cell
                if cell.blocker == nil { opened.insert(n) }
            }
        }
        return opened
    }

    @discardableResult
    static func openFirstChest(_ grid: inout Grid) -> Pos? {
        for r in 0..<grid.count {
            for c in 0..<grid[r].count {
                guard var cell = grid[r][c], var blocker = cell.blocker,
                      blocker.type == .chest else { continue }
                let keysLeft = max(0, (blocker.requiredKeys ?? 1) - 1)
                blocker.requiredKeys = keysLeft
                cell.blocker = keysLeft > 0 ? blocker : nil
                grid[r][c] = cell
                return keysLeft == 0 ? Pos(r: r, c: c) : nil
            }
        }
        return nil
    }

    @discardableResult
    static func clearMatches(_ grid: inout Grid, matches: Set<Pos>,
                             context: ClearContext = .normal,
                             matchedPositions: Set<Pos>? = nil) -> ClearResult {
        var cleared = Set<Pos>()
        var damaged = Set<Pos>()
        var events: [GamePresentationEvent] = []
        var candidates = matches
        if context.damagesAdjacentBlockers {
            for p in matches where isValid(p, in: grid) {
                candidates.formUnion(orthogonalNeighbors(of: p, rows: grid.count, cols: grid[p.r].count))
            }
        }
        for p in candidates where isValid(p, in: grid) {
            guard var cell = grid[p.r][p.c] else { continue }
            let previousPiece = cell.piece
            let adjacent = !matches.contains(p)
            if var blocker = cell.blocker {
                guard blocker.type.rules.canBeDamaged(by: context.source, adjacent: adjacent),
                      (blocker.requiredKeys ?? 0) <= 0 || context.source == .key else { continue }
                if blocker.type == .colorLock,
                   let required = blocker.requiredColor,
                   required.lowercased() != cell.color.lowercased() {
                    grid[p.r][p.c] = cell
                    continue
                }
                let previousBlocker = blocker
                events.append(.blockerHit(at: p, blocker: previousBlocker))
                blocker.hits -= 1
                blocker.layer = max(0, blocker.layer - 1)
                damaged.insert(p)
                if blocker.hits > 0 {
                    cell.blocker = blocker
                    events.append(.blockerDamaged(at: p, before: previousBlocker, after: blocker))
                } else {
                    cell.blocker = nil
                    events.append(.blockerDestroyed(at: p, blocker: previousBlocker))
                }
                if !adjacent, blocker.type.rules.clearsPieceWithLayer,
                   cell.kind == .normal, cell.hasPiece {
                    cell.piece = nil
                    cleared.insert(p)
                }
                grid[p.r][p.c] = cell
            } else if !adjacent, cell.kind == .normal, cell.hasPiece {
                cell.piece = nil
                grid[p.r][p.c] = cell
                cleared.insert(p)
            }
            if let previousPiece, cell.piece == nil {
                if context.source == .normalMatch, (matchedPositions ?? matches).contains(p) {
                    events.append(.pieceMatched(at: p, piece: previousPiece))
                }
                if let special = previousPiece.special {
                    events.append(.specialActivated(at: p, special: special))
                }
                events.append(.pieceDestroyed(at: p, piece: previousPiece))
            }
        }
        var ordered = events.enumerated().sorted { lhs, rhs in
            let a = lhs.element.position ?? Pos(r: 0, c: 0)
            let b = rhs.element.position ?? Pos(r: 0, c: 0)
            if a.r != b.r { return a.r < b.r }
            if a.c != b.c { return a.c < b.c }
            return lhs.offset < rhs.offset
        }.map(\.element)
        let chain = ordered.compactMap { event -> Pos? in
            if case .specialActivated(let position, _) = event { return position }
            return nil
        }
        if chain.count > 1 { ordered.append(.specialChainTriggered(positions: chain)) }
        return ClearResult(cleared: cleared, damagedBlockers: damaged, presentationEvents: ordered)
    }

    /// Drop existing tiles down, then fill empties at the top with new colors.
    /// `cascadeBoost` (0…1) biases the new tile colors so they're more likely to
    /// land on a colour that already pairs with what's beneath/beside them — used
    /// in early levels to manufacture cascades and cinematic combos.
    static func collapseAndRefill(_ grid: Grid,
                                   colors: [String],
                                   mask: [[Bool]]? = nil,
                                   cascadeBoost: Double = 0,
                                   portals: [LevelPortal] = [],
                                   spawnWeights: [PieceColor: Double] = [:]) -> Grid {
        var rng = SystemRandomNumberGenerator()
        return collapseAndRefill(grid,
                                 colors: colors,
                                 mask: mask,
                                 cascadeBoost: cascadeBoost,
                                 portals: portals,
                                 spawnWeights: spawnWeights,
                                 rng: &rng)
    }

    static func collapseAndRefill<R: RandomNumberGenerator>(_ grid: Grid,
                                                            colors: [String],
                                                            mask: [[Bool]]? = nil,
                                                            cascadeBoost: Double = 0,
                                                            portals: [LevelPortal] = [],
                                                            spawnWeights: [PieceColor: Double] = [:],
                                                            rng: inout R) -> Grid {
        collapseAndRefillResult(grid, colors: colors, mask: mask, cascadeBoost: cascadeBoost,
            portals: portals, spawnWeights: spawnWeights, rng: &rng, capturesPresentation: false).grid
    }

    static func collapseAndRefillResult<R: RandomNumberGenerator>(_ grid: Grid,
        colors: [String], mask: [[Bool]]? = nil, cascadeBoost: Double = 0,
        portals: [LevelPortal] = [], spawnWeights: [PieceColor: Double] = [:],
        rng: inout R, capturesPresentation: Bool = true) -> BoardRefillResult {
        var events: [GamePresentationEvent] = []
        var transfers: [PortalPresentationTransfer] = []
        let rows = grid.count
        let cols = grid.first?.count ?? 0
        guard rows > 0, cols > 0, !colors.isEmpty else {
            return BoardRefillResult(grid: grid, presentationEvents: [], portalTransfers: [])
        }
        var g = grid
        // Legacy nil vacancies are adapted to explicit empty slots. A supplied
        // mask remains authoritative for holes in shaped boards.
        for r in 0..<rows {
            for c in 0..<cols {
                if let mask, !mask[r][c] { g[r][c] = nil }
                else if g[r][c] == nil { g[r][c] = Cell(piece: nil) }
            }
        }
        func compactColumn(_ c: Int) {
            var segment: [Int] = []
            func compact() {
                let pieces = segment.compactMap { g[$0][c]?.piece }
                for (index, r) in segment.enumerated() {
                    g[r][c]?.piece = index < pieces.count ? pieces[index] : nil
                }
                segment.removeAll()
            }
            for r in stride(from: rows - 1, through: 0, by: -1) {
                guard let cell = g[r][c], cell.blocker?.type.rules.blocksMovement != true else {
                    compact()
                    continue
                }
                segment.append(r)
            }
            compact()
        }
        // Route into empty exits before refill; bounded iterations prevent a
        // portal/gravity cycle from trapping the turn forever.
        let validPortals = validatedPortals(portals, in: g)
        for _ in 0..<max(1, rows * cols) {
            let previous = g
            g = applyPortals(g, pairs: validPortals, transfers: &transfers,
                             capturesPresentation: capturesPresentation)
            for c in 0..<cols { compactColumn(c) }
            if g == previous { break }
        }
        for c in 0..<cols {
            for r in stride(from: rows - 1, through: 0, by: -1) {
                if let cell = g[r][c], !cell.hasPiece,
                   cell.blocker?.type.rules.canContainPiece != false {
                    var picked = weightedColor(colors, weights: spawnWeights, rng: &rng)
                    if cascadeBoost > 0, Double.random(in: 0...1, using: &rng) < cascadeBoost,
                       let biased = biasedRefillColor(g, r: r, c: c) {
                        picked = biased
                    }
                    let piece = Piece(id: uid(rng: &rng), legacyColorToken: picked)
                    g[r][c]?.piece = piece
                    if capturesPresentation { events.append(.pieceCreated(at: Pos(r: r, c: c), piece: piece)) }
                }
            }
        }
        events.insert(contentsOf: transfers.map { .portalEntered(from: $0.from, to: $0.to) }, at: 0)
        return BoardRefillResult(grid: g, presentationEvents: events, portalTransfers: transfers)
    }

    static func applyPortals(_ grid: Grid, pairs: [LevelPortal]) -> Grid {
        var transfers: [PortalPresentationTransfer] = []
        return applyPortals(grid, pairs: pairs, transfers: &transfers, capturesPresentation: false)
    }

    private static func applyPortals(_ grid: Grid, pairs: [LevelPortal],
        transfers: inout [PortalPresentationTransfer], capturesPresentation: Bool) -> Grid {
        guard !pairs.isEmpty else { return grid }
        var g = grid
        for pair in validatedPortals(pairs, in: grid) {
            let from = pair.from
            let to = pair.to
            guard g[from.r][from.c]?.hasPiece == true,
                  g[to.r][to.c]?.hasPiece == false,
                  g[from.r][from.c]?.blocker?.type.rules.blocksMovement != true,
                  g[to.r][to.c]?.blocker?.type.rules.blocksMovement != true else { continue }
            let movingPiece = g[from.r][from.c]?.piece
            if capturesPresentation, let movingPiece {
                transfers.append(.init(pieceID: movingPiece.id, from: from, to: to))
            }
            g[to.r][to.c]?.piece = movingPiece
            g[from.r][from.c]?.piece = nil
        }
        return g
    }

    static func validatedPortals(_ pairs: [LevelPortal], in grid: Grid) -> [LevelPortal] {
        var sources = Set<Pos>()
        var exits = Set<Pos>()
        let valid = pairs.filter { pair in
            guard pair.from != pair.to, isValid(pair.from, in: grid), isValid(pair.to, in: grid),
                  grid[pair.from.r][pair.from.c] != nil, grid[pair.to.r][pair.to.c] != nil,
                  !sources.contains(pair.from), !exits.contains(pair.to) else { return false }
            sources.insert(pair.from)
            exits.insert(pair.to)
            return true
        }
        let links = Dictionary(uniqueKeysWithValues: valid.map { ($0.from, $0.to) })
        return valid.filter { pair in
            var visited: Set<Pos> = [pair.from]
            var next: Pos? = pair.to
            while let position = next {
                guard visited.insert(position).inserted else { return false }
                next = links[position]
            }
            return true
        }
    }

    private static func weightedColor<R: RandomNumberGenerator>(_ colors: [String],
                                                                weights: [PieceColor: Double],
                                                                rng: inout R) -> String {
        let values = colors.map { max(0, weights[PieceColor.fromLegacyToken($0)] ?? 1) }
        let total = values.reduce(0, +)
        guard total.isFinite, total > 0 else { return colors.randomElement(using: &rng)! }
        var choice = Double.random(in: 0..<total, using: &rng)
        for (index, value) in values.enumerated() {
            choice -= value
            if choice < 0 { return colors[index] }
        }
        return colors.last!
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
                cell.piece = nil
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
                cell.piece = nil
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
                g[bottom][c]?.piece = nil
                collected.insert(Pos(r: bottom, c: c))
            }
        }
        return (g, collected)
    }

    static func applyConveyors(_ grid: Grid, belts: [ConveyorBelt]) -> Grid {
        guard !belts.isEmpty else { return grid }
        var g = grid
        let rows = g.count
        let cols = g.first?.count ?? 0

        for belt in belts {
            guard belt.row >= 0, belt.row < rows else { continue }
            var positions: [Pos] = []
            func rotate() {
                guard positions.count > 1 else { positions.removeAll(); return }
                let pieces = positions.map { g[$0.r][$0.c]?.piece }
                let shift = belt.direction >= 0 ? 1 : -1
                for (index, pos) in positions.enumerated() {
                    g[pos.r][pos.c]?.piece = pieces[(index - shift + positions.count) % positions.count]
                }
                positions.removeAll()
            }
            for c in 0..<cols {
                if let cell = g[belt.row][c], cell.blocker?.type.rules.blocksMovement != true {
                    positions.append(Pos(r: belt.row, c: c))
                } else { rotate() }
            }
            rotate()
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
    static func canSwap(_ grid: Grid, _ a: Pos, _ b: Pos) -> Bool {
        guard isValid(a, in: grid), isValid(b, in: grid),
              abs(a.r - b.r) + abs(a.c - b.c) == 1,
              let first = grid[a.r][a.c], let second = grid[b.r][b.c] else { return false }
        return first.hasPiece && second.hasPiece && !first.isMovementBlocked && !second.isMovementBlocked
    }

    static func swapIfValid(_ grid: Grid, _ a: Pos, _ b: Pos) -> (didSwap: Bool, grid: Grid) {
        guard let classified = classifySwap(grid, a, b) else { return (false, grid) }
        return (true, classified.grid)
    }

    /// Single source of truth for whether an adjacent swap is legal and which
    /// activation it represents.
    static func classifySwap(_ grid: Grid, _ a: Pos, _ b: Pos) -> ClassifiedSwap? {
        var g = grid
        let rows = g.count, cols = g.first?.count ?? 0
        guard a.r >= 0, a.r < rows, a.c >= 0, a.c < cols,
              b.r >= 0, b.r < rows, b.c >= 0, b.c < cols,
              abs(a.r - b.r) + abs(a.c - b.c) == 1,
              g[a.r][a.c] != nil, g[b.r][b.c] != nil else {
            return nil
        }
        let cellA = g[a.r][a.c]!
        let cellB = g[b.r][b.c]!
        guard cellA.hasPiece, cellB.hasPiece,
              cellA.blocker?.type.rules.blocksMovement != true,
              cellB.blocker?.type.rules.blocksMovement != true else { return nil }
        g[a.r][a.c]?.piece = cellB.piece
        g[b.r][b.c]?.piece = cellA.piece

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
        let rows = grid.count, cols = grid.first?.count ?? 0
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
        let rows = grid.count, cols = grid.first?.count ?? 0
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

    /// Shuffle whole movable pieces, preserving identity, powers and every
    /// anchored tile. Failure is explicit so callers never accept a dead board.
    static func shuffledPlayableGrid(_ grid: Grid, maxAttempts: Int = 200) -> Grid? {
        var rng = SystemRandomNumberGenerator()
        return shuffledPlayableGrid(grid, maxAttempts: maxAttempts, rng: &rng)
    }

    static func shuffledPlayableGrid<R: RandomNumberGenerator>(_ grid: Grid,
                                                               maxAttempts: Int = 200,
                                                               rng: inout R) -> Grid? {
        var positions: [Pos] = []
        var pieces: [Piece] = []
        for r in grid.indices {
            for c in grid[r].indices {
                guard let cell = grid[r][c], let piece = cell.piece,
                      !cell.isMovementBlocked else { continue }
                positions.append(Pos(r: r, c: c))
                pieces.append(piece)
            }
        }
        guard positions.count > 1, maxAttempts > 0 else { return nil }
        for _ in 0..<min(maxAttempts, 10_000) {
            var candidate = grid
            let shuffled = pieces.shuffled(using: &rng)
            for (index, position) in positions.enumerated() {
                candidate[position.r][position.c]?.piece = shuffled[index]
            }
            if findMatches(candidate).isEmpty, findSquares(candidate).isEmpty, hasAnyMoves(candidate) {
                return candidate
            }
        }
        return nil
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
            case .lineBlast:   score += 350
            case .rocket:      score += 300
            case .ufo:         score += 400
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
        if r >= 1, c >= 1, g[r - 1][c]?.color == color,
           g[r][c - 1]?.color == color, g[r - 1][c - 1]?.color == color { return true }
        return false
    }

    private static func createsMatch(_ g: Grid, at p: Pos) -> Bool {
        let rows = g.count, cols = g[0].count
        guard let here = g[p.r][p.c], here.isMatchable else { return false }
        let color = here.color

        var cnt = 1
        var x = p.c - 1
        while x >= 0, g[p.r][x]?.isMatchable == true, g[p.r][x]?.color == color { cnt += 1; x -= 1 }
        x = p.c + 1
        while x < cols, g[p.r][x]?.isMatchable == true, g[p.r][x]?.color == color { cnt += 1; x += 1 }
        if cnt >= 3 { return true }

        cnt = 1
        var y = p.r - 1
        while y >= 0, g[y][p.c]?.isMatchable == true, g[y][p.c]?.color == color { cnt += 1; y -= 1 }
        y = p.r + 1
        while y < rows, g[y][p.c]?.isMatchable == true, g[y][p.c]?.color == color { cnt += 1; y += 1 }
        return cnt >= 3
    }

    /// A 2x2 block of identical-colour plain tiles — a new match type that
    /// spawns a Fish special.
    private static func isUniformPlainSquare(_ g: Grid, _ quad: [Pos]) -> Bool {
        guard let first = g[quad[0].r][quad[0].c],
              first.blocker == nil, first.isMatchable, first.special == nil else { return false }
        for p in quad.dropFirst() {
            guard let cell = g[p.r][p.c],
                  cell.blocker == nil, cell.isMatchable, cell.special == nil,
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
