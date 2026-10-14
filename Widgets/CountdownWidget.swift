import SwiftUI
import WidgetKit

struct CountdownEntry: TimelineEntry {
    let date: Date
    let countdown: Countdown?
}

struct CountdownProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CountdownEntry {
        CountdownEntry(date: .now, countdown: .sample)
    }

    func snapshot(for configuration: SelectCountdownIntent, in context: Context) async -> CountdownEntry {
        CountdownEntry(date: .now, countdown: resolve(configuration) ?? .sample)
    }

    func timeline(for configuration: SelectCountdownIntent, in context: Context) async -> Timeline<CountdownEntry> {
        let countdown = resolve(configuration)
        // One entry per midnight for the next two weeks, so the day count ticks
        // over on time even if the app is never opened.
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var entries = [CountdownEntry(date: .now, countdown: countdown)]
        for offset in 1...14 {
            if let day = calendar.date(byAdding: .day, value: offset, to: today) {
                entries.append(CountdownEntry(date: day, countdown: countdown))
            }
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    private func resolve(_ configuration: SelectCountdownIntent) -> Countdown? {
        let all = CountdownFile.load()
        if let id = configuration.countdown?.id, let match = all.first(where: { $0.id == id }) {
            return match
        }
        return CountdownPicker.featured(in: all)
    }
}

struct CountdownWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "CountdownWidget", intent: SelectCountdownIntent.self, provider: CountdownProvider()) { entry in
            CountdownWidgetView(entry: entry)
        }
        .configurationDisplayName("Countdown")
        .description("Days until your event, with its photo.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
        .contentMarginsDisabled()
    }
}

struct CountdownWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CountdownEntry

    var body: some View {
        if let countdown = entry.countdown {
            content(countdown, days: countdown.daysRemaining(from: entry.date))
        } else {
            empty
        }
    }

    @ViewBuilder
    private func content(_ c: Countdown, days: Int) -> some View {
        switch family {
        case .accessoryInline:
            Text("\(c.emoji.map { $0 + " " } ?? "")\(c.title): \(DayMath.phrase(for: days))")
                .containerBackground(.clear, for: .widget)

        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: -2) {
                    Text(days == 0 ? "🎉" : "\(abs(days))")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.5)
                    Text(days == 0 ? "today" : "days")
                        .font(.system(size: 9, weight: .semibold))
                        .textCase(.uppercase)
                }
                .padding(4)
            }
            .containerBackground(.clear, for: .widget)

        case .accessoryRectangular:
            HStack(spacing: 8) {
                if let key = c.imageKey, let image = ImageStore.image(for: key, maxPixel: 160) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else if let emoji = c.emoji {
                    Text(emoji).font(.title)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(c.title)
                        .font(.headline)
                        .widgetAccentable()
                        .lineLimit(1)
                    (Text(days == 0 ? "Today!" : "\(abs(days))")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                     + Text(days == 0 ? "" : " " + DayMath.caption(for: days))
                        .font(.caption))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .containerBackground(.clear, for: .widget)

        default:
            homeScreen(c, days: days)
                .containerBackground(for: .widget) {
                    CountdownBackground(countdown: c, maxPixel: family == .systemLarge ? 800 : 500)
                }
        }
    }

    private func homeScreen(_ c: Countdown, days: Int) -> some View {
        let big: CGFloat = family == .systemSmall ? 48 : 64
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let emoji = c.emoji { Text(emoji).font(family == .systemSmall ? .title2 : .title) }
                Spacer()
            }
            Spacer(minLength: 0)
            Text(days == 0 ? "🎉" : "\(abs(days))")
                .font(.system(size: big, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .contentTransition(.numericText())
            Text(DayMath.caption(for: days))
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .opacity(0.85)
            Text(c.title)
                .font(family == .systemSmall ? .subheadline.bold() : .headline)
                .lineLimit(family == .systemSmall ? 2 : 1)
            if family != .systemSmall {
                Text(c.nextDate(from: entry.date), format: .dateTime.weekday(.wide).month().day().year())
                    .font(.caption)
                    .opacity(0.85)
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.3), radius: 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(16)
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Image(systemName: "calendar.badge.plus")
                .font(.title2)
            if family != .accessoryCircular && family != .accessoryInline {
                Text("Add a countdown in the app")
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
        }
        .containerBackground(for: .widget) {
            CountdownTheme.ocean.gradient
        }
    }
}

#Preview(as: .systemSmall) {
    CountdownWidget()
} timeline: {
    CountdownEntry(date: .now, countdown: .sample)
}

#Preview(as: .accessoryRectangular) {
    CountdownWidget()
} timeline: {
    CountdownEntry(date: .now, countdown: .sample)
}
