import AppIntents
import WidgetKit

/// Lets the user pick which countdown a widget shows (long-press > Edit Widget).
struct SelectCountdownIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose Countdown"
    static var description = IntentDescription("Pick the event this widget counts down to.")

    @Parameter(title: "Countdown")
    var countdown: CountdownEntity?
}
