import Foundation

/// App-Group-backed state shared between the app and the widget extension.
/// The app is the only writer; the widget reads. Plain UserDefaults values —
/// no Codable — so both targets stay trivially in sync.
nonisolated enum WidgetSharedState {

    static let appGroupID = "group.com.currenttech.SugarShift"

    private enum K {
        static let dateKey      = "ssw.daily.dateKey"
        static let number       = "ssw.daily.number"
        static let level        = "ssw.daily.level"
        static let claimed      = "ssw.daily.claimed"
        static let streak       = "ssw.daily.streak"
        static let lives        = "ssw.lives"
        static let livesMax     = "ssw.livesMax"
        static let nextLifeAt   = "ssw.nextLifeAt"
        static let regenSeconds = "ssw.regenSeconds"
    }

    struct Snapshot {
        let dateKey: String
        let number: Int
        let level: Int
        let claimed: Bool
        let streak: Int
        let lives: Int
        let livesMax: Int
        let nextLifeAt: Date?
        let regenSeconds: TimeInterval

        /// Whether the stored daily info still describes today's challenge.
        /// After local midnight the app may not have run yet — the widget then
        /// shows "new daily ready" instead of stale level details.
        func isCurrent(at now: Date = Date()) -> Bool {
            dateKey == WidgetSharedState.todayKey(at: now)
        }

        /// Lives regenerate on a wall-clock timer, so the widget can compute
        /// the current count long after the app last wrote the snapshot.
        func livesNow(at now: Date = Date()) -> Int {
            guard let next = nextLifeAt, lives < livesMax, regenSeconds > 0 else { return lives }
            guard now >= next else { return lives }
            let extra = 1 + Int(now.timeIntervalSince(next) / regenSeconds)
            return min(livesMax, lives + extra)
        }

        /// Dates at which a widget entry needs to advance the displayed life
        /// count. Entries stop at midnight because the daily challenge rolls
        /// over then and WidgetKit requests a fresh timeline.
        func regenerationDates(after now: Date, before limit: Date) -> [Date] {
            guard let first = nextLifeAt,
                  regenSeconds > 0,
                  livesNow(at: now) < livesMax else { return [] }

            let next: Date
            if now < first {
                next = first
            } else {
                let completedIntervals = floor(now.timeIntervalSince(first) / regenSeconds) + 1
                next = first.addingTimeInterval(completedIntervals * regenSeconds)
            }

            let missing = livesMax - livesNow(at: now)
            return (0..<missing).compactMap { offset in
                let date = next.addingTimeInterval(Double(offset) * regenSeconds)
                return date < limit ? date : nil
            }
        }
    }

    static func write(dateKey: String,
                      number: Int,
                      level: Int,
                      claimed: Bool,
                      streak: Int,
                      lives: Int,
                      livesMax: Int,
                      nextLifeAt: Date?,
                      regenSeconds: TimeInterval) {
        guard let d = UserDefaults(suiteName: appGroupID) else { return }
        d.set(dateKey, forKey: K.dateKey)
        d.set(number, forKey: K.number)
        d.set(level, forKey: K.level)
        d.set(claimed, forKey: K.claimed)
        d.set(streak, forKey: K.streak)
        d.set(lives, forKey: K.lives)
        d.set(livesMax, forKey: K.livesMax)
        d.set(regenSeconds, forKey: K.regenSeconds)
        if let nextLifeAt {
            d.set(nextLifeAt, forKey: K.nextLifeAt)
        } else {
            d.removeObject(forKey: K.nextLifeAt)
        }
    }

    static func read() -> Snapshot? {
        guard let d = UserDefaults(suiteName: appGroupID),
              let dateKey = d.string(forKey: K.dateKey) else { return nil }
        return Snapshot(dateKey: dateKey,
                        number: d.integer(forKey: K.number),
                        level: d.integer(forKey: K.level),
                        claimed: d.bool(forKey: K.claimed),
                        streak: d.integer(forKey: K.streak),
                        lives: d.integer(forKey: K.lives),
                        livesMax: max(1, d.integer(forKey: K.livesMax)),
                        nextLifeAt: d.object(forKey: K.nextLifeAt) as? Date,
                        regenSeconds: d.double(forKey: K.regenSeconds))
    }

    /// Mirrors the app's daily date key (Gregorian, POSIX digits, local
    /// midnight rollover) without pulling the level catalog into the widget.
    static func todayKey(at now: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: calendar.startOfDay(for: now))
    }

    static func nextMidnight(after now: Date = Date()) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let startOfDay = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now.addingTimeInterval(86_400)
    }
}
