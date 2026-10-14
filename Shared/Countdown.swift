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
    /// Birthdays/anniversaries: counts down to the next occurrence each year.
    var repeatsYearly: Bool
    var isPinned: Bool
    var remindersEnabled: Bool
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
        repeatsYearly: Bool = false,
        isPinned: Bool = false,
        remindersEnabled: Bool = true,
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
        self.repeatsYearly = repeatsYearly
        self.isPinned = isPinned
        self.remindersEnabled = remindersEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // Tolerant decoding so caches written by older versions still load.
    private enum CodingKeys: String, CodingKey {
        case id, title, targetDate, isAllDay, notes, theme, emoji, imageKey
        case repeatsYearly, isPinned, remindersEnabled, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        targetDate = try c.decode(Date.self, forKey: .targetDate)
        isAllDay = try c.decodeIfPresent(Bool.self, forKey: .isAllDay) ?? true
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        theme = (try? c.decode(CountdownTheme.self, forKey: .theme)) ?? .ocean
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji)
        imageKey = try c.decodeIfPresent(String.self, forKey: .imageKey)
        repeatsYearly = try c.decodeIfPresent(Bool.self, forKey: .repeatsYearly) ?? false
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        remindersEnabled = try c.decodeIfPresent(Bool.self, forKey: .remindersEnabled) ?? true
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now
    }

    static let sample = Countdown(
        title: "Summer Vacation",
        targetDate: Calendar.current.date(byAdding: .day, value: 42, to: .now)!,
        theme: .sunset,
        emoji: "🏖️"
    )
}

extension Countdown {
    /// The date being counted down to. For yearly events this is the next
    /// anniversary on or after today; otherwise it is `targetDate`.
    func nextDate(from now: Date = .now, calendar: Calendar = .current) -> Date {
        guard repeatsYearly else { return targetDate }
        let parts = calendar.dateComponents([.month, .day, .hour, .minute], from: targetDate)
        let today = calendar.startOfDay(for: now)
        var year = calendar.component(.year, from: now)
        while true {
            var c = parts
            c.year = year
            // Feb 29 falls back to Feb 28 in non-leap years.
            let date = calendar.date(from: c) ?? calendar.date(from: DateComponents(year: year, month: 2, day: 28))!
            if calendar.startOfDay(for: date) >= today { return date }
            year += 1
        }
    }

    /// Whole calendar days from `now` until the event (negative once it has passed).
    func daysRemaining(from now: Date = .now, calendar: Calendar = .current) -> Int {
        DayMath.days(from: now, to: nextDate(from: now, calendar: calendar), calendar: calendar)
    }

    /// The exact moment the countdown reaches zero (midnight for all-day events).
    func eventStart(from now: Date = .now) -> Date {
        let date = nextDate(from: now)
        return isAllDay ? Calendar.current.startOfDay(for: date) : date
    }

    /// Which anniversary is coming up, e.g. 30 for a 30th birthday.
    func upcomingAnniversary(from now: Date = .now) -> Int? {
        guard repeatsYearly else { return nil }
        let years = Calendar.current.dateComponents([.year], from: targetDate, to: nextDate(from: now)).year ?? 0
        return years > 0 ? years : nil
    }

    var isPast: Bool { daysRemaining() < 0 }
}

extension Int {
    /// 1st, 2nd, 3rd, 4th...
    var ordinal: String {
        let f = NumberFormatter()
        f.numberStyle = .ordinal
        return f.string(from: NSNumber(value: self)) ?? "\(self)"
    }
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
