import Foundation
import Observation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

/// Owns everything notification-related:
/// - **Local, in-session** alerts (`notifyMatchLive`) fired by Home's live
///   ticker when a followed team goes live while the app is open. Works with
///   no backend.
/// - **Remote** push registration: asks for authorization, registers with
///   APNs, and syncs the device token + followed teams + per-type alert
///   preferences to our push worker (`push-server/`, `AppConfig.pushBackendURL`),
///   which is what actually sends alerts while the app is closed.
///
/// A single shared instance so the `AppDelegate` (token callbacks) and the UI
/// (Settings toggles, onboarding) talk to the same state.
@Observable
final class NotificationManager {
    static let shared = NotificationManager()

    /// Category the server tags match alerts with, so we can attach a "View
    /// match" action and route taps.
    static let matchCategoryID = "MATCH_ALERT"

    // MARK: - Preference keys (UserDefaults-backed; mirrored by Settings)

    enum Key {
        /// Master "match is live" alert. Named `matchAlerts` for back-compat
        /// with the original single toggle.
        static let live = "matchAlerts"
        static let startingSoon = "alertStartingSoon"
        static let finished = "alertFinished"
        static let majorFinals = "alertMajorFinals"
        static let deviceToken = "apnsDeviceToken"
    }

    /// Current system authorization; refreshed on launch and after prompting.
    var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// Hex APNs token once registered. Persisted so we can re-sync followed
    /// teams on later launches before a fresh token arrives.
    private(set) var deviceToken: String? {
        didSet { UserDefaults.standard.set(deviceToken, forKey: Key.deviceToken) }
    }

    /// Teams the user follows; kept here so any preference change can re-POST
    /// the full registration. Updated from `FavoritesStore`.
    private var followedTeams: [String] = []

    private init() {
        UserDefaults.standard.register(defaults: [
            Key.live: true,
            Key.startingSoon: true,
            Key.finished: false,
            Key.majorFinals: false,
        ])
        deviceToken = UserDefaults.standard.string(forKey: Key.deviceToken)
    }

    // MARK: - Alert preferences

    struct Preferences: Encodable {
        var live: Bool
        var startingSoon: Bool
        var finished: Bool
        var majorFinals: Bool

        static var current: Preferences {
            let d = UserDefaults.standard
            return Preferences(live: d.bool(forKey: Key.live),
                               startingSoon: d.bool(forKey: Key.startingSoon),
                               finished: d.bool(forKey: Key.finished),
                               majorFinals: d.bool(forKey: Key.majorFinals))
        }
    }

    // MARK: - Authorization + registration

    /// Requests permission (if not already asked) and, when granted, registers
    /// categories and kicks off APNs registration. Safe to call repeatedly.
    @MainActor
    func enableNotifications() async {
        registerCategories()
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refreshAuthorizationStatus()
        guard granted else { return }
        #if canImport(UIKit)
        UIApplication.shared.registerForRemoteNotifications()
        #endif
    }

    @MainActor
    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    private func registerCategories() {
        let view = UNNotificationAction(identifier: "VIEW_MATCH",
                                        title: "View match",
                                        options: [.foreground])
        let category = UNNotificationCategory(identifier: Self.matchCategoryID,
                                              actions: [view],
                                              intentIdentifiers: [],
                                              options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - APNs token callbacks (from AppDelegate)

    func didRegister(tokenData: Data) {
        let hex = tokenData.map { String(format: "%02x", $0) }.joined()
        deviceToken = hex
        Task { await syncRegistration() }
    }

    func didFailToRegister(error: Error) {
        // Common in the Simulator / unsigned builds; not fatal — local alerts
        // and `simctl push` still work.
        print("[Push] remote registration failed: \(error.localizedDescription)")
    }

    // MARK: - Backend sync

    /// Called when the followed-team set changes. Re-syncs if we already have a
    /// token.
    func updateFollowedTeams(_ ids: [String]) {
        let sorted = ids.sorted()
        guard sorted != followedTeams else { return }
        followedTeams = sorted
        Task { await syncRegistration() }
    }

    /// Called when a Settings alert toggle changes.
    func preferencesChanged() {
        Task { await syncRegistration() }
    }

    /// POSTs token + followed teams + preferences to the push worker. No-op
    /// when there's no token yet or no backend configured.
    private func syncRegistration() async {
        guard let token = deviceToken, let base = AppConfig.pushBackendURL else { return }

        struct Body: Encodable {
            let token: String
            let teams: [String]
            let alerts: Preferences
            let environment: String
            let bundleID: String
        }
        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif
        let body = Body(token: token,
                        teams: followedTeams,
                        alerts: .current,
                        environment: environment,
                        bundleID: Bundle.main.bundleIdentifier ?? "com.vlrcompanion.app")

        var request = URLRequest(url: base.appendingPathComponent("register"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)
        do {
            _ = try await URLSession.shared.data(for: request)
        } catch {
            print("[Push] registration sync failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Local, in-session alert (no backend)

    func notifyMatchLive(_ match: Match) {
        guard UserDefaults.standard.bool(forKey: Key.live) else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(match.team1.name) vs \(match.team2.name) is live"
        content.body = [match.eventName, match.stage].filter { !$0.isEmpty }.joined(separator: " · ")
        content.sound = .default
        content.categoryIdentifier = Self.matchCategoryID
        // Same payload shape as the server sends, so the tap handler routes
        // identically whether the alert came from here or from APNs.
        content.userInfo = ["match": [
            "id": match.id,
            "team1": match.team1.name, "tag1": match.team1.tag, "color1": match.team1.colorHex,
            "team2": match.team2.name, "tag2": match.team2.tag, "color2": match.team2.colorHex,
            "event": match.eventName, "stage": match.stage, "status": "live",
        ]]

        let request = UNNotificationRequest(identifier: "live-\(match.id)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
