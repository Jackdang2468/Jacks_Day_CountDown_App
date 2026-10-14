import AppIntents
import Foundation
import Observation
import WidgetKit

/// Local-first store: changes save to the shared container right away (so
/// widgets update instantly) and then sync to the user's account.
@MainActor
@Observable
final class CountdownStore {
    private(set) var countdowns: [Countdown] = []
    private(set) var isSyncing = false
    private(set) var lastSyncError: String?
    private(set) var lastSynced: Date?

    private var sync: SyncService?
    /// Mirrors saves and deletes to Outlook when connected.
    var outlook: OutlookService?
    private var pending = PendingChanges.load()

    init() {
        countdowns = CountdownFile.load().sorted(by: Self.order)
    }

    var past: [Countdown] {
        countdowns.filter(\.isPast).sorted { $0.targetDate > $1.targetDate }
    }

    func upcoming(sortedBy sort: CountdownSort) -> [Countdown] {
        let now = Date.now
        let items = countdowns.filter { !$0.isPast }
        let sorted: [Countdown]
        switch sort {
        case .soonest: sorted = items.sorted { $0.nextDate(from: now) < $1.nextDate(from: now) }
        case .latest: sorted = items.sorted { $0.nextDate(from: now) > $1.nextDate(from: now) }
        case .name: sorted = items.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .newest: sorted = items.sorted { $0.createdAt > $1.createdAt }
        }
        // Pinned countdowns always come first.
        return sorted.filter(\.isPinned) + sorted.filter { !$0.isPinned }
    }

    func togglePin(_ countdown: Countdown) {
        var item = countdown
        item.isPinned.toggle()
        save(item, newImage: nil, removeImage: false)
    }

    // MARK: Account

    func attach(userID: UUID?) async {
        guard let userID, let client = Backend.client else {
            sync = nil
            return
        }
        // A different account signed in on this phone: start from a clean cache.
        if pending.ownerID != nil, pending.ownerID != userID {
            wipeLocal()
        }
        pending.ownerID = userID
        pending.save()
        sync = SyncService(client: client, userID: userID)
        await syncNow()
    }

    func signedOut() {
        sync = nil
        wipeLocal()
    }

    // MARK: Editing

    func save(_ countdown: Countdown, newImage: Data?, removeImage: Bool, addToOutlook: Bool = false) {
        var item = countdown
        item.updatedAt = .now
        let old = countdowns.first { $0.id == item.id }

        if let newImage {
            let key = ImageStore.newKey()
            ImageStore.save(newImage, key: key)
            item.imageKey = key
            pending.imageUploads.insert(key)
        } else if removeImage {
            item.imageKey = nil
        }
        if let oldKey = old?.imageKey, oldKey != item.imageKey {
            ImageStore.delete(oldKey)
            pending.imageDeletes.insert(oldKey)
            pending.imageUploads.remove(oldKey)
        }

        if let index = countdowns.firstIndex(where: { $0.id == item.id }) {
            countdowns[index] = item
        } else {
            countdowns.append(item)
        }
        pending.upserts.insert(item.id)
        persist()
        let saved = item
        Task {
            await syncNow()
            await outlook?.countdownSaved(saved, isNew: old == nil, force: addToOutlook)
        }
    }

    func delete(_ countdown: Countdown) {
        countdowns.removeAll { $0.id == countdown.id }
        if let key = countdown.imageKey {
            ImageStore.delete(key)
            pending.imageDeletes.insert(key)
            pending.imageUploads.remove(key)
        }
        pending.upserts.remove(countdown.id)
        pending.deletes.insert(countdown.id)
        persist()
        Task {
            await syncNow()
            await outlook?.remove(countdown)
        }
    }

    // MARK: Sync

    func syncNow() async {
        guard let sync, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            // 1. Push what changed on this phone.
            for key in pending.imageUploads where ImageStore.exists(key) {
                try await sync.uploadImage(key: key)
                pending.imageUploads.remove(key)
            }
            try await sync.deleteImages(keys: Array(pending.imageDeletes))
            pending.imageDeletes.removeAll()

            try await sync.delete(ids: Array(pending.deletes))
            pending.deletes.removeAll()

            let toPush = countdowns.filter { pending.upserts.contains($0.id) }
            try await sync.upsert(toPush)
            pending.upserts.removeAll()
            pending.save()

            // 2. Pull the account copy, which now includes this phone's changes.
            let remote = try await sync.fetchAll()
            for item in remote {
                if let key = item.imageKey, !ImageStore.exists(key) {
                    try? await sync.downloadImage(key: key)
                }
            }
            countdowns = remote.sorted(by: Self.order)
            persist()
            lastSynced = .now
            lastSyncError = nil
        } catch {
            pending.save()
            lastSyncError = "Couldn't sync. Your changes are saved on this phone and will sync later."
        }
    }

    // MARK: Private

    private func persist() {
        countdowns.sort(by: Self.order)
        CountdownFile.save(countdowns)
        pending.save()
        WidgetCenter.shared.reloadAllTimelines()
        refreshSystemFeatures()
    }

    /// Reminders, Live Activities, and Siri's list of countdown names all
    /// follow the current countdowns.
    func refreshSystemFeatures() {
        let snapshot = countdowns
        Task {
            // Asks once, the first time there is something to remind about.
            if !snapshot.isEmpty && ReminderScheduler.isEnabled {
                await ReminderScheduler.requestPermission()
            }
            await ReminderScheduler.reschedule(snapshot)
            await LiveActivityManager.refresh(snapshot)
        }
        DayCounterShortcuts.updateAppShortcutParameters()
    }

    private func wipeLocal() {
        for key in countdowns.compactMap(\.imageKey) { ImageStore.delete(key) }
        countdowns = []
        pending = PendingChanges()
        persist()
    }

    private static func order(_ a: Countdown, _ b: Countdown) -> Bool {
        a.targetDate < b.targetDate
    }
}

/// Changes made on this phone that the server has not seen yet.
private struct PendingChanges: Codable {
    var ownerID: UUID?
    var upserts: Set<UUID> = []
    var deletes: Set<UUID> = []
    var imageUploads: Set<String> = []
    var imageDeletes: Set<String> = []

    private static var url: URL { SharedContainer.baseURL.appendingPathComponent("pending.json") }

    static func load() -> PendingChanges {
        guard let data = try? Data(contentsOf: url),
              let value = try? JSONDecoder().decode(PendingChanges.self, from: data)
        else { return PendingChanges() }
        return value
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: Self.url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

enum CountdownSort: String, CaseIterable, Identifiable {
    case soonest, latest, name, newest
    var id: String { rawValue }
    var label: String {
        switch self {
        case .soonest: return "Soonest first"
        case .latest: return "Latest first"
        case .name: return "Name"
        case .newest: return "Recently added"
        }
    }
}
