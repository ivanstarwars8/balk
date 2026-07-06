import SwiftUI
import UIKit
import UserNotifications

/// App delegate wired via @UIApplicationDelegateAdaptor — needed to receive
/// the APNs device token callbacks (SwiftUI has no native hook for those).
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = PushCenter.shared
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        PushCenter.shared.token = hex
        Task { await APIClient.shared.registerPushToken(hex) }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Silent: happens on Simulator (no APNs) or before the Push
        // Notifications capability is enabled on the App ID.
    }
}

/// Requests notification permission and drives APNs registration.
@MainActor
final class PushCenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PushCenter()
    var token: String?

    /// Ask once (system remembers the choice) and register for remote pushes.
    func requestAndRegister() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        guard granted else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// Re-send the token after a fresh login (token may have been captured
    /// before the user was authenticated).
    func resendIfNeeded() async {
        if let t = token { await APIClient.shared.registerPushToken(t) }
    }

    // Show banners even while the app is in the foreground.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}
