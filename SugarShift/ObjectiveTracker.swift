import Foundation

enum LevelObjective: Codable, Hashable {
    case collectPieces(color: PieceColor, count: Int)
    case clearJelly(count: Int)
    case breakIce(count: Int)
    case breakBlockers(count: Int)
    case collectIngredients(count: Int)
    case reachScore(Int)
    case collectKeys(count: Int)
    case freePieces(count: Int)
    case clearChocolate(count: Int)
    case destroySpecificBlocker(type: BlockerType, count: Int)
    case comboObjective(minimumDepth: Int, count: Int)
    // Exact adapters for existing campaign goals and crown encounters.
    case createSpecials(count: Int)
    case detonateBombs(count: Int)
    case breakBossShield(count: Int)

    var target: Int {
        switch self {
        case .collectPieces(_, let count), .clearJelly(let count), .breakIce(let count),
             .breakBlockers(let count), .collectIngredients(let count), .reachScore(let count),
             .collectKeys(let count), .freePieces(let count), .clearChocolate(let count),
             .destroySpecificBlocker(_, let count), .comboObjective(_, let count),
             .createSpecials(let count), .detonateBombs(let count), .breakBossShield(let count):
            return count
        }
    }
}

enum ObjectiveEvent: Equatable {
    case piecesCleared(color: PieceColor, count: Int)
    case jellyCleared(count: Int)
    case iceBroken(count: Int)
    case blockersBroken(count: Int)
    /// One destruction event updates the specific type AND applicable general
    /// blocker objectives. Do not also send blockersBroken for the same tile.
    case blockerDestroyed(type: BlockerType, count: Int)
    case ingredientsCollected(count: Int)
    case keysCollected(count: Int)
    case piecesFreed(count: Int)
    case chocolateCleared(count: Int)
    case scoreEarned(Int)
    case combo(depth: Int)
    case specialsCreated(count: Int)
    case bombsDetonated(count: Int)
    case bossShieldDamaged(count: Int)
}

struct ObjectiveProgress: Equatable {
    let objective: LevelObjective
    let current: Int
    var target: Int { objective.target }
    var isComplete: Bool { current >= target }
    var fraction: Double { target > 0 ? min(1, Double(current) / Double(target)) : 1 }
}

/// Pure value state: storing this alongside a board snapshot makes Undo restore
/// every objective, including score and simultaneous drop-item requirements.
struct ObjectiveTracker: Equatable, Codable {
    let objectives: [LevelObjective]
    private var counts: [Int]
    /// Presentation detail for a legacy "clear blockers" goal. Kept in this
    /// value state so Undo restores the breakdown together with the total.
    private(set) var destroyedBlockers: [BlockerType: Int] = [:]

    init(objectives: [LevelObjective]) {
        self.objectives = objectives
        self.counts = Array(repeating: 0, count: objectives.count)
    }

    private enum CodingKeys: String, CodingKey { case objectives, counts, destroyedBlockers }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        objectives = try values.decode([LevelObjective].self, forKey: .objectives)
        counts = try values.decode([Int].self, forKey: .counts)
        destroyedBlockers = try values.decodeIfPresent([BlockerType: Int].self, forKey: .destroyedBlockers) ?? [:]
    }

    var progresses: [ObjectiveProgress] {
        objectives.enumerated().map { ObjectiveProgress(objective: $0.element, current: counts[$0.offset]) }
    }
    var isComplete: Bool { !objectives.isEmpty && progresses.allSatisfy(\.isComplete) }
    var progressFraction: Double {
        guard !objectives.isEmpty else { return 0 }
        return progresses.reduce(0) { $0 + $1.fraction } / Double(objectives.count)
    }
    func progress(for objective: LevelObjective) -> ObjectiveProgress {
        let current = objectives.firstIndex(of: objective).map { counts[$0] } ?? 0
        return ObjectiveProgress(objective: objective, current: current)
    }

    mutating func consume(_ event: ObjectiveEvent) {
        if case .blockerDestroyed(let type, let count) = event {
            destroyedBlockers[type, default: 0] += max(0, count)
        }
        for index in objectives.indices {
            let objective = objectives[index]
            let amount: Int
            switch (objective, event) {
            case (.collectPieces(let wanted, _), .piecesCleared(let color, let count)) where wanted == color:
                amount = count
            case (.clearJelly, .jellyCleared(let count)), (.breakIce, .iceBroken(let count)),
                 (.breakBlockers, .blockersBroken(let count)),
                 (.collectIngredients, .ingredientsCollected(let count)),
                 (.collectKeys, .keysCollected(let count)), (.freePieces, .piecesFreed(let count)),
                 (.clearChocolate, .chocolateCleared(let count)), (.reachScore, .scoreEarned(let count)),
                 (.createSpecials, .specialsCreated(let count)), (.detonateBombs, .bombsDetonated(let count)),
                 (.breakBossShield, .bossShieldDamaged(let count)):
                amount = count
            case (.destroySpecificBlocker(let wanted, _), .blockerDestroyed(let type, let count)) where wanted == type:
                amount = count
            case (.breakBlockers, .blockerDestroyed(_, let count)),
                 (.clearJelly, .blockerDestroyed(.jelly, let count)),
                 (.breakIce, .blockerDestroyed(.ice, let count)),
                 (.clearChocolate, .blockerDestroyed(.chocolate, let count)):
                amount = count
            case (.freePieces, .blockerDestroyed(let type, let count)) where [.lock, .colorLock, .cage, .vine].contains(type):
                amount = count
            case (.comboObjective(let minimumDepth, _), .combo(let depth)) where depth >= minimumDepth:
                amount = 1
            default: amount = 0
            }
            let remaining = max(0, objective.target - counts[index])
            counts[index] += min(remaining, max(0, amount))
        }
    }
}

extension LevelGoal {
    func objectives(targetScore: Int, blockerCount: Int) -> [LevelObjective] {
        switch self {
        case .score: return [.reachScore(targetScore)]
        case .clearBlockers: return [.breakBlockers(count: blockerCount)]
        case .collectColor(let index, let count):
            return [.collectPieces(color: .fromLegacyPaletteIndex(index), count: count)]
        case .createSpecials(let count): return [.createSpecials(count: count)]
        case .detonateBombs(let count): return [.detonateBombs(count: count)]
        case .collectIngredients(let count): return [.collectIngredients(count: count)]
        case .collectKeys(let count): return [.collectKeys(count: count)]
        case .openChests(let count): return [.destroySpecificBlocker(type: .chest, count: count)]
        case .collectIngredientsAndKeys(let ingredients, let keys):
            return [.collectIngredients(count: ingredients), .collectKeys(count: keys)]
        }
    }
}
