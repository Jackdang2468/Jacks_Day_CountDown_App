import Foundation
import Supabase

/// Row shape of the `countdowns` table (see supabase/migrations).
struct CountdownRecord: Codable {
    var id: UUID
    var userId: UUID
    var title: String
    var targetDate: Date
    var isAllDay: Bool
    var notes: String
    var theme: String
    var emoji: String?
    var imageKey: String?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, notes, theme, emoji
        case userId = "user_id"
        case targetDate = "target_date"
        case isAllDay = "is_all_day"
        case imageKey = "image_key"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(_ c: Countdown, userID: UUID) {
        id = c.id
        userId = userID
        title = c.title
        targetDate = c.targetDate
        isAllDay = c.isAllDay
        notes = c.notes
        theme = c.theme.rawValue
        emoji = c.emoji
        imageKey = c.imageKey
        createdAt = c.createdAt
        updatedAt = c.updatedAt
    }

    var countdown: Countdown {
        Countdown(
            id: id, title: title, targetDate: targetDate, isAllDay: isAllDay,
            notes: notes, theme: CountdownTheme(rawValue: theme) ?? .ocean,
            emoji: emoji, imageKey: imageKey, createdAt: createdAt, updatedAt: updatedAt
        )
    }
}

/// Talks to Supabase. Every request carries the signed-in user's token, and
/// row-level security on the server limits each user to their own rows/files.
struct SyncService {
    let client: SupabaseClient
    let userID: UUID

    private var table: PostgrestQueryBuilder { client.from("countdowns") }

    func fetchAll() async throws -> [Countdown] {
        let rows: [CountdownRecord] = try await table
            .select()
            .order("target_date", ascending: true)
            .execute()
            .value
        return rows.map(\.countdown)
    }

    func upsert(_ countdowns: [Countdown]) async throws {
        guard !countdowns.isEmpty else { return }
        try await table.upsert(countdowns.map { CountdownRecord($0, userID: userID) }).execute()
    }

    func delete(ids: [UUID]) async throws {
        guard !ids.isEmpty else { return }
        try await table.delete().in("id", values: ids.map(\.uuidString)).execute()
    }

    // MARK: Images (private bucket, one folder per user)

    private func remotePath(_ key: String) -> String { "\(userID.uuidString.lowercased())/\(key)" }

    func uploadImage(key: String) async throws {
        let data = try Data(contentsOf: ImageStore.url(for: key))
        try await client.storage.from(Backend.imageBucket).upload(
            remotePath(key),
            data: data,
            options: FileOptions(contentType: "image/jpeg", upsert: true)
        )
    }

    func downloadImage(key: String) async throws {
        let data = try await client.storage.from(Backend.imageBucket).download(path: remotePath(key))
        ImageStore.save(data, key: key)
    }

    func deleteImages(keys: [String]) async throws {
        guard !keys.isEmpty else { return }
        _ = try await client.storage.from(Backend.imageBucket).remove(paths: keys.map(remotePath))
    }
}
