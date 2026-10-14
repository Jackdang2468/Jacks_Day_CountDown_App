import SwiftUI

struct CountdownListView: View {
    @Environment(CountdownStore.self) private var store
    @Environment(AuthService.self) private var auth
    @State private var editing: Countdown?
    @State private var isCreating = false
    @State private var showSettings = false
    @State private var showPast = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if auth.state == .offline {
                        OfflineBanner()
                    }
                    if let error = store.lastSyncError {
                        Label(error, systemImage: "icloud.slash")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if store.countdowns.isEmpty {
                        EmptyStateView { isCreating = true }
                    }

                    ForEach(store.upcoming) { item in
                        card(for: item)
                    }

                    if !store.past.isEmpty {
                        DisclosureGroup(isExpanded: $showPast) {
                            VStack(spacing: 16) {
                                ForEach(store.past) { item in card(for: item) }
                            }
                            .padding(.top, 12)
                        } label: {
                            Text("Past events (\(store.past.count))")
                                .font(.headline)
                        }
                        .tint(.primary)
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 96)
            }
            .refreshable { await store.syncNow() }
            .navigationTitle("Countdowns")
            .navigationDestination(for: Countdown.ID.self) { id in
                CountdownDetailView(countdownID: id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("Account and settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if store.isSyncing { ProgressView() }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Button { isCreating = true } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            LinearGradient(colors: [.brandCyan, .brandBlue, .brandViolet],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: Circle()
                        )
                        .shadow(color: .brandBlue.opacity(0.4), radius: 12, y: 6)
                }
                .padding(24)
                .accessibilityLabel("New countdown")
            }
            .sheet(isPresented: $isCreating) {
                CountdownEditorView(original: nil)
            }
            .sheet(item: $editing) { item in
                CountdownEditorView(original: item)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    private func card(for item: Countdown) -> some View {
        NavigationLink(value: item.id) {
            CountdownCard(countdown: item)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Edit", systemImage: "pencil") { editing = item }
            Button("Delete", systemImage: "trash", role: .destructive) {
                withAnimation { store.delete(item) }
            }
        }
    }
}

struct CountdownCard: View {
    let countdown: Countdown

    var body: some View {
        let days = countdown.daysRemaining()
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                if let emoji = countdown.emoji, !emoji.isEmpty {
                    Text(emoji).font(.largeTitle)
                }
                Spacer(minLength: 0)
                Text(countdown.title)
                    .font(.title3.bold())
                    .lineLimit(2)
                Text(countdown.targetDate, format: countdown.isAllDay
                     ? .dateTime.weekday(.abbreviated).month().day().year()
                     : .dateTime.weekday(.abbreviated).month().day().hour().minute())
                    .font(.subheadline)
                    .opacity(0.85)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(days == 0 ? "🎉" : "\(abs(days))")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(DayMath.caption(for: days))
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .opacity(0.85)
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(height: 170)
        .background { CountdownBackground(countdown: countdown, maxPixel: 900) }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 6)
        .opacity(countdown.isPast ? 0.75 : 1)
    }
}

private struct EmptyStateView: View {
    var onCreate: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
            Text("Nothing to count down yet")
                .font(.title3.bold())
            Text("Add a trip, birthday, launch, or anything you're looking forward to.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Add your first countdown", action: onCreate)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
        }
        .padding(.vertical, 60)
    }
}

private struct OfflineBanner: View {
    var body: some View {
        Label("Sync isn't set up yet, so countdowns stay on this phone.", systemImage: "info.circle")
            .font(.footnote)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.yellow.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
    }
}
