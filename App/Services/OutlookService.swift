import AuthenticationServices
import CryptoKit
import EventKit
import Foundation
import Observation
import UIKit

/// "Connect Outlook". Two ways to reach the Outlook calendar:
///
/// - **iPhone account** (default, no setup): the user's Outlook/Exchange
///   account is added in iPhone Settings > Calendar > Accounts, and the app
///   writes events to that calendar with EventKit. iOS syncs them to Outlook.
/// - **Microsoft sign-in** (when the build has MS_CLIENT_ID): signs in with
///   OAuth 2.0 + PKCE and writes events through Microsoft Graph. Needs an
///   Entra app registration (docs/OUTLOOK.md).
///
/// The Graph path does the OAuth flow directly instead of using MSAL because MSAL ties
/// its redirect URI and Keychain group to the app's bundle ID and team ID,
/// which sideloading tools rewrite on every re-sign.
@MainActor
@Observable
final class OutlookService {
    static let redirectScheme = "jacksdaycounter"
    static let redirectURI = "jacksdaycounter://auth"
    private static let scopes = "openid profile offline_access User.Read Calendars.ReadWrite"

    private(set) var accountName: String?
    private(set) var isWorking = false
    var errorMessage: String?

    var autoAdd: Bool {
        didSet { UserDefaults.standard.set(autoAdd, forKey: "outlook.autoAdd") }
    }

    var isConnected: Bool { accountName != nil }

    /// Outlook is always offered; this decides which path it uses.
    var isConfigured: Bool { true }

    /// True when the build carries an Entra client ID (MS_CLIENT_ID).
    var usesMicrosoftSignIn: Bool { !clientID.isEmpty }

    // iPhone-account path
    private let eventStore = EKEventStore()
    private(set) var phoneCalendarID: String? {
        didSet { UserDefaults.standard.set(phoneCalendarID, forKey: "outlook.phoneCalendar") }
    }

