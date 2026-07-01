import UIKit

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Re-register the reminder for returning users. First-run users get the notification
        // permission prompt contextually when they finish onboarding with the reminder on,
        // keeping the splash free of a premature system dialog.
        if UserDefaults.standard.bool(forKey: AppSessionStore.onboardingCompletedKey) {
            ReminderScheduler.shared.scheduleDefaultIfNeeded()
        }
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
}
