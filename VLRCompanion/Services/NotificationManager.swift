import Foundation
import UserNotifications

/// Local-notification stub for "your team is live" alerts, fired by the Home
/// live ticker when it sees a followed team's match flip to live while the
/// app is running.
///
/// Server-push integration point: match-start/match-end alerts while the app
/// is closed need APNs from the backend. When that lands, register for remote
/// notifications here and drop the local scheduling path (the payloads can
/// keep the same identifier scheme, `live-{match_id}`).
enum NotificationManager {

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func notifyMatchLive(_ match: Match) {
        guard UserDefaults.standard.object(forKey: "matchAlerts") == nil
                || UserDefaults.standard.bool(forKey: "matchAlerts") else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(match.team1.name) vs \(match.team2.name) is live"
        content.body = "\(match.eventName) · \(match.stage)"
        content.sound = .default

        let request = UNNotificationRequest(identifier: "live-\(match.id)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