    /// Calendars the app may write to, Outlook/Exchange ones first.
    var writableCalendars: [EKCalendar] {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return [] }
        return eventStore.calendars(for: .event)
            .filter(\.allowsContentModifications)
            .sorted { ($0.source.sourceType == .exchange ? 0 : 1, $0.title) < ($1.source.sourceType == .exchange ? 0 : 1, $1.title) }
    }

    private let clientID = Bundle.main.object(forInfoDictionaryKey: "MicrosoftClientID") as? String ?? ""
    private let tenant: String = {
        let value = Bundle.main.object(forInfoDictionaryKey: "MicrosoftTenant") as? String ?? ""
        return value.isEmpty ? "common" : value
    }()

    private var accessToken: String?
    private var accessTokenExpiry = Date.distantPast
    private let webAuth = WebAuthenticator()

    /// Countdown ID -> event ID, so edits update the same event.
    private var eventIDsKey: String { usesMicrosoftSignIn ? "outlook.eventIDs" : "outlook.phoneEventIDs" }
    private var eventIDs: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: eventIDsKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: eventIDsKey) }
    }

    init() {
        autoAdd = UserDefaults.standard.bool(forKey: "outlook.autoAdd")
        if usesMicrosoftSignIn {
            accountName = UserDefaults.standard.string(forKey: "outlook.account")
            if Keychain.get("outlook.refresh") == nil { accountName = nil }
        } else if let id = UserDefaults.standard.string(forKey: "outlook.phoneCalendar"),
                  EKEventStore.authorizationStatus(for: .event) == .fullAccess,
                  let calendar = eventStore.calendar(withIdentifier: id) {
            phoneCalendarID = id
            accountName = Self.describe(calendar)
        }
    }

    private static func describe(_ calendar: EKCalendar) -> String {
        "\(calendar.title) (\(calendar.source.title))"
    }

    func isLinked(_ countdown: Countdown) -> Bool {
        eventIDs[countdown.id.uuidString] != nil
    }

    // MARK: Connect / disconnect

    func connect() async {
        guard usesMicrosoftSignIn else {
            await connectPhoneAccount()
            return
        }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let verifier = Self.randomURLSafe(bytes: 32)
            let challenge = Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
            let state = Self.randomURLSafe(bytes: 16)

            var components = URLComponents(string: "https://login.microsoftonline.com/\(tenant)/oauth2/v2.0/authorize")!
            components.queryItems = [
                .init(name: "client_id", value: clientID),
                .init(name: "response_type", value: "code"),
                .init(name: "redirect_uri", value: Self.redirectURI),
                .init(name: "response_mode", value: "query"),
                .init(name: "scope", value: Self.scopes),
                .init(name: "state", value: state),
                .init(name: "code_challenge", value: challenge),
                .init(name: "code_challenge_method", value: "S256"),
                .init(name: "prompt", value: "select_account"),
            ]

            let callback = try await webAuth.start(url: components.url!, callbackScheme: Self.redirectScheme)
            let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
            if let error = items.first(where: { $0.name == "error_description" })?.value {
                throw OutlookError.message(error)
            }
            guard items.first(where: { $0.name == "state" })?.value == state,
                  let code = items.first(where: { $0.name == "code" })?.value
            else { throw OutlookError.message("Sign-in was cancelled or didn't complete.") }

            try await redeem([
                "grant_type": "authorization_code",
                "code": code,
                "redirect_uri": Self.redirectURI,
                "code_verifier": verifier,
            ])

            let me: GraphUser = try await graph("GET", "/me")
            accountName = me.mail ?? me.userPrincipalName ?? me.displayName ?? "Outlook"
            UserDefaults.standard.set(accountName, forKey: "outlook.account")
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            // User closed the sign-in sheet.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func disconnect() {
        phoneCalendarID = nil
        Keychain.delete("outlook.refresh")
        accessToken = nil
        accountName = nil
        eventIDs = [:]
        UserDefaults.standard.removeObject(forKey: "outlook.account")
    }

    // MARK: Calendar

    /// Creates the Outlook event, or updates it if this countdown already has one.
    func addOrUpdate(_ countdown: Countdown) async throws {
        guard usesMicrosoftSignIn else {
            try phoneUpsert(countdown)
            return
        }
        let body = GraphEvent(countdown)
        if let existing = eventIDs[countdown.id.uuidString] {
            do {
                let _: GraphCreated = try await graph("PATCH", "/me/events/\(existing)", body: body)
                return
            } catch OutlookError.notFound {
                // Deleted in Outlook; fall through and create it again.
            }
        }
        let created: GraphCreated = try await graph("POST", "/me/events", body: body)
        eventIDs[countdown.id.uuidString] = created.id
    }

    func remove(_ countdown: Countdown) async {
        guard let existing = eventIDs[countdown.id.uuidString] else { return }
        guard usesMicrosoftSignIn else {
            if let event = eventStore.event(withIdentifier: existing) {
                try? eventStore.remove(event, span: .thisEvent, commit: true)
            }
            eventIDs[countdown.id.uuidString] = nil
            return
        }
        try? await graphNoContent("DELETE", "/me/events/\(existing)")
        eventIDs[countdown.id.uuidString] = nil
    }

    // MARK: iPhone account

    private func connectPhoneAccount() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            guard try await eventStore.requestFullAccessToEvents() else {
                errorMessage = "Calendar access is off. Turn it on in iPhone Settings > Privacy & Security > Calendars > Day Counter."
                return
            }
            guard let calendar = writableCalendars.first(where: { $0.source.sourceType == .exchange }) else {
                errorMessage = "No Outlook calendar on this iPhone yet. Add your account in iPhone Settings > Calendar > Accounts > Add Account > Microsoft Exchange (or Outlook.com), then tap Connect again."
                return
            }
            choosePhoneCalendar(calendar)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func choosePhoneCalendar(_ calendar: EKCalendar) {
        if phoneCalendarID != calendar.calendarIdentifier {
            eventIDs = [:]
        }
        phoneCalendarID = calendar.calendarIdentifier
        accountName = Self.describe(calendar)
    }

    private func phoneUpsert(_ c: Countdown) throws {
        guard let id = phoneCalendarID, let calendar = eventStore.calendar(withIdentifier: id) else {
            accountName = nil
            throw OutlookError.message("The Outlook calendar isn't available. Connect Outlook again in Settings.")
        }
        let event = eventIDs[c.id.uuidString].flatMap { eventStore.event(withIdentifier: $0) }
            ?? EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = [c.emoji, c.title].compactMap { $0 }.joined(separator: " ")
        event.notes = c.notes.isEmpty ? "Added by Jack's Day Counter." : c.notes
        event.isAllDay = c.isAllDay
        if c.isAllDay {
            let day = Calendar.current.startOfDay(for: c.targetDate)
            event.startDate = day
            event.endDate = day
            event.availability = .free
        } else {
            event.startDate = c.targetDate
            event.endDate = c.targetDate.addingTimeInterval(3600)
        }
        event.alarms = [EKAlarm(relativeOffset: -24 * 60 * 60)]
        event.recurrenceRules = c.repeatsYearly
            ? [EKRecurrenceRule(recurrenceWith: .yearly, interval: 1, end: nil)]
            : nil
        try eventStore.save(event, span: .thisEvent, commit: true)
        eventIDs[c.id.uuidString] = event.eventIdentifier
    }

    /// Called by the store after every save/delete.
    func countdownSaved(_ countdown: Countdown, isNew: Bool, force: Bool) async {
        guard isConnected, force || (isNew && autoAdd) || isLinked(countdown) else { return }
        do { try await addOrUpdate(countdown) } catch { errorMessage = error.localizedDescription }
    }

    // MARK: Tokens

    private func validAccessToken() async throws -> String {
        if let accessToken, accessTokenExpiry > .now.addingTimeInterval(60) { return accessToken }
        guard let refresh = Keychain.get("outlook.refresh") else {
            accountName = nil
            throw OutlookError.message("Outlook isn't connected. Connect it in Settings.")
        }
        try await redeem(["grant_type": "refresh_token", "refresh_token": refresh])
        return accessToken ?? ""
    }

    private func redeem(_ params: [String: String]) async throws {
        var request = URLRequest(url: URL(string: "https://login.microsoftonline.com/\(tenant)/oauth2/v2.0/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var all = params
        all["client_id"] = clientID
        all["scope"] = Self.scopes
        request.httpBody = Self.formEncode(all).data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200, let token = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
            let reason = (try? JSONDecoder().decode(TokenError.self, from: data))?.error_description
            if params["grant_type"] == "refresh_token" { disconnect() }
            throw OutlookError.message(reason?.components(separatedBy: "\r\n").first
                                       ?? "Microsoft sign-in failed (\(status)).")
        }
        accessToken = token.access_token
        accessTokenExpiry = .now.addingTimeInterval(TimeInterval(token.expires_in))
        if let refresh = token.refresh_token { Keychain.set(refresh, for: "outlook.refresh") }
    }

    // MARK: Graph

    private func graphRequest(_ method: String, _ path: String, body: Encodable?) async throws -> (Data, Int) {
        var request = URLRequest(url: URL(string: "https://graph.microsoft.com/v1.0" + path)!)
        request.httpMethod = method
        let token = try await validAccessToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200...299: return (data, status)
        case 404: throw OutlookError.notFound
        case 401, 403:
            throw OutlookError.message("Outlook refused access (\(status)). Your organization may need to approve the app; see docs/OUTLOOK.md.")
        default:
            let message = (try? JSONDecoder().decode(GraphErrorEnvelope.self, from: data))?.error.message
            throw OutlookError.message(message ?? "Outlook request failed (\(status)).")
        }
    }

    private func graph<T: Decodable>(_ method: String, _ path: String, body: Encodable? = nil) async throws -> T {
        let (data, _) = try await graphRequest(method, path, body: body)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func graphNoContent(_ method: String, _ path: String) async throws {
        _ = try await graphRequest(method, path, body: nil)
    }

    // MARK: Helpers

    private static func randomURLSafe(bytes: Int) -> String {
        var data = Data(count: bytes)
        _ = data.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, bytes, $0.baseAddress!) }
        return base64URL(data)
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func formEncode(_ params: [String: String]) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return params.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value)"
        }.joined(separator: "&")
    }
}

