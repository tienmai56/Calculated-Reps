import UIKit
import UserNotifications

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // Retire old daily reflection reminders: the previous notebook is read-only.
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["matmind.reflection.reminder"])
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        AuthService.handleOpenURL(url)
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in
            SocialPushCoordinator.token = token
            NotificationCenter.default.post(name: Notification.Name("MatMindPushToken"), object: nil)
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        Task { @MainActor in
            SocialPushCoordinator.pending = info
            NotificationCenter.default.post(name: Notification.Name("MatMindPushOpen"), object: nil)
        }
        completionHandler()
    }

    /// Show Mat Monkey pushes as banners while the app is open too, and refresh the feed behind them.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Task { @MainActor in NotificationCenter.default.post(name: Notification.Name("MatMindPushReceived"), object: nil) }
        completionHandler([.banner, .list, .sound])
    }
}
