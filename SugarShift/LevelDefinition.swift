import Foundation

struct LevelCell: Codable, Hashable {
    let row: Int
    let column: Int
    var position: Pos { Pos(r: row, c: column) }
}

struct LevelFixedBlocker: Codable, Equatable {
    let position: LevelCell
    let type: BlockerType
    let hits: Int
}

struct LevelDefinitionPortal: Codable, Equatable {
    let from: LevelCell
    let to: LevelCell
}

struct LevelDefinitionConveyor: Codable, Equatable {
    let row: Int
    let direction: Int
}

struct LevelStarThresholds: Codable, Equatable {
    let one: Int
    let two: Int
    let three: Int
}

enum LevelBooster: String, Codable, CaseIterable {
    case hammer, shuffle, swap, extraMoves
}

enum LevelTutorial: String, Codable {
    case basicSwap, striped, wrapped, colorBomb
}

enum LevelDefinitionValidationError: Error, Equatable {
    case invalidDimensions
    case invalidActiveCells
    case disconnectedActiveCells
    case noPlayableMovesGeometry
    case invalidPieceTypes
    case invalidSpawnWeights
    case invalidMoves
    case invalidStarThresholds
    case invalidBlockers
    case invalidPortals
    case invalidConveyors
    case invalidObjectiveTarget
    case objectiveUsesUnavailablePiece(PieceColor)
    case impossibleObjective(LevelObjective)
}

/// A serializable, validated authoring surface. Legacy generated campaign
/// layouts continue using LevelConfig; authored levels override the same API.
struct LevelDefinition: Codable, Equatable {
    let id: Int
    let boardWidth: Int
    let boardHeight: Int
    let activeCells: [LevelCell]
    let pieceTypes: [PieceColor]
    let moves: Int
    let objectives: [LevelObjective]
    let fixedBlockers: [LevelFixedBlocker]
    let portals: [LevelDefinitionPortal]
    let conveyors: [LevelDefinitionConveyor]
    let starThresholds: LevelStarThresholds
    let difficulty: LevelDifficulty
    let rewards: LevelReward
    let allowedBoosters: [LevelBooster]
    let spawnWeights: [PieceColor: Double]
    let tutorial: LevelTutorial?
    let ingredientCount: Int
    let keyCount: Int

    init(id: Int, boardWidth: Int, boardHeight: Int, activeCells: [LevelCell],
         pieceTypes: [PieceColor], moves: Int, objectives: [LevelObjective],
         fixedBlockers: [LevelFixedBlocker] = [], portals: [LevelDefinitionPortal] = [],
         conveyors: [LevelDefinitionConveyor] = [], starThresholds: LevelStarThresholds,
         difficulty: LevelDifficulty = .normal,
         rewards: LevelReward = LevelReward(title: "", coins: 0, lives: 0, shuffles: 0, hammers: 0, swaps: 0),
         allowedBoosters: [LevelBooster] = LevelBooster.allCases,
         spawnWeights: [PieceColor: Double] = [:], tutorial: LevelTutorial? = nil,
         ingredientCount: Int = 0, keyCount: Int = 0) {
        self.id = id
        self.boardWidth = boardWidth
        self.boardHeight = boardHeight
        self.activeCells = activeCells
        self.pieceTypes = pieceTypes
        self.moves = moves
        self.objectives = objectives
        self.fixedBlockers = fixedBlockers
        self.portals = portals
        self.conveyors = conveyors
        self.starThresholds = starThresholds
        self.difficulty = difficulty
        self.rewards = rewards
        self.allowedBoosters = allowedBoosters
        self.spawnWeights = spawnWeights.isEmpty
            ? Dictionary(uniqueKeysWithValues: Set(pieceTypes).map { ($0, 1.0) }) : spawnWeights
        self.tutorial = tutorial
        self.ingredientCount = ingredientCount
        self.keyCount = keyCount
    }

    private enum CodingKeys: String, CodingKey {
        case id, boardWidth, boardHeight, activeCells, pieceTypes, moves, objectives
        case fixedBlockers, portals, conveyors, starThresholds, difficulty, rewards
        case allowedBoosters, spawnWeights, tutorial, ingredientCount, keyCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        boardWidth = try c.decode(Int.self, forKey: .boardWidth)
        boardHeight = try c.decode(Int.self, forKey: .boardHeight)
        activeCells = try c.decode([LevelCell].self, forKey: .activeCells)
        pieceTypes = try c.decode([PieceColor].self, forKey: .pieceTypes)
        moves = try c.decode(Int.self, forKey: .moves)
        objectives = try c.decode([LevelObjective].self, forKey: .objectives)
        fixedBlockers = try c.decodeIfPresent([LevelFixedBlocker].self, forKey: .fixedBlockers) ?? []
        portals = try c.decodeIfPresent([LevelDefinitionPortal].self, forKey: .portals) ?? []
        conveyors = try c.decodeIfPresent([LevelDefinitionConveyor].self, forKey: .conveyors) ?? []
        starThresholds = try c.decode(LevelStarThresholds.self, forKey: .starThresholds)
        difficulty = try c.decode(LevelDifficulty.self, forKey: .difficulty)
        rewards = try c.decode(LevelReward.self, forKey: .rewards)
        allowedBoosters = try c.decode([LevelBooster].self, forKey: .allowedBoosters)
        spawnWeights = try c.decode([PieceColor: Double].self, forKey: .spawnWeights)
        tutorial = try c.decodeIfPresent(LevelTutorial.self, forKey: .tutorial)
        ingredientCount = try c.decodeIfPresent(Int.self, forKey: .ingredientCount) ?? 0
        keyCount = try c.decodeIfPresent(Int.self, forKey: .keyCount) ?? 0
        _ = try validated()
    }

