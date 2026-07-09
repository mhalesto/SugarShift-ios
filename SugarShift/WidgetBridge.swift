import Foundation
import WidgetKit
#if canImport(ActivityKit)
import ActivityKit
#endif

/// One-way bridge from game state to the widget extension: snapshots the
/// daily-challenge + lives state into the shared App Group and manages the
/// life-regen Live Activity. Cheap to call — fire it on any state change that
/// a widget surface displays.
enum WidgetBridge {

    static func syncSharedState() {
        let daily = Levels.dailyChallenge()
        WidgetSharedState.write(dateKey: daily.dateKey,
                                number: daily.number,
                                level: daily.level,
                                claimed: Persistence.hasClaimedDailyReward(daily.dateKey),
                                streak: Persistence.dailyStreak,
                                lives: Persistence.lives,
                                livesMax: Economy.livesMax,
                                nextLifeAt: Persistence.nextLifeAt,
                                regenSeconds: Economy.lifeRegenInterval)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Starts/updates the Dynamic Island life timer when lives are missing and
    /// ends it once the bar is full. Call when the app is about to leave the
    /// foreground (activities can only be *started* while foregrounded).
    static func refreshLifeActivity() {
        #if canImport(ActivityKit)
        // ActivityContent-based request/update/end need 16.2 (16.1 only had
        // the deprecated contentState variants).
        guard #available(iOS 16.2, *) else { return }
        let lives = Persistence.lives
        let nextLifeAt = Persistence.nextLifeAt
        let missing = max(0, Economy.livesMax - lives)
        let fullAt = nextLifeAt.map { $0.addingTimeInterval(Double(max(0, missing - 1)) * Economy.lifeRegenInterval) }

        let state = LifeRegenAttributes.ContentState(lives: lives,
                                                     nextLifeAt: nextLifeAt,
                                                     fullAt: fullAt,
                                                     regenSeconds: Economy.lifeRegenInterval)
        let existing = Activity<LifeRegenAttributes>.activities

        guard missing > 0, nextLifeAt != nil else {
            for activity in existing {
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
            }
            return
        }

        if let activity = existing.first {
            Task { await activity.update(ActivityContent(state: state, staleDate: fullAt)) }
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            do {
                _ = try Activity.request(attributes: LifeRegenAttributes(livesMax: Economy.livesMax),
                                         content: ActivityContent(state: state, staleDate: fullAt))
                Analytics.track("life_activity_started",
                                properties: ["lives": "\(lives)"])
            } catch {
                Analytics.track("life_activity_failed",
                                properties: ["error": "\(error)"])
            }
        }
        #endif
    }
}
