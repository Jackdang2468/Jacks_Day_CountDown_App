import Foundation
import Observation
import Supabase

@MainActor
@Observable
final class AuthService {
    enum State: Equatable {
        case loading
        case signedOut
        case signedIn(userID: UUID, email: String)
        /// Backend not configured; the app runs on-device only.
        case offline
    }

    private(set) var state: State = .loading
    var errorMessage: String?
    var infoMessage: String?
    var isWorking = false

    init() {
        guard let client = Backend.client else {
            state = .offline
            return
        }
        Task { [weak self] in
            for await (_, session) in client.auth.authStateChanges {
                guard let self else { return }
                guard let session else {
                    self.state = .signedOut
                    continue
                }
                if session.isExpired {
                    // A refreshed session arrives as its own event.
                    if (try? await client.auth.refreshSession()) == nil {
                        self.state = .signedOut
                    }
                    continue
                }
                self.state = .signedIn(userID: session.user.id, email: session.user.email ?? "")
            }
        }
    }

    var userID: UUID? {
        if case let .signedIn(id, _) = state { return id }
        return nil
    }

    var email: String? {
        if case let .signedIn(_, email) = state { return email }
        return nil
    }

    func signIn(email: String, password: String) async {
        await run {
            try await Backend.client?.auth.signIn(email: email.trimmed, password: password)
        }
    }

    func signUp(email: String, password: String) async {
        await run {
            guard let client = Backend.client else { return }
            let response = try await client.auth.signUp(email: email.trimmed, password: password)
            if response.session == nil {
                self.infoMessage = "Check your email to confirm your account, then sign in."
            }
        }
    }

    func signOut() async {
        await run {
            try await Backend.client?.auth.signOut()
        }
    }

    private func run(_ work: @escaping () async throws -> Void) async {
        errorMessage = nil
        infoMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try await work()
        } catch {
            errorMessage = Self.friendly(error)
        }
    }

    private static func friendly(_ error: Error) -> String {
        let text = error.localizedDescription
        if text.localizedCaseInsensitiveContains("invalid login") {
            return "That email and password don't match an account."
        }
        if text.localizedCaseInsensitiveContains("email not confirmed") {
            return "Please confirm your email first, then sign in."
        }
        return text
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
