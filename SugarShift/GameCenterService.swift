import Foundation
import GameKit
import UIKit

/// Wraps Game Center auth, leaderboard submission, and achievements.
///
/// Calls fail silently when the Game Center entitlement isn't enabled or the
/// user isn't signed in to iCloud — the rest of the game keeps working. To
/// light this up:
///
/// 1. Add the **Game Center** capability to the SugarShift target.
/// 2. Create the leaderboards/achievements in App Store Connect with the IDs
///    in `Leaderboard` / `Achievement` below.
/// 3. Build & run on a real device or simulator signed into a sandbox tester.
final class GameCenterService {

    static let shared = GameCenterService()

    enum Leaderboard: String {
        case totalScore  = "com.currenttech.SugarShift.lb.totalScore"
        case highestLevel = "com.currenttech.SugarShift.lb.highestLevel"
        case threeStarLevels = "com.currenttech.SugarShift.lb.threeStarLevels"
    }

    enum Achievement: String, CaseIterable {
        case firstClear = "com.currenttech.SugarShift.ach.firstClear"
        case crownReached = "com.currenttech.SugarShift.ach.crownReached"
        case finalCrown = "com.currenttech.SugarShift.ach.finalCrown"
        case sweetTooth100 = "com.currenttech.SugarShift.ach.sweetTooth100"
        case streak7 = "com.currenttech.SugarShift.ach.streak7"

        var threshold: Double {
            switch self {
            case .firstClear:    return 1
            case .crownReached:  return 100
            case .finalCrown:    return 200
            case .sweetTooth100: return 100
            case .streak7:       return 7
            }
        }
    }

    private(set) var isAuthenticated = false

    private init() {}

    /// Begins the Game Center sign-in flow. Safe to call repeatedly; Game Kit
    /// debounces the prompt internally.
    ///
    /// No-ops unless `Persistence.gameCenterOptIn` is true. Setting the
    /// `authenticateHandler` on a build without the Game Center entitlement
    /// produces a wall of "Could not load services for GameKit" errors in
    /// the device console, so we keep it dormant until the user explicitly
    /// asks to sign in (e.g., from Settings).
    func authenticate() {
        guard Persistence.gameCenterOptIn else { return }
        let local = GKLocalPlayer.local
        local.authenticateHandler = { [weak self] viewController, error in
            if let viewController {
                self?.present(viewController)
            }
            if let error {
                Analytics.track("gamecenter_auth_failed",
                                properties: ["error": "\(error)"])
            }
            self?.isAuthenticated = local.isAuthenticated
            if local.isAuthenticated {
                Analytics.track("gamecenter_authenticated")
            }
        }
    }

    func submitCampaignProgress(totalScore: Int,
                                highestLevel: Int,
                                threeStarLevels: Int,
                                dailyStreak: Int) {
        submitTotalScore(totalScore)
        submitHighestLevel(highestLevel)
        submitThreeStarLevels(threeStarLevels)
        reportAchievementProgress(.firstClear, value: highestLevel > 1 ? 1 : 0)
        reportAchievementProgress(.crownReached, value: Double(highestLevel))
        reportAchievementProgress(.finalCrown, value: Double(highestLevel))
        reportAchievementProgress(.sweetTooth100, value: Double(threeStarLevels))
        reportAchievementProgress(.streak7, value: Double(dailyStreak))
    }

    func submitTotalScore(_ score: Int) {
        report(score, to: .totalScore)
    }

    func submitHighestLevel(_ level: Int) {
        report(level, to: .highestLevel)
    }

    func submitThreeStarLevels(_ count: Int) {
        report(count, to: .threeStarLevels)
    }

    /// Updates achievement progress (0…100) and reports to Game Center.
    func reportAchievementProgress(_ achievement: Achievement, value: Double) {
        guard isAuthenticated else { return }
        let percent = max(0, min(100, value / achievement.threshold * 100))
        let report = GKAchievement(identifier: achievement.rawValue)
        report.percentComplete = percent
        report.showsCompletionBanner = true
        GKAchievement.report([report]) { error in
            if let error {
                Analytics.track("gamecenter_achievement_failed",
                                properties: ["id": achievement.rawValue,
                                             "error": "\(error)"])
            }
        }
    }

    private func report(_ value: Int, to leaderboard: Leaderboard) {
        guard isAuthenticated else { return }
        GKLeaderboard.submitScore(value,
                                  context: 0,
                                  player: GKLocalPlayer.local,
                                  leaderboardIDs: [leaderboard.rawValue]) { error in
            if let error {
                Analytics.track("gamecenter_score_failed",
                                properties: ["board": leaderboard.rawValue,
                                             "error": "\(error)"])
            }
        }
    }

    private func present(_ viewController: UIViewController) {
        guard let presenter = topViewController() else { return }
        presenter.present(viewController, animated: true)
    }

    private func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let keyWindow = scenes.flatMap(\.windows).first { $0.isKeyWindow }
        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        if let nav = top as? UINavigationController {
            return nav.visibleViewController
        }
        if let tab = top as? UITabBarController {
            return tab.selectedViewController
        }
        return top
    }
}
