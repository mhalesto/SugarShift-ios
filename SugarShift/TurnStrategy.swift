import Foundation

/// What the player deliberately committed before refill randomness begins.
/// Keeping this separate from cascade depth lets mastery rewards favour agency
/// without pretending every lucky refill was planned.
enum TurnIntent: String, Equatable {
    case match
    case special
    case specialCombo
    case playerSmash
}

enum TurnMasteryGrade: Int, Comparable, Equatable {
    case routine
    case purposeful
    case powerful
    case masterful

    static func < (lhs: TurnMasteryGrade, rhs: TurnMasteryGrade) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct TurnMasteryOutcome: Equatable {
    let grade: TurnMasteryGrade
    let flowBefore: Int
    let flowAfter: Int
    let scoreBonus: Int
    let smashBonus: Int
    let chargesSugarRush: Bool

    var flowChanged: Bool { flowBefore != flowAfter }
}

/// Pure policy for the multi-turn Flow loop. Objective work, deliberately
/// created specials, and power-up combinations build Flow. Routine clears cool
/// it by one visible step rather than silently deleting the entire streak.
enum TurnMasteryPolicy {
    static let maximumFlow = 5
    static let sugarRushFlow = 3

    static func evaluate(flow: Int,
                         intent: TurnIntent,
                         tilesCleared: Int,
                         blockersDamaged: Int,
                         specialsTriggered: Int,
                         specialsCreated: Int,
                         objectiveHits: Int,
                         cascadeDepth: Int,
                         scoreEarned: Int) -> TurnMasteryOutcome {
        let before = max(0, min(maximumFlow, flow))
        let deliberate = intent == .specialCombo
            || specialsCreated > 0
            || objectiveHits > 0
            || blockersDamaged >= 2
            || (intent == .special && specialsTriggered > 0)

        var impact = max(0, objectiveHits) * 4
            + max(0, blockersDamaged) * 2
            + max(0, specialsTriggered) * 3
            + max(0, specialsCreated) * 6
            + min(5, max(0, tilesCleared - 3) / 3)
            + min(3, max(0, cascadeDepth - 1))
        if intent == .specialCombo { impact += 12 }
        if intent == .playerSmash { impact += 6 }

        let grade: TurnMasteryGrade
        if intent == .specialCombo || impact >= 20 {
            grade = .masterful
        } else if impact >= 11 {
            grade = .powerful
        } else if impact >= 5 || deliberate {
            grade = .purposeful
        } else {
            grade = .routine
        }

        let after: Int
        if intent == .playerSmash {
            // Smash cashes in prior work; it should not recursively manufacture
            // more Flow, but it also should not punish the player for spending it.
            after = before
        } else if deliberate {
            let step = grade == .masterful ? 2 : 1
            after = min(maximumFlow, before + step)
        } else {
            after = max(0, before - 1)
        }

        let gradeRate: Double
        switch grade {
        case .routine:    gradeRate = 0
        case .purposeful: gradeRate = 0.05
        case .powerful:   gradeRate = 0.09
        case .masterful:  gradeRate = 0.14
        }
        let scoreRate = grade == .routine
            ? 0
            : min(0.34, gradeRate + Double(after) * 0.04)
        let scoreBonus = Int((Double(max(0, scoreEarned)) * scoreRate).rounded())

        let smashBonus: Int
        if intent == .playerSmash {
            smashBonus = 0
        } else {
            switch grade {
            case .routine:    smashBonus = 0
            case .purposeful: smashBonus = 2
            case .powerful:   smashBonus = 5
            case .masterful:  smashBonus = 8
            }
        }

        return TurnMasteryOutcome(
            grade: grade,
            flowBefore: before,
            flowAfter: after,
            scoreBonus: scoreBonus,
            smashBonus: smashBonus,
            chargesSugarRush: before < sugarRushFlow && after >= sugarRushFlow)
    }
}

enum TacticalMoveReason: Equatable {
    case specialCombo(SpecialComboKind)
    case objective(Int)
    case hazard(Int)
    case createsSpecial(Special)
    case powerClear(Int)
    case match
}

struct TacticalMoveAnalysis {
    let move: (Pos, Pos)
    let score: Int
    let affected: Set<Pos>
    let objectivePositions: Set<Pos>
    let hazardPositions: Set<Pos>
    let createdSpecial: Special?
    let reason: TacticalMoveReason
}

struct TacticalSmashAnalysis {
    let tier: PlayerSmashTier
    let center: Pos
    let affected: Set<Pos>
    let objectivePositions: Set<Pos>
    let hazardPositions: Set<Pos>
    let score: Int
}

/// Shared target intelligence for manual Smashes. Live previews and the
/// deterministic balance bot both consume the exact Engine footprint.
enum TacticalSmashEvaluator {
    static func analysis(tier: PlayerSmashTier,
                         centeredAt center: Pos,
                         in grid: Grid,
                         config: LevelConfig,
                         sugarRushCharged: Bool = false) -> TacticalSmashAnalysis? {
        guard center.r >= 0, center.r < grid.count,
              center.c >= 0, center.c < grid[center.r].count,
              grid[center.r][center.c]?.kind == .normal else { return nil }
        let base = Engine.playerSmashFootprint(in: grid,
                                               centeredAt: center,
                                               tier: tier)
        let expanded = Engine.expandMatchesWithSpecials(
            grid,
            base,
            bigger: config.modifiers.contains(.specialsExplodeBigger))
        let affected = sugarRushCharged
            ? Engine.sugarRushResolution(in: grid,
                                         base: expanded,
                                         preferredAnchor: center).positions
            : expanded
        guard !affected.isEmpty else { return nil }

        let objectivePositions = Set(affected.filter {
            TacticalMoveEvaluator.isObjectivePosition($0, in: grid, config: config)
        })
        let hazardPositions = Set(affected.filter {
            guard let type = grid[$0.r][$0.c]?.blocker?.type else { return false }
            return type == .countdown || type == .chocolate
                || type == .syrup || type == .vine
        })
        let hazardValue = hazardPositions.reduce(into: 0) { total, position in
            guard let blocker = grid[position.r][position.c]?.blocker else { return }
            if blocker.type == .countdown {
                total += max(2, 8 - (blocker.countdown ?? 5)) * 22
            } else if blocker.type == .chocolate {
                total += 70
            } else {
                total += 42
            }
        }
        let specialCount = affected.reduce(into: 0) { count, position in
            if grid[position.r][position.c]?.special != nil { count += 1 }
        }
        let blockerCount = affected.reduce(into: 0) { count, position in
            if grid[position.r][position.c]?.blocker != nil { count += 1 }
        }
        let score = affected.count * 10
            + objectivePositions.count * 90
            + hazardValue
            + specialCount * 42
            + blockerCount * 24

        return TacticalSmashAnalysis(tier: tier,
                                     center: center,
                                     affected: affected,
                                     objectivePositions: objectivePositions,
                                     hazardPositions: hazardPositions,
                                     score: score)
    }

