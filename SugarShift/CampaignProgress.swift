import Foundation

struct CampaignLevelRecord: Codable, Equatable {
    var bestScore = 0
    var attempts = 0
    var completedAt: Date?
}

/// Supplemental local data. The existing stars, current-level, economy and
/// cloud snapshot formats remain intact. These records do not yet cloud-sync.
enum CampaignProgress {
    static let storageKey = "ss.campaign.records.v1"

    static func record(for level: Int, defaults: UserDefaults = .standard) -> CampaignLevelRecord {
        records(defaults)[String(level)] ?? CampaignLevelRecord()
    }

    static func recordStart(level: Int, defaults: UserDefaults = .standard) {
        update(level: level, defaults: defaults) { $0.attempts += 1 }
    }

    static func recordResult(level: Int, score: Int, won: Bool,
                             at date: Date = Date(), defaults: UserDefaults = .standard) {
        update(level: level, defaults: defaults) {
            $0.bestScore = max($0.bestScore, score)
            if won { $0.completedAt = min($0.completedAt ?? date, date) }
        }
    }

    static func recordAttempt(level: Int, score: Int, defaults: UserDefaults = .standard) {
        recordStart(level: level, defaults: defaults)
        recordResult(level: level, score: score, won: false, defaults: defaults)
    }

    static func recordCompletion(level: Int, score: Int, at date: Date = Date(),
                                  defaults: UserDefaults = .standard) {
        recordStart(level: level, defaults: defaults)
        recordResult(level: level, score: score, won: true, at: date, defaults: defaults)
    }

    static func isCompleted(level: Int, defaults: UserDefaults = .standard,
                            legacyStars: (Int) -> Int = { Persistence.starsForLevel($0) }) -> Bool {
        record(for: level, defaults: defaults).completedAt != nil || legacyStars(level) > 0
    }

    static func highestUnlockedLevel(currentLevel: Int, levelCount: Int = Levels.count,
                                      defaults: UserDefaults = .standard,
                                      legacyStars: (Int) -> Int = { Persistence.starsForLevel($0) }) -> Int {
        guard levelCount > 0 else { return 1 }
        let saved = records(defaults)
        let completed = (1...levelCount).last {
            saved[String($0)]?.completedAt != nil || legacyStars($0) > 0
        } ?? 0
        return min(levelCount, max(1, currentLevel, completed + 1))
    }

    private static func records(_ defaults: UserDefaults) -> [String: CampaignLevelRecord] {
        guard let data = defaults.data(forKey: storageKey),
              let records = try? JSONDecoder().decode([String: CampaignLevelRecord].self, from: data) else { return [:] }
        return records
    }

    private static func update(level: Int, defaults: UserDefaults,
                                mutation: (inout CampaignLevelRecord) -> Void) {
        guard (1...Levels.count).contains(level) else { return }
        var saved = records(defaults)
        var record = saved[String(level)] ?? CampaignLevelRecord()
        mutation(&record)
        saved[String(level)] = record
        if let data = try? JSONEncoder().encode(saved) { defaults.set(data, forKey: storageKey) }
    }
}
