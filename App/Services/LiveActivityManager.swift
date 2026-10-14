import ActivityKit
import Foundation

/// Starts a Live Activity in the final hours before an event. Runs locally;
/// no push server is involved.
enum LiveActivityManager {
    /// iOS keeps a Live Activity running for up to 8 hours.
    static let window: TimeInterval = 8 * 60 * 60

    static var autoStart: Bool {
        get { UserDefaults.standard.object(forKey: "liveActivity.auto") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "liveActivity.auto") }
    }

    static var areEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    static func isRunning(_ id: UUID) -> Bool {
        Activity<CountdownActivityAttributes>.activities.contains { $0.attributes.countdownID == id }
    }

    /// Whether the event is close enough for a Live Activity.
    static func isEligible(_ countdown: Countdown, now: Date = .now) -> Bool {
        let remaining = countdown.eventStart(from: now).timeIntervalSince(now)
        return remaining > 0 && remaining <= window
    }

    static func start(_ countdown: Countdown) throws {
        guard areEnabled, !isRunning(countdown.id) else { return }
        let end = countdown.eventStart()
        let attributes = CountdownActivityAttributes(
            countdownID: countdown.id,
            title: countdown.title,
            emoji: countdown.emoji,
            themeRaw: countdown.theme.rawValue
        )
        let content = ActivityContent(
            state: CountdownActivityAttributes.ContentState(eventDate: end),
            staleDate: end.addingTimeInterval(60 * 60)
        )
        _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
    }

    static func stop(_ id: UUID) async {
        for activity in Activity<CountdownActivityAttributes>.activities where activity.attributes.countdownID == id {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Ends finished or deleted activities and, if enabled, starts new ones.
    static func refresh(_ countdowns: [Countdown]) async {
        let now = Date.now
        for activity in Activity<CountdownActivityAttributes>.activities {
            let match = countdowns.first { $0.id == activity.attributes.countdownID }
            let ended = activity.content.state.eventDate.addingTimeInterval(60 * 60) < now
            if match == nil || ended {
                await activity.end(nil, dismissalPolicy: .default)
            } else if let match, match.eventStart(from: now) != activity.content.state.eventDate {
                let state = CountdownActivityAttributes.ContentState(eventDate: match.eventStart(from: now))
                await activity.update(ActivityContent(state: state, staleDate: state.eventDate.addingTimeInterval(3600)))
            }
        }
        guard autoStart else { return }
        for countdown in countdowns where isEligible(countdown, now: now) {
            try? start(countdown)
        }
    }
}
