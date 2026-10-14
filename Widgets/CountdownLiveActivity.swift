import ActivityKit
import SwiftUI
import WidgetKit

struct CountdownLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CountdownActivityAttributes.self) { context in
            LockScreenActivityView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(context.attributes.theme.colors.last?.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let emoji = context.attributes.emoji ?? "⏳"
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(emoji).font(.largeTitle)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownTimerText(date: context.state.eventDate)
                        .font(.title2.bold())
                        .frame(maxWidth: 110)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.eventDate, format: .dateTime.weekday().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Text(emoji)
            } compactTrailing: {
                CountdownTimerText(date: context.state.eventDate)
                    .frame(maxWidth: 56)
                    .font(.caption.bold())
            } minimal: {
                Text(emoji)
            }
        }
    }
}

private struct LockScreenActivityView: View {
    let attributes: CountdownActivityAttributes
    let state: CountdownActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            Text(attributes.emoji ?? "⏳")
                .font(.system(size: 40))
            VStack(alignment: .leading, spacing: 2) {
                Text(attributes.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(state.eventDate, format: .dateTime.weekday(.wide).hour().minute())
                    .font(.caption)
                    .opacity(0.85)
            }
            Spacer()
            CountdownTimerText(date: state.eventDate)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .frame(maxWidth: 150, alignment: .trailing)
        }
        .foregroundStyle(.white)
        .padding(16)
    }
}

/// Counts down live without the app running; shows a party popper at zero.
private struct CountdownTimerText: View {
    let date: Date

    var body: some View {
        if date > .now {
            Text(timerInterval: Date.now...date, countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        } else {
            Text("🎉")
        }
    }
}