enum OutlookError: LocalizedError {
    case message(String)
    case notFound

    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        case .notFound: return "That Outlook event no longer exists."
        }
    }
}

// MARK: Wire types

private struct TokenResponse: Decodable {
    let access_token: String
    let refresh_token: String?
    let expires_in: Int
}

private struct TokenError: Decodable {
    let error_description: String?
}

private struct GraphUser: Decodable {
    let displayName: String?
    let mail: String?
    let userPrincipalName: String?
}

private struct GraphCreated: Decodable {
    let id: String
}

private struct GraphErrorEnvelope: Decodable {
    struct Inner: Decodable { let message: String }
    let error: Inner
}

private struct GraphEvent: Encodable {
    struct Body: Encodable { let contentType = "text"; let content: String }
    struct When: Encodable { let dateTime: String; let timeZone: String }

    let subject: String
    let body: Body
    let start: When
    let end: When
    let isAllDay: Bool
    let isReminderOn = true
    let reminderMinutesBeforeStart = 24 * 60
    let showAs: String
    let categories = ["Day Counter"]
    let recurrence: Recurrence?

    struct Recurrence: Encodable {
        struct Pattern: Encodable { let type = "absoluteYearly"; let interval = 1; let month: Int; let dayOfMonth: Int }
        struct Range: Encodable { let type = "noEnd"; let startDate: String }
        let pattern: Pattern
        let range: Range
    }

    init(_ c: Countdown) {
        let calendar = Calendar.current
        let zone = TimeZone.current.identifier
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        subject = [c.emoji, c.title].compactMap { $0 }.joined(separator: " ")
        if c.repeatsYearly {
            let parts = calendar.dateComponents([.year, .month, .day], from: c.targetDate)
            recurrence = Recurrence(
                pattern: .init(month: parts.month ?? 1, dayOfMonth: parts.day ?? 1),
                range: .init(startDate: String(format: "%04d-%02d-%02d", parts.year ?? 2000, parts.month ?? 1, parts.day ?? 1))
            )
        } else {
            recurrence = nil
        }
        body = Body(content: c.notes.isEmpty ? "Added by Jack's Day Counter." : c.notes)
        isAllDay = c.isAllDay
        if c.isAllDay {
            let day = calendar.startOfDay(for: c.targetDate)
            let next = calendar.date(byAdding: .day, value: 1, to: day)!
            start = When(dateTime: formatter.string(from: day), timeZone: zone)
            end = When(dateTime: formatter.string(from: next), timeZone: zone)
            showAs = "free"
        } else {
            start = When(dateTime: formatter.string(from: c.targetDate), timeZone: zone)
            end = When(dateTime: formatter.string(from: c.targetDate.addingTimeInterval(3600)), timeZone: zone)
            showAs = "busy"
        }
    }
}

/// Async wrapper around the system web sign-in sheet.
private final class WebAuthenticator: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    @MainActor
    func start(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { url, error in
                if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: error ?? OutlookError.message("Sign-in failed."))
                }
            }
            session.presentationContextProvider = self
            self.session = session
            session.start()
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }
}
