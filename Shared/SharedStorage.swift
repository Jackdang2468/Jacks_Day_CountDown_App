import Foundation
import ImageIO
import UIKit

/// The App Group container both the app and the widget extension can read.
/// Only a local cache lives here; the account copy lives in Supabase.
enum SharedContainer {
    /// AltStore/SideStore rewrite App Group IDs when they re-sign the app and
    /// publish the rewritten IDs under `ALTAppGroups`, so prefer those.
    static let appGroupID: String? = {
        if let groups = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String],
           let first = groups.first {
            return first
        }
        let configured = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String
        return (configured?.isEmpty == false) ? configured : nil
    }()

    static let baseURL: URL = {
        if let id = appGroupID,
           let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
            return url
        }
        // Fallback keeps the app usable; widgets will be empty without the App Group.
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return support
    }()

    static var isShared: Bool {
        guard let id = appGroupID else { return false }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) != nil
    }

    static var countdownsURL: URL { baseURL.appendingPathComponent("countdowns.json") }

    static var imagesURL: URL {
        let url = baseURL.appendingPathComponent("Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

enum CountdownFile {
    static func load() -> [Countdown] {
        guard let data = try? Data(contentsOf: SharedContainer.countdownsURL) else { return [] }
        return (try? decoder.decode([Countdown].self, from: data)) ?? []
    }

    static func save(_ countdowns: [Countdown]) {
        guard let data = try? encoder.encode(countdowns) else { return }
        try? data.write(to: SharedContainer.countdownsURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

enum ImageStore {
    static func url(for key: String) -> URL {
        SharedContainer.imagesURL.appendingPathComponent(key)
    }

    static func exists(_ key: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: key).path)
    }

    static func save(_ data: Data, key: String) {
        try? data.write(to: url(for: key), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    static func delete(_ key: String) {
        try? FileManager.default.removeItem(at: url(for: key))
    }

    static func newKey() -> String { UUID().uuidString.lowercased() + ".jpg" }

    /// Loads a downsampled image. Widgets have a tight memory budget, so they
    /// should ask for a small `maxPixel`.
    static func image(for key: String, maxPixel: CGFloat = 1200) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url(for: key) as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }

    /// Shrinks a picked photo to a sensible size and re-encodes it as JPEG.
    static func prepareForStorage(_ data: Data, maxPixel: CGFloat = 1600) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cg).jpegData(compressionQuality: 0.82)
    }
}
