import Foundation
import UserNotifications

/// Local reminder notifications: 1 week before, 1 day before, and the day of.
/// Scheduled on the phone, so there is no push server and no cost.
enum ReminderScheduler {
    private static let prefix = "countdown."
    /// iOS keeps at most 64 pending local notifications per app.
    private static let limit = 60

    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "reminders.enabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "reminders.enabled") }
    }

    /// Hour of day for all-day event reminders (default 9 AM).
    static var hour: Int {
        get { UserDefaults.standard.object(forKey: "reminders.hour") as? Int ?? 9 }
        set { UserDefaults.standard.set(newValue, forKey: "reminders.hour") }
    }

    @discardableResult
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Replaces every reminder this app scheduled with a fresh set.
    static func reschedule(_ countdowns: [Countdown]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })

        guard isEnabled else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let now = Date.now
        let calendar = Calendar.current
        var requests: [(Date, UNNotificationRequest)] = []

        for countdown in countdowns where countdown.remindersEnabled {
            let start = countdown.eventStart(from: now)
            let stops: [(days: Int, body: String)] = [
                (7, "1 week to go"),
                (1, "Tomorrow!"),
                (0, countdown.isAllDay ? "It's today! 🎉" : "It's time! 🎉"),
            ]
            for stop in stops {
                guard var fire = calendar.date(byAdding: .day, value: -stop.days, to: start) else { continue }
                if countdown.isAllDay {
                    fire = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: fire) ?? fire
                }
                guard fire > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = [countdown.emoji, countdown.title].compactMap { $0 }.joined(separator: " ")
                content.body = stop.body
                content.sound = .default
                content.userInfo = ["countdownID": countdown.id.uuidString]

                let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
                let id = "\(prefix)\(countdown.id.uuidString).\(stop.days)"
                requests.append((fire, UNNotificationRequest(identifier: id, content: content, trigger: trigger)))
            }
        }

        for (_, request) in requests.sorted(by: { $0.0 < $1.0 }).prefix(limit) {
            try? await center.add(request)
        }
    }
}
