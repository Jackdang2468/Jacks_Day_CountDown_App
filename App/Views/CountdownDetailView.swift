import SwiftUI

struct CountdownDetailView: View {
    let countdownID: Countdown.ID
    @Environment(CountdownStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var showCalendar = false
    @State private var calendarAdded = false
    @State private var confirmDelete = false

    private var countdown: Countdown? { store.countdowns.first { $0.id == countdownID } }

    var body: some View {
        if let countdown {
            content(countdown)
        } else {
            ContentUnavailableView("Countdown removed", systemImage: "calendar.badge.minus")
        }
    }

    private func content(_ countdown: Countdown) -> some View {
        ZStack {
            CountdownBackground(countdown: countdown)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                if let emoji = countdown.emoji, !emoji.isEmpty {
                    Text(emoji).font(.system(size: 64))
                }
                Text(countdown.title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text(countdown.targetDate, format: countdown.isAllDay
                     ? .dateTime.weekday(.wide).month(.wide).day().year()
                     : .dateTime.weekday(.wide).month(.wide).day().year().hour().minute())
                    .font(.headline)
                    .opacity(0.85)

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    LiveCountdown(target: countdown.isAllDay
                                  ? Calendar.current.startOfDay(for: countdown.targetDate)
                                  : countdown.targetDate,
                                  now: context.date)
                }
                .padding(.vertical, 8)

                if calendarAdded {
                    Label("Added to your calendar", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                Spacer()

                HStack(spacing: 12) {
                    Button {
                        showCalendar = true
                    } label: {
                        Label("Add to Calendar", systemImage: "calendar.badge.plus")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    if let ics = ICSFile.make(for: countdown) {
                        ShareLink(item: ics) {
                            Label("Share .ics", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(.white)
            }
            .foregroundStyle(.white)
            .padding(24)
            .shadow(color: .black.opacity(0.25), radius: 6)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Menu {
                Button("Edit", systemImage: "pencil") { isEditing = true }
                Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .sheet(isPresented: $isEditing) {
            CountdownEditorView(original: countdown)
        }
        .sheet(isPresented: $showCalendar) {
            AddToCalendarSheet(countdown: countdown) { saved in
                showCalendar = false
                calendarAdded = saved
            }
            .ignoresSafeArea()
        }
        .confirmationDialog("Delete \"\(countdown.title)\"?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                store.delete(countdown)
                dismiss()
            }
        }
    }
}

private struct LiveCountdown: View {
    let target: Date
    let now: Date

    var body: some View {
        let seconds = max(0, Int(target.timeIntervalSince(now)))
        let parts = [
            (seconds / 86_400, "days"),
            ((seconds % 86_400) / 3_600, "hours"),
            ((seconds % 3_600) / 60, "min"),
            (seconds % 60, "sec"),
        ]
        HStack(spacing: 10) {
            ForEach(parts.indices, id: \.self) { index in
                let (value, label) = parts[index]
                VStack(spacing: 2) {
                    Text("\(value)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                    Text(label)
                        .font(.caption2.weight(.semibold))
                        .textCase(.uppercase)
                        .opacity(0.8)
                }
                .frame(width: 72, height: 78)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .animation(.default, value: seconds)
    }
}