    static func bestTarget(tier: PlayerSmashTier,
                           in grid: Grid,
                           config: LevelConfig,
                           sugarRushCharged: Bool = false) -> TacticalSmashAnalysis? {
        var best: TacticalSmashAnalysis?
        for r in 0..<grid.count {
            for c in 0..<grid[r].count {
                guard let candidate = analysis(tier: tier,
                                               centeredAt: Pos(r: r, c: c),
                                               in: grid,
                                               config: config,
                                               sugarRushCharged: sugarRushCharged) else { continue }
                guard let current = best else {
                    best = candidate
                    continue
                }
                if candidate.score > current.score
                    || (candidate.score == current.score && candidate.center.r < current.center.r)
                    || (candidate.score == current.score
                        && candidate.center.r == current.center.r
                        && candidate.center.c < current.center.c) {
                    best = candidate
                }
            }
        }
        return best
    }
}

/// Shared objective-aware move intelligence for hints, previews, and the
/// deterministic balance bot. It layers level intent and urgent hazards over
/// Engine's canonical legality/special-creation score instead of duplicating
/// swap rules in the scene.
enum TacticalMoveEvaluator {
    static func rankedMoves(in grid: Grid,
                            config: LevelConfig,
                            sugarRushCharged: Bool = false) -> [TacticalMoveAnalysis] {
        Engine.scoredLegalMoves(grid).compactMap { candidate in
            analysis(for: candidate.move.0,
                     candidate.move.1,
                     in: grid,
                     config: config,
                     engineScore: candidate.score,
                     sugarRushCharged: sugarRushCharged)
        }.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.move.0.r != rhs.move.0.r { return lhs.move.0.r < rhs.move.0.r }
            if lhs.move.0.c != rhs.move.0.c { return lhs.move.0.c < rhs.move.0.c }
            if lhs.move.1.r != rhs.move.1.r { return lhs.move.1.r < rhs.move.1.r }
            return lhs.move.1.c < rhs.move.1.c
        }
    }

