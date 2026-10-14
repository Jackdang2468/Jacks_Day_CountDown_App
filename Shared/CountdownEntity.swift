import AppIntents
import Foundation

/// A countdown as Siri, Shortcuts, and widget configuration see it.
struct CountdownEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Countdown"
    static var defaultQuery = CountdownQuery()

    var id: UUID
    var title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }

    init(_ countdown: Countdown) {
        id = countdown.id
        title = countdown.title
    }
}

struct CountdownQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [CountdownEntity] {
        CountdownFile.load().filter { identifiers.contains($0.id) }.map(CountdownEntity.init)
    }

    func entities(matching string: String) async throws -> [CountdownEntity] {
        CountdownFile.load()
            .filter { $0.title.localizedCaseInsensitiveContains(string) }
            .map(CountdownEntity.init)
    }

    func suggestedEntities() async throws -> [CountdownEntity] {
        CountdownFile.load().map(CountdownEntity.init)
    }

    func defaultResult() async -> CountdownEntity? {
        CountdownPicker.featured(in: CountdownFile.load()).map(CountdownEntity.init)
    }
}

enum CountdownPicker {
    /// The countdown to show when none was chosen: a pinned one first, then
    /// the soonest upcoming one.
    static func featured(in all: [Countdown], now: Date = .now) -> Countdown? {
        let upcoming = all.filter { $0.daysRemaining(from: now) >= 0 }
            .sorted { $0.nextDate(from: now) < $1.nextDate(from: now) }
        return upcoming.first(where: \.isPinned) ?? upcoming.first ?? all.first
    }
}
