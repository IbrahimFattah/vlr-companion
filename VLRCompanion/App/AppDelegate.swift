import UIKit
import UserNotifications

/// Bridges UIKit-only notification plumbing into the SwiftUI app: receives the
/// APNs device token, presents alerts while the app is foregrounded, and routes
/// taps to `PushRouter` (which Home turns into a match-detail navigation).
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Task { await NotificationManager.shared.refreshAuthorizationStatus() }
        return true
    }

    // MARK: - Remote registration

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationManager.shared.didRegister(tokenData: deviceToken)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationManager.shared.didFailToRegister(error: error)
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show match alerts even when the app is in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
    -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    /// Tapping an alert (or its "View match" action) deep-links to the match.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        await MainActor.run { PushRouter.shared.handle(userInfo: userInfo) }
    }
}
