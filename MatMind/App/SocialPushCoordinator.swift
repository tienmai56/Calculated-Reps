import UIKit
import UserNotifications

/// The app's existing AppDelegate forwards APNs registration here. Registration
/// requires a verified cloud session; no local notebook identity is accepted.
@MainActor enum SocialPushCoordinator {
    static var token: String?
    static var pending: [AnyHashable:Any]?
    static func register(in app: SocialAppModel) async {
        guard app.userID != nil else { return }
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options:[.alert,.sound,.badge])
            guard granted else { return }
            UIApplication.shared.registerForRemoteNotifications()
            if let token {
                #if DEBUG
                let environment = "sandbox"
                #else
                let environment = "production"
                #endif
                _ = try await app.backend.command("register_device",payload:["token":token,"environment":environment])
            }
        } catch { app.error = "Could not register notifications: \(error.localizedDescription)" }
    }
}