    func validated() throws -> Self {
        guard id > 0, (3...16).contains(boardWidth), (3...16).contains(boardHeight) else {
            throw LevelDefinitionValidationError.invalidDimensions
        }
        let active = Set(activeCells)
        guard !active.isEmpty, active.count == activeCells.count,
              active.allSatisfy({ (0..<boardHeight).contains($0.row) && (0..<boardWidth).contains($0.column) }) else {
            throw LevelDefinitionValidationError.invalidActiveCells
        }
        var reached: Set<LevelCell> = [activeCells[0]]
        var queue = [activeCells[0]]
        var index = 0
        while index < queue.count {
            let cell = queue[index]
            index += 1
            for neighbor in neighbors(of: cell) where active.contains(neighbor) && reached.insert(neighbor).inserted {
                queue.append(neighbor)
            }
        }
        guard reached == active else { throw LevelDefinitionValidationError.disconnectedActiveCells }
        let immovable = Set(fixedBlockers.filter { $0.type == .solidX }.map(\.position))
        let playable = active.subtracting(immovable)
        // A line of three needs a fourth adjacent cell to permit a swap into
        // that line. Merely having three isolated playable cells cannot work.
        let canMatch = playable.contains { cell in
            [(0, 1), (1, 0)].contains { dr, dc in
                let line: Set<LevelCell> = Set((0..<3).map {
                    LevelCell(row: cell.row + dr * $0, column: cell.column + dc * $0)
                })
                return line.isSubset(of: playable) && line.contains { member in
                    neighbors(of: member).contains { playable.contains($0) && !line.contains($0) }
                }
            }
        }
        guard canMatch else { throw LevelDefinitionValidationError.noPlayableMovesGeometry }
        guard pieceTypes.count >= 3, Set(pieceTypes).count == pieceTypes.count else {
            throw LevelDefinitionValidationError.invalidPieceTypes
        }
        guard Set(spawnWeights.keys) == Set(pieceTypes),
              spawnWeights.values.allSatisfy({ $0.isFinite && $0 > 0 }) else {
            throw LevelDefinitionValidationError.invalidSpawnWeights
        }
        guard moves > 0 else { throw LevelDefinitionValidationError.invalidMoves }
        guard starThresholds.one > 0, starThresholds.two > starThresholds.one,
              starThresholds.three > starThresholds.two else { throw LevelDefinitionValidationError.invalidStarThresholds }
        guard Set(fixedBlockers.map(\.position)).count == fixedBlockers.count,
              fixedBlockers.allSatisfy({ active.contains($0.position) && $0.hits > 0 }) else {
            throw LevelDefinitionValidationError.invalidBlockers
        }
        let endpoints = portals.flatMap { [$0.from, $0.to] }
        guard Set(endpoints).count == endpoints.count,
              endpoints.allSatisfy({ playable.contains($0) }), portals.allSatisfy({ $0.from != $0.to }) else {
            throw LevelDefinitionValidationError.invalidPortals
        }
        guard Set(conveyors.map(\.row)).count == conveyors.count,
              conveyors.allSatisfy({ belt in
                  abs(belt.direction) == 1 && (0..<boardHeight).contains(belt.row)
                    && active.filter { $0.row == belt.row }.count >= 2
              }) else { throw LevelDefinitionValidationError.invalidConveyors }
        guard !objectives.isEmpty, objectives.allSatisfy({ $0.target > 0 }),
              ingredientCount >= 0, keyCount >= 0 else { throw LevelDefinitionValidationError.invalidObjectiveTarget }
        func blockers(_ types: Set<BlockerType>) -> Int {
            fixedBlockers.filter { types.contains($0.type) }.count
        }
        for objective in objectives {
            let capacity: Int?
            switch objective {
            case .collectPieces(let color, _):
                guard pieceTypes.contains(color) else { throw LevelDefinitionValidationError.objectiveUsesUnavailablePiece(color) }
                capacity = nil // Refill allows more collections than initial cells.
            case .clearJelly: capacity = blockers([.jelly])
            case .breakIce: capacity = blockers([.ice])
            case .breakBlockers: capacity = fixedBlockers.filter { $0.type != .solidX }.count
            case .collectIngredients: capacity = ingredientCount
            case .collectKeys: capacity = keyCount
            case .freePieces: capacity = blockers([.lock, .colorLock, .cage, .vine])
            case .clearChocolate: capacity = blockers([.chocolate]) > 0 ? nil : 0
            case .destroySpecificBlocker(let type, _): capacity = type == .solidX ? 0 : blockers([type])
            case .comboObjective(let depth, _):
                guard depth > 0 else { throw LevelDefinitionValidationError.invalidObjectiveTarget }
                capacity = moves
            case .reachScore, .createSpecials, .detonateBombs, .breakBossShield: capacity = nil
            }
            if let capacity, objective.target > capacity { throw LevelDefinitionValidationError.impossibleObjective(objective) }
        }
        return self
    }

    var mask: [[Bool]] {
        let active = Set(activeCells)
        return (0..<boardHeight).map { row in
            (0..<boardWidth).map { active.contains(LevelCell(row: row, column: $0)) }
        }
    }

    private func neighbors(of cell: LevelCell) -> [LevelCell] {
        [LevelCell(row: cell.row - 1, column: cell.column), LevelCell(row: cell.row + 1, column: cell.column),
         LevelCell(row: cell.row, column: cell.column - 1), LevelCell(row: cell.row, column: cell.column + 1)]
    }
}
