import Foundation
import Observation

/// Owns the signed-in session: the bearer token (in Keychain) and the cached
/// `Account`. Account features are additive — when no API server is configured
/// or the user is signed out, the rest of the app works unchanged.
@MainActor
@Observable
final class AccountStore {
    private static let tokenKey = "token"

    private let service = AccountService()
    private(set) var account: Account?
    private var token: String?

    var isSignedIn: Bool { account != nil && token != nil }
    var isAvailable: Bool { AppConfig.accountsBaseURL != nil }
    var authToken: String? { token }
    var myUserID: String? { account?.id }

    init() {
        token = Keychain.get(Self.tokenKey)
    }

    /// Validate a restored token on launch. Silent on failure (server down or
    /// token expired) — we just present as signed-out.
    func restore() async {
        #if DEBUG
        // UI-testing hook: `-vlrDevLogin <username>` signs in on launch.
        if let username = UserDefaults.standard.string(forKey: "vlrDevLogin"),
           isAvailable, token == nil {
            try? await signInDev(username: username, emoji: "🎮", color: "5E5CE6")
            return
        }
        #endif
        guard token != nil, isAvailable else { return }
        do {
            account = try await service.me(token: token!)
        } catch {
            account = nil
        }
    }

    func signInDev(username: String, emoji: String, color: String) async throws {
        let result = try await service.devLogin(username: username, emoji: emoji, color: color)
        setSession(token: result.token, account: result.user)
    }

    func updateProfile(username: String?, emoji: String?, color: String?) async throws {
        guard let token else { throw AccountError.server("Not signed in") }
        account = try await service.updateProfile(token: token, username: username,
                                                  emoji: emoji, color: color)
    }

    func deleteAccount() async throws {
        guard let token else { return }
        try await service.deleteAccount(token: token)
        signOut()
    }

    func signOut() {
        setSession(token: nil, account: nil)
    }

    /// Best-effort push of the local favorites to the server. Silent on failure
    /// so following a team never blocks on the network.
    func syncFavorites(favorite: String?, secondaries: [String]) async {
        guard let token else { return }
        try? await service.putFavorites(token: token, favorite: favorite, secondaries: secondaries)
    }

    private func setSession(token: String?, account: Account?) {
        self.token = token
        self.account = account
        Keychain.set(token, for: Self.tokenKey)
    }
}
