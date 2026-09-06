import Foundation

/// Builds the Wordle-style share text for the daily challenge. The emoji grid
/// is the board's *starting* state — identical for every player that day — so
/// sharing it spoils nothing and doubles as an invitation to play the same
/// puzzle.
enum DailyShare {

    static func shareText(challenge: DailyChallenge,
                          stars: Int,
                          score: Int,
                          movesToSpare: Int,
                          startGrid: Grid) -> String {
        var lines: [String] = []
        lines.append(String(localized: "SugarShift Daily #\(challenge.number) — \(challenge.dateKey)"))

        let starText = String(repeating: "⭐", count: max(0, min(3, stars)))
        let scoreText = formattedScore(score)
        if movesToSpare > 0 {
            lines.append(String(localized: "\(starText) \(scoreText) pts · \(movesToSpare) moves to spare"))
        } else {
            lines.append(String(localized: "\(starText) \(scoreText) pts"))
        }
        lines.append("")

        let grid = emojiGrid(for: startGrid)
        if !grid.isEmpty {
            lines.append(grid)
            lines.append("")
        }

        lines.append(String(localized: "Same board for everyone — can you beat it?"))
        return lines.joined(separator: "\n")
    }

    /// One emoji per cell, rows joined by newlines. Blockers and seeded
    /// specials override the fruit so the hazards read at a glance.
    static func emojiGrid(for grid: Grid) -> String {
        guard !grid.isEmpty else { return "" }
        var rows: [String] = []
        for row in grid {
            var line = ""
            for cell in row {
                line += emoji(for: cell)
            }
            rows.append(line)
        }
        return rows.joined(separator: "\n")
    }

    private static func emoji(for cell: Cell?) -> String {
        guard let cell else { return "⬜" }
        if let blocker = cell.blocker {
            switch blocker.type {
            case .ice:       return "🧊"
            case .lock:      return "🔒"
            case .jelly:     return "🍮"
            case .crate:     return "📦"
            case .colorLock: return "🔐"
            case .chest:     return "🎁"
            case .vine:      return "🌿"
            case .chocolate: return "🍫"
            case .syrup:     return "🍯"
            case .countdown: return "⏰"
            case .honey: return "🍯"
            case .stone, .solidX: return "🪨"
            case .cage: return "🔒"
            case .licorice: return "◼️"
            case .cream: return "🧁"
            case .bubble: return "🫧"
            case .magicFrost: return "❄️"
            case .donut: return "🍩"
            }
        }
        switch cell.kind {
        case .ingredient: return "🧺"
        case .key:        return "🗝️"
        case .normal:     break
        }
        if cell.special != nil { return "💣" }
        return Theme.emoji(forColor: cell.color)
    }

    private static func formattedScore(_ score: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: score)) ?? "\(score)"
    }
}
