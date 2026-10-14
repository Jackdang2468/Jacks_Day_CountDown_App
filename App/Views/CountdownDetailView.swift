import SwiftUI

struct CountdownDetailView: View {
    let countdownID: Countdown.ID
    @Environment(CountdownStore.self) private var store
    @Environment(OutlookService.self) private var outlook
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var showCalendar = false
    @State private var calendarAdded = false
    @State private var confirmDelete = false
    @State private var outlookBusy = false
    @State private var outlookMessage: String?
    @State private var shareImage: UIImage?
    @State private var liveActivityMessage: String?

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
                Text(countdown.nextDate(), format: countdown.isAllDay
                     ? .dateTime.weekday(.wide).month(.wide).day().year()
                     : .dateTime.weekday(.wide).month(.wide).day().year().hour().minute())
                    .font(.headline)
                    .opacity(0.85)

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    LiveCountdown(target: countdown.eventStart(from: context.date), now: context.date)
                }
                .padding(.vertical, 8)

                if calendarAdded {
                    Label("Added to your calendar", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                if let n = countdown.upcomingAnniversary() {
                    Label("\(n.ordinal) anniversary", systemImage: "repeat")
                        .font(.subheadline.weight(.semibold))
                }
                if let liveActivityMessage {
                    Text(liveActivityMessage)
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)
                }
                if let outlookMessage {
                    Text(outlookMessage)
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)
                }
                Spacer()

                HStack(spacing: 12) {
                    if outlook.isConfigured {
                        Button {
                            Task { await sendToOutlook(countdown) }
                        } label: {
                            Group {
                                if outlookBusy {
                                    ProgressView()
                                } else {
                                    Label(outlook.isLinked(countdown) ? "Update Outlook" : "Add to Outlook",
                                          systemImage: "calendar.badge.plus")
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .disabled(outlookBusy)
                    }
                    Menu {
                        Button("iPhone Calendar", systemImage: "calendar") { showCalendar = true }
                        if let ics = ICSFile.make(for: countdown) {
                            ShareLink(item: ics) {
                                Label("Share .ics file", systemImage: "square.and.arrow.up")
                            }
                        }
                    } label: {
                        Label(outlook.isConfigured ? "More" : "Add to Calendar",
                              systemImage: outlook.isConfigured ? "ellipsis" : "calendar.badge.plus")
                            .frame(maxWidth: outlook.isConfigured ? nil : .infinity, minHeight: 44)
                            .padding(.horizontal, outlook.isConfigured ? 8 : 0)
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
                Button(countdown.isPinned ? "Unpin" : "Pin to top",
                       systemImage: countdown.isPinned ? "pin.slash" : "pin") {
                    store.togglePin(countdown)
                }
                if let shareImage {
                    ShareLink(item: Image(uiImage: shareImage),
                              preview: SharePreview(countdown.title, image: Image(uiImage: shareImage))) {
                        Label("Share image", systemImage: "photo.on.rectangle")
                    }
                }
                if LiveActivityManager.isEligible(countdown) {
                    if LiveActivityManager.isRunning(countdown.id) {
                        Button("Stop Live Activity", systemImage: "stop.circle") {
                            Task {
                                await LiveActivityManager.stop(countdown.id)
                                liveActivityMessage = nil
                            }
                        }
                    } else {
                        Button("Start Live Activity", systemImage: "timer") {
                            do {
                                try LiveActivityManager.start(countdown)
                                liveActivityMessage = "Live countdown is on your Lock Screen"
                            } catch {
                                liveActivityMessage = "Live Activities are off. Turn them on in iPhone Settings > Day Counter."
                            }
                        }
                    }
                }
                Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .sheet(isPresented: $isEditing) {
            CountdownEditorView(original: countdown)
        }
        .task(id: countdown) {
            shareImage = ShareCardView.render(countdown)
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

extension CountdownDetailView {
    private func sendToOutlook(_ countdown: Countdown) async {
        outlookBusy = true
        defer { outlookBusy = false }
        outlookMessage = nil
        if !outlook.isConnected { await outlook.connect() }
        guard outlook.isConnected else {
            outlookMessage = outlook.errorMessage
            return
        }
        do {
            let wasLinked = outlook.isLinked(countdown)
            try await outlook.addOrUpdate(countdown)
            outlookMessage = wasLinked ? "Updated in Outlook" : "Added to Outlook"
        } catch {
            outlookMessage = error.localizedDescription
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
