import UIKit
import UserNotifications

/// The app's existing AppDelegate forwards APNs registration here. Registration
/// requires a verified cloud session; no local notebook identity is accepted.
@MainActor enum SocialPushCoordinator {
    static var token: String?
    static var pending: [AnyHashable:Any]?
    /// The account the current token was last sent for, so launches don't resend it.
    private static var uploaded: (user: String, token: String)?

    /// Asks for permission (iOS shows the prompt only the first time) and registers with APNs.
    /// The token arrives later through the AppDelegate and is sent by `uploadToken`.
    static func register(in app: SocialAppModel) async {
        guard app.userID != nil else { return }
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options:[.alert,.sound,.badge])
            guard granted else { return }
            UIApplication.shared.registerForRemoteNotifications()
            await uploadToken(in: app)
        } catch { app.error = "Could not register notifications: \(error.localizedDescription)" }
    }

    static func uploadToken(in app: SocialAppModel) async {
        guard let user = app.userID, let token, uploaded?.user != user || uploaded?.token != token else { return }
        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif
        do {
            _ = try await app.backend.command("register_device",payload:["token":token,"environment":environment])
            uploaded = (user, token)
        } catch { app.error = "Could not register notifications: \(error.localizedDescription)" }
    }

    static func forget() { uploaded = nil }
}
