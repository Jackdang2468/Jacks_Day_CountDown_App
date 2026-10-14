import Foundation

/// One event the user is counting down to. Shared by the app and the widgets.
struct Countdown: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var title: String
    var targetDate: Date
    var isAllDay: Bool
    var notes: String
    var theme: CountdownTheme
    var emoji: String?
    /// File name of the photo for this countdown, if any. A new key is minted
    /// every time the photo changes, so caches never serve a stale image.
    var imageKey: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        targetDate: Date,
        isAllDay: Bool = true,
        notes: String = "",
        theme: CountdownTheme = .ocean,
        emoji: String? = nil,
        imageKey: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.targetDate = targetDate
        self.isAllDay = isAllDay
        self.notes = notes
        self.theme = theme
        self.emoji = emoji
        self.imageKey = imageKey
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static let sample = Countdown(
        title: "Summer Vacation",
        targetDate: Calendar.current.date(byAdding: .day, value: 42, to: .now)!,
        theme: .sunset,
        emoji: "🏖️"
    )
}

extension Countdown {
    /// Whole calendar days from `now` until the event (negative once it has passed).
    func daysRemaining(from now: Date = .now, calendar: Calendar = .current) -> Int {
        DayMath.days(from: now, to: targetDate, calendar: calendar)
    }

    var isPast: Bool { daysRemaining() < 0 }
}

enum DayMath {
    static func days(from start: Date, to end: Date, calendar: Calendar = .current) -> Int {
        let a = calendar.startOfDay(for: start)
        let b = calendar.startOfDay(for: end)
        return calendar.dateComponents([.day], from: a, to: b).day ?? 0
    }

    /// "Today", "Tomorrow", "12 days", "3 days ago".
    static func phrase(for days: Int) -> String {
        switch days {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case -1: return "Yesterday"
        case let d where d > 1: return "\(d) days"
        default: return "\(-days) days ago"
        }
    }

    /// Short caption shown under the big number.
    static func caption(for days: Int) -> String {
        switch days {
        case 0: return "today"
        case 1: return "day to go"
        case let d where d > 1: return "days to go"
        case -1: return "day since"
        default: return "days since"
        }
    }
}
