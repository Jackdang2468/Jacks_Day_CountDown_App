import AppIntents
import Foundation

/// "Hey Siri, how many days until Vacation in Day Counter?"
struct DaysUntilIntent: AppIntent {
    static var title: LocalizedStringResource = "Days Until Countdown"
    static var description = IntentDescription("Tells you how many days are left until one of your countdowns.")

    @Parameter(title: "Countdown")
    var countdown: CountdownEntity?

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let all = CountdownFile.load()
        let chosen = countdown.flatMap { entity in all.first { $0.id == entity.id } }
        guard let item = chosen ?? CountdownPicker.featured(in: all) else {
            return .result(value: 0, dialog: "You don't have any countdowns yet.")
        }
        let days = item.daysRemaining()
        let text: String
        switch days {
        case 0: text = "\(item.title) is today!"
        case 1: text = "\(item.title) is tomorrow."
        case let d where d > 1: text = "\(d) days until \(item.title)."
        default: text = "\(item.title) was \(-days) days ago."
        }
        return .result(value: days, dialog: "\(text)")
    }
}

struct DayCounterShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: DaysUntilIntent(),
            phrases: [
                "How many days until \(\.$countdown) in \(.applicationName)",
                "Days until \(\.$countdown) in \(.applicationName)",
                "How long until my next \(.applicationName) event",
                "What's next in \(.applicationName)",
            ],
            shortTitle: "Days Until",
            systemImageName: "calendar.badge.clock"
        )
    }
}
