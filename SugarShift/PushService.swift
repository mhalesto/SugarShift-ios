import Foundation
import UserNotifications

/// Schedules local notifications for life refill, daily challenge reset, and
/// returning-player nudges.
///
/// All methods are safe to call without a Push Notifications entitlement —
/// these are *local* notifications only, but production should still:
///
/// 1. Add the "Push Notifications" capability if remote pushes are added later.
/// 2. Verify the user-facing copy with localization.
final class PushService {

    static let shared = PushService()

    private let center = UNUserNotificationCenter.current()
    private let lifeRegenIdentifier = "ss.notify.lifeRegen"
    private let dailyResetIdentifier = "ss.notify.dailyReset"

    private init() {}

    /// Asks the user for notification permission once. We track that we've
    /// asked so we never re-prompt; iOS shows the system "Settings" path if
    /// the player wants to flip it on later.
    func requestAuthorizationIfNeeded(_ completion: ((Bool) -> Void)? = nil) {
        if UserDefaults.standard.bool(forKey: Persistence.K.pushAuthAsked) {
            getStatus { completion?($0 == .authorized) }
            return
        }
        UserDefaults.standard.set(true, forKey: Persistence.K.pushAuthAsked)
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error {
                Analytics.track("push_auth_failed", properties: ["error": "\(error)"])
            }
            Analytics.track("push_auth_decided",
                            properties: ["granted": granted ? "true" : "false"])
            completion?(granted)
        }
    }

    /// Schedule a "Your hearts are full!" reminder for the moment lives reach
    /// max. We re-derive this each time lives change so the trigger is always
    /// correct. Cancels prior scheduling first.
    func scheduleLifeRegenNotificationIfNeeded() {
        center.removePendingNotificationRequests(withIdentifiers: [lifeRegenIdentifier])
        let livesNow = Persistence.lives
        guard livesNow < Economy.livesMax else { return }
        let missing = Economy.livesMax - livesNow
        let secondsUntilFull = Persistence.secondsUntilNextLife
            + Double(max(0, missing - 1)) * Economy.lifeRegenInterval
        guard secondsUntilFull >= 60 else { return }

        ensureAuthorizationForReminder { [weak self] allowed in
            guard allowed, let self else { return }
            self.center.removePendingNotificationRequests(withIdentifiers: [self.lifeRegenIdentifier])

            let content = UNMutableNotificationContent()
            content.title = "Sweet — your hearts are full"
            content.body = "Tap to play. Your next match is waiting."
            content.sound = .default
            content.badge = NSNumber(value: missing)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: secondsUntilFull,
                                                             repeats: false)
            let request = UNNotificationRequest(identifier: self.lifeRegenIdentifier,
                                                content: content,
                                                trigger: trigger)
            self.center.add(request) { error in
                if let error {
                    Analytics.track("push_schedule_failed",
                                    properties: ["id": self.lifeRegenIdentifier,
                                                 "error": "\(error)"])
                }
            }
        }
    }

    /// Daily reminder at 10 AM local time so the new daily challenge is ready
    /// when the player checks back in. Re-installs the same trigger; iOS keeps
    /// the next pending one.
    func scheduleDailyChallengeReminder() {
        ensureAuthorizationForReminder { [weak self] allowed in
            guard allowed, let self else { return }
            self.center.removePendingNotificationRequests(withIdentifiers: [self.dailyResetIdentifier])
            var dateComponents = DateComponents()
            dateComponents.hour = 10
            dateComponents.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents,
                                                         repeats: true)
            let content = UNMutableNotificationContent()
            content.title = "Today's Daily Challenge is ready"
            content.body = "Clear it for a streak bonus."
            content.sound = .default
            let request = UNNotificationRequest(identifier: self.dailyResetIdentifier,
                                                content: content,
                                                trigger: trigger)
            self.center.add(request, withCompletionHandler: nil)
        }
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    private func getStatus(_ completion: @escaping (UNAuthorizationStatus) -> Void) {
        center.getNotificationSettings { settings in
            completion(settings.authorizationStatus)
        }
    }

    private func ensureAuthorizationForReminder(_ completion: @escaping (Bool) -> Void) {
        getStatus { [weak self] status in
            switch status {
            case .authorized, .provisional, .ephemeral:
                completion(true)
            case .notDetermined:
                self?.requestAuthorizationIfNeeded(completion)
            case .denied:
                completion(false)
            @unknown default:
                completion(false)
            }
        }
    }
}
