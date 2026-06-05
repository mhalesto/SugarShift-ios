import Foundation

struct LevelDesignRow: Equatable {
    let level: Int
    let chapter: String
    let difficulty: LevelDifficulty
    let goal: String
    let moves: Int
    let target: Int
    let mechanics: String
    let cadence: String
    let tags: [String]
    let openingMoveScore: Int
    let estimatedWinRate: Double
    let estimatedAverageStars: Double
    let warnings: [String]
}

enum LevelDesignReport {
    static func rows() -> [LevelDesignRow] {
        (1...Levels.count).map { level in
            let config = Levels.config(for: level)
            let snapshot = LevelBalanceAnalyzer.snapshot(for: config)
            return LevelDesignRow(level: level,
                                  chapter: Levels.chapter(for: level).title,
                                  difficulty: config.difficulty,
                                  goal: config.goal.title,
                                  moves: config.moves,
                                  target: config.target,
                                  mechanics: config.layout.mechanicSummary,
                                  cadence: cadence(for: config),
                                  tags: tags(for: config),
                                  openingMoveScore: snapshot.openingMoveScore,
                                  estimatedWinRate: LevelBalanceAnalyzer.estimatedWinRate(for: config),
                                  estimatedAverageStars: LevelBalanceAnalyzer.estimatedAverageStars(for: config),
                                  warnings: snapshot.warnings)
        }
    }

    static func levelsNeedingAttention() -> [LevelDesignRow] {
        rows().filter { !$0.warnings.isEmpty }
    }

    static func simulationRows(levelRange: ClosedRange<Int> = 1...Levels.count,
                               attemptsPerLevel: Int = 12) -> [LevelSimulationSummary] {
        LevelSimulationBot.simulate(levelRange: levelRange,
                                    attemptsPerLevel: attemptsPerLevel)
    }

    static func csv() -> String {
        let header = "level,chapter,difficulty,goal,moves,target,mechanics,cadence,tags,opening_move_score,estimated_win_rate,estimated_average_stars,warnings"
        let body = rows().map { row in
            [
                "\(row.level)",
                row.chapter,
                row.difficulty.rawValue,
                row.goal,
                "\(row.moves)",
                "\(row.target)",
                row.mechanics,
                row.cadence,
                row.tags.joined(separator: "|"),
                "\(row.openingMoveScore)",
                String(format: "%.2f", row.estimatedWinRate),
                String(format: "%.2f", row.estimatedAverageStars),
                row.warnings.joined(separator: "|")
            ].map(csvEscape).joined(separator: ",")
        }
        return ([header] + body).joined(separator: "\n")
    }

    private static func cadence(for config: LevelConfig) -> String {
        if config.number == 1 { return "Teach" }
        if Levels.mechanicUnlock(for: config.number) != nil { return "Teach" }
        if config.isBoss { return "Boss" }
        if config.number.isMultiple(of: 5) { return "Reward beat" }
        if config.difficulty == .normal, config.number > 1 {
            let previous = Levels.config(for: config.number - 1)
            if previous.difficulty == .hard || previous.difficulty == .superHard {
                return "Relief"
            }
        }
        if config.difficulty == .hard || config.difficulty == .superHard || config.difficulty == .crownChallenge {
            return "Pressure"
        }
        return "Practice"
    }

    private static func tags(for config: LevelConfig) -> [String] {
        var tags = [archetypeTag(config.archetype), goalTag(config.goal), config.difficulty.rawValue]
        if config.layout.iceCount > 0 { tags.append("Ice") }
        if config.layout.lockCount > 0 { tags.append("Locks") }
        if config.layout.jellyCount > 0 { tags.append("Jelly") }
        if config.layout.crateCount > 0 { tags.append("Crates") }
        if config.layout.colorLockCount > 0 { tags.append("Color locks") }
        if config.layout.startingBombs > 0 { tags.append("Seeded bombs") }
        if !config.layout.portalPairs.isEmpty { tags.append("Portals") }
        if !config.layout.conveyorBelts.isEmpty { tags.append("Conveyors") }
        if config.layout.chocolateCount > 0 { tags.append("Chocolate") }
        if config.layout.ingredientCount > 0 { tags.append("Ingredients") }
        if config.layout.keyCount > 0 { tags.append("Keys") }
        if config.layout.chestCount > 0 { tags.append("Chests") }
        if config.layout.vineCount > 0 { tags.append("Vines") }
        tags.append(contentsOf: config.modifiers.map(\.title))
        if config.isBoss { tags.append("Boss") }
        return tags
    }

    private static func archetypeTag(_ archetype: LevelArchetype) -> String {
        switch archetype {
        case .starter: return "Starter"
        case .combo: return "Combo"
        case .ice: return "Ice"
        case .lock: return "Lock"
        case .crowded: return "Crowded"
        case .bombRush: return "Bomb rush"
        case .finale: return "Finale"
        }
    }

    private static func goalTag(_ goal: LevelGoal) -> String {
        switch goal {
        case .score: return "Score"
        case .clearBlockers: return "Blocker clear"
        case .collectColor: return "Color collect"
        case .createSpecials: return "Special creation"
        case .detonateBombs: return "Bomb detonation"
        case .collectIngredients: return "Ingredient drop"
        case .collectKeys: return "Key drop"
        case .openChests: return "Chest open"
        case .collectIngredientsAndKeys: return "Mixed drops"
        }
    }

    nonisolated private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