    static func analysis(for a: Pos,
                         _ b: Pos,
                         in grid: Grid,
                         config: LevelConfig,
                         engineScore: Int? = nil,
                         sugarRushCharged: Bool = false) -> TacticalMoveAnalysis? {
        guard let swap = Engine.classifySwap(grid, a, b) else { return nil }
        let baseScore = engineScore ?? Engine.scoredLegalMoves(grid)
            .first(where: { $0.move.0 == a && $0.move.1 == b })?.score ?? 0

        var affected = affectedPositions(for: swap,
                                         move: (a, b),
                                         originalGrid: grid,
                                         config: config)
        if sugarRushCharged {
            affected = Engine.sugarRushResolution(in: swap.grid,
                                                  base: affected,
                                                  preferredAnchor: b).positions
        }

        let createdSpecial = predictedSpecial(in: swap.grid,
                                              originalGrid: grid,
                                              move: (a, b))
        let objectivePositions: Set<Pos>
        if case .createSpecials = config.goal, createdSpecial != nil {
            objectivePositions = [b]
        } else {
            objectivePositions = Set(affected.filter {
                isObjectivePosition($0, in: swap.grid, config: config)
            })
        }
        let hazardPositions = Set(affected.filter {
            guard let type = swap.grid[$0.r][$0.c]?.blocker?.type else { return false }
            return type == .countdown || type == .chocolate || type == .syrup || type == .vine
        })

        let urgentHazardBonus = hazardPositions.reduce(into: 0) { total, position in
            guard let blocker = swap.grid[position.r][position.c]?.blocker else { return }
            if blocker.type == .countdown {
                total += max(1, 7 - (blocker.countdown ?? 5)) * 18
            } else if blocker.type == .chocolate {
                total += 48
            } else {
                total += 30
            }
        }
        let objectiveBonus = objectivePositions.count * 62
        let rushBonus = sugarRushCharged ? affected.count * 3 : 0
        let totalScore = baseScore + objectiveBonus + urgentHazardBonus
            + affected.count * 2 + rushBonus

        let reason: TacticalMoveReason
        if case .specialCombo(let kind, _, _, _) = swap.activation {
            reason = .specialCombo(kind)
        } else if !objectivePositions.isEmpty {
            reason = .objective(objectivePositions.count)
        } else if !hazardPositions.isEmpty {
            reason = .hazard(hazardPositions.count)
        } else if let createdSpecial {
            reason = .createsSpecial(createdSpecial)
        } else if affected.count >= 6 {
            reason = .powerClear(affected.count)
        } else {
            reason = .match
        }

        return TacticalMoveAnalysis(move: (a, b),
                                    score: totalScore,
                                    affected: affected,
                                    objectivePositions: objectivePositions,
                                    hazardPositions: hazardPositions,
                                    createdSpecial: createdSpecial,
                                    reason: reason)
    }

