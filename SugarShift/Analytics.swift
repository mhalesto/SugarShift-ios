import Foundation

enum Analytics {
    private static let key = "ss.analytics.events"
    private static let levelStatsKey = "ss.analytics.levelStats"
    private static let maxEvents = 250

    static func track(_ name: String, properties: [String: String] = [:]) {
        var record = properties
        record["event"] = name
        record["time"] = ISO8601DateFormatter().string(from: Date())

        var events = UserDefaults.standard.array(forKey: key) as? [[String: String]] ?? []
        events.append(record)
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
        UserDefaults.standard.set(events, forKey: key)
        updateLevelStats(for: name, properties: properties)

        #if DEBUG
        print("[Analytics] \(name) \(properties)")
        #endif
    }

    static func recentEvents() -> [[String: String]] {
        UserDefaults.standard.array(forKey: key) as? [[String: String]] ?? []
    }

    static func levelStats(for level: Int) -> [String: Int] {
        let all = allLevelStats()
        return all["\(level)"] ?? [:]
    }

    static func resetLevelStats() {
        UserDefaults.standard.removeObject(forKey: levelStatsKey)
    }

    private static func updateLevelStats(for event: String, properties: [String: String]) {
        guard let levelText = properties["level"], Int(levelText) != nil else { return }

        var all = allLevelStats()
        var stats = all[levelText] ?? [:]

        func add(_ key: String, _ value: Int = 1) {
            stats[key, default: 0] += value
        }

        switch event {
        case "level_start":
            add("attempts")
        case "level_win":
            add("wins")
            add("stars_total", Int(properties["stars"] ?? "0") ?? 0)
            add("moves_left_total", Int(properties["moves_left"] ?? "0") ?? 0)
            add("score_total", Int(properties["score"] ?? "0") ?? 0)
        case "level_fail":
            add("fails")
            let score = Int(properties["score"] ?? "0") ?? 0
            let target = Int(properties["target"] ?? "0") ?? 0
            add("fail_score_gap_total", max(0, target - score))
            add("score_total", score)
        case "booster_use":
            add("booster_uses")
        default:
            break
        }

        all[levelText] = stats
        UserDefaults.standard.set(all, forKey: levelStatsKey)
    }

    private static func allLevelStats() -> [String: [String: Int]] {
        let raw = UserDefaults.standard.dictionary(forKey: levelStatsKey) ?? [:]
        var out: [String: [String: Int]] = [:]
        for (level, value) in raw {
            if let stats = value as? [String: Int] {
                out[level] = stats
            } else if let stats = value as? [String: NSNumber] {
                out[level] = stats.mapValues { $0.intValue }
            }
        }
        return out
    }
}
