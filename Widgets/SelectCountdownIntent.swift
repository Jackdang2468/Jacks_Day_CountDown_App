import AppIntents
import WidgetKit

/// Lets the user pick which countdown a widget shows (long-press > Edit Widget).
struct SelectCountdownIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose Countdown"
    static var description = IntentDescription("Pick the event this widget counts down to.")

    @Parameter(title: "Countdown")
    var countdown: CountdownEntity?
}

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

struct CountdownQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [CountdownEntity] {
        CountdownFile.load().filter { identifiers.contains($0.id) }.map(CountdownEntity.init)
    }

    func suggestedEntities() async throws -> [CountdownEntity] {
        CountdownFile.load().map(CountdownEntity.init)
    }

    func defaultResult() async -> CountdownEntity? {
        CountdownFile.load().first { !$0.isPast }.map(CountdownEntity.init)
    }
}
