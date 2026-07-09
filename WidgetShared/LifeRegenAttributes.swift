import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// Live Activity payload for the life-regen timer. Compiled into both the app
/// (which starts/updates the activity) and the widget extension (which renders
/// it on the lock screen and in the Dynamic Island).
@available(iOS 16.1, *)
nonisolated struct LifeRegenAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        /// Lives the player has right now.
        var lives: Int
        /// When the next life lands. Nil only when the bar is already full.
        var nextLifeAt: Date?
        /// When the bar is completely refilled.
        var fullAt: Date?
        /// Wall-clock duration between regenerated lives.
        var regenSeconds: TimeInterval

        func lives(at now: Date, maximum: Int) -> Int {
            guard let nextLifeAt,
                  lives < maximum,
                  regenSeconds > 0 else { return min(maximum, lives) }
            guard now >= nextLifeAt else { return lives }
            let regenerated = 1 + Int(now.timeIntervalSince(nextLifeAt) / regenSeconds)
            return min(maximum, lives + regenerated)
        }

        func nextLife(after now: Date, maximum: Int) -> Date? {
            guard lives(at: now, maximum: maximum) < maximum,
                  let nextLifeAt,
                  regenSeconds > 0 else { return nil }
            guard now >= nextLifeAt else { return nextLifeAt }
            let completedIntervals = floor(now.timeIntervalSince(nextLifeAt) / regenSeconds) + 1
            return nextLifeAt.addingTimeInterval(completedIntervals * regenSeconds)
        }
    }

    var livesMax: Int
}
#endif