    private static func affectedPositions(for swap: ClassifiedSwap,
                                          move: (Pos, Pos),
                                          originalGrid: Grid,
                                          config: LevelConfig) -> Set<Pos> {
        switch swap.activation {
        case .normal:
            var positions = Engine.findMatches(swap.grid)
            for square in Engine.findSquares(swap.grid) { positions.formUnion(square) }
            return Engine.expandMatchesWithSpecials(
                swap.grid,
                positions,
                bigger: config.modifiers.contains(.specialsExplodeBigger))

        case .colorBomb(let position, let targetColor):
            var positions: Set<Pos> = [position]
            for r in 0..<swap.grid.count {
                for c in 0..<swap.grid[r].count where swap.grid[r][c]?.color == targetColor {
                    positions.insert(Pos(r: r, c: c))
                }
            }
            return Engine.expandMatchesWithSpecials(
                swap.grid,
                positions,
                bigger: config.modifiers.contains(.specialsExplodeBigger),
                excludingSpecialsAt: [position])

        case .specialCombo(let kind, let first, let second, let targetColor):
            let excluded = Set([move.0, move.1])
            return Engine.resolveSpecialCombo(
                swap.grid,
                kind: kind,
                first: first,
                second: second,
                positions: move,
                targetColor: targetColor,
                rankedFishTargets: rankedTargets(in: swap.grid,
                                                 config: config,
                                                 excluding: excluded),
                bigger: config.modifiers.contains(.specialsExplodeBigger))
        }
    }

    private static func predictedSpecial(in grid: Grid,
                                         originalGrid: Grid,
                                         move: (Pos, Pos)) -> Special? {
        let groups = Engine.findMatchGroups(grid)
        if let spawn = Engine.specialSpawn(from: groups,
                                           preferredPositions: [move.1, move.0]) {
            return spawn.special
        }
        let makesNewSquare = Engine.findSquares(grid).contains { square in
            (square.contains(move.0) || square.contains(move.1))
                && !Engine.findSquares(originalGrid).contains(square)
        }
        return makesNewSquare ? .fish : nil
    }

    static func isObjectivePosition(_ position: Pos,
                                    in grid: Grid,
                                    config: LevelConfig) -> Bool {
        guard let cell = grid[position.r][position.c] else { return false }
        switch config.goal {
        case .score:
            return false
        case .clearBlockers:
            return cell.blocker != nil
        case .collectColor(let index, _):
            let palette = config.pieceTypes.map(\.legacyToken)
            let target = palette[max(0, index) % max(1, palette.count)]
            return cell.color.lowercased() == target.lowercased()
        case .createSpecials:
            return false
        case .detonateBombs:
            return cell.special == .bomb
        case .collectIngredients, .collectKeys, .collectIngredientsAndKeys:
            for r in 0..<min(position.r, grid.count) {
                guard position.c < grid[r].count,
                      let drop = grid[r][position.c] else { continue }
                if drop.kind != .normal { return true }
            }
            return false
        case .openChests:
            return cell.blocker?.type == .chest
        }
    }

    static func rankedTargets(in grid: Grid,
                              config: LevelConfig,
                              excluding: Set<Pos>) -> [Pos] {
        let palette = config.pieceTypes.map(\.legacyToken)
        let goalColor: String?
        if case .collectColor(let index, _) = config.goal {
            goalColor = palette[max(0, index) % max(1, palette.count)].lowercased()
        } else {
            goalColor = nil
        }
        var dropItems: [Pos] = []
        for r in 0..<grid.count {
            for c in 0..<grid[r].count where grid[r][c]?.kind != .normal {
                dropItems.append(Pos(r: r, c: c))
            }
        }

        func priority(_ position: Pos) -> Int {
            guard let cell = grid[position.r][position.c] else { return Int.min }
            if cell.blocker != nil { return 400 }
            if let drop = dropItems
                .filter({ $0.c == position.c && position.r > $0.r })
                .min(by: { (position.r - $0.r) < (position.r - $1.r) }) {
                return 360 - (position.r - drop.r)
            }
            if let goalColor, cell.color.lowercased() == goalColor { return 300 }
            if cell.special != nil { return 200 }
            return 100 + position.r
        }

        var candidates: [Pos] = []
        for r in 0..<grid.count {
            for c in 0..<grid[r].count {
                let position = Pos(r: r, c: c)
                if grid[r][c]?.kind == .normal, !excluding.contains(position) {
                    candidates.append(position)
                }
            }
        }
        return candidates.sorted {
            let lhs = priority($0), rhs = priority($1)
            if lhs != rhs { return lhs > rhs }
            if $0.r != $1.r { return $0.r > $1.r }
            return $0.c < $1.c
        }
    }
}
