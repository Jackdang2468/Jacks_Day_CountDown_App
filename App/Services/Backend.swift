import Foundation
import Supabase

/// Supabase client, configured from Info.plist values that come from
/// Config/Secrets.xcconfig (or GitHub Actions secrets in the cloud build).
enum Backend {
    static let client: SupabaseClient? = {
        guard
            let host = Bundle.main.object(forInfoDictionaryKey: "SupabaseHost") as? String,
            let key = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String,
            !host.isEmpty, !key.isEmpty,
            let url = URL(string: "https://\(host)")
        else { return nil }
        // The auth session (access + refresh token) is kept in the iOS Keychain
        // by the Supabase SDK, never in plain files.
        return SupabaseClient(supabaseURL: url, supabaseKey: key)
    }()

    static var isConfigured: Bool { client != nil }

    static let imageBucket = "countdown-images"
}
