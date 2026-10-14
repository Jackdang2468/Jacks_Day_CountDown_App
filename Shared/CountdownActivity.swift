import ActivityKit
import Foundation

/// Live Activity shown on the Lock Screen and Dynamic Island in the final hours.
struct CountdownActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var eventDate: Date
    }

    var countdownID: UUID
    var title: String
    var emoji: String?
    var themeRaw: String

    var theme: CountdownTheme { CountdownTheme(rawValue: themeRaw) ?? .ocean }
}
