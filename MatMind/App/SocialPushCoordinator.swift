import os
import UIKit
import UserNotifications

/// The app's existing AppDelegate forwards APNs registration here. Registration
/// requires a verified cloud session; no local notebook identity is accepted.
@MainActor enum SocialPushCoordinator {
    static var token: String?
    static var pending: [AnyHashable:Any]?
    /// The account the current token was last sent for, so launches don't resend it.
    private static var uploaded: (user: String, token: String)?
    /// True while a registration the person asked for (the Enable notifications button)
    /// is waiting on APNs, so a late failure can be shown to them instead of only logged.
    private static var userRequested = false
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MatMind", category: "push")

    static let permissionOffMessage = "Notifications are off for Mat Monkey. Turn them on in Settings › Notifications so you don’t miss an invite to train."

    /// Asks for permission (iOS shows the prompt only the first time) and registers with APNs.
    /// The token arrives later through the AppDelegate and is sent by `uploadToken`.
    /// Automatic launches stay quiet when push is unavailable; `userInitiated` requests
    /// explain why, since iOS never shows the prompt again after someone declines it
    /// (including people who declined the old notebook's reflection reminders).
    static func register(in app: SocialAppModel, userInitiated: Bool = false) async {
        guard app.userID != nil else { return }
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options:[.alert,.sound,.badge])
            guard granted else {
                log.notice("Push not registered: notification permission is off")
                if userInitiated { app.error = permissionOffMessage }
                return
            }
            // A token from an earlier registration means APNs already accepted this device.
            userRequested = userInitiated && token == nil
            UIApplication.shared.registerForRemoteNotifications()
            await uploadToken(in: app)
        } catch {
            log.error("Push permission request failed: \(error.localizedDescription, privacy: .public)")
            app.error = "Could not register notifications: \(error.localizedDescription)"
        }
    }

    static func uploadToken(in app: SocialAppModel) async {
        guard let user = app.userID, let token else { return }
        userRequested = false
        guard uploaded?.user != user || uploaded?.token != token else { return }
        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif
        do {
            _ = try await app.backend.command("register_device",payload:["token":token,"environment":environment])
            uploaded = (user, token)
            log.info("Push token registered (\(environment, privacy: .public))")
        } catch {
            log.error("Push token upload failed: \(error.localizedDescription, privacy: .public)")
            app.error = "Could not register notifications: \(error.localizedDescription)"
        }
    }

    /// APNs refused to register this device (no network, missing push entitlement,
    /// or a provisioning profile without Push Notifications). Always logged; shown
    /// to the person only when they asked to enable notifications.
    static func registrationFailed(_ message: String, in app: SocialAppModel) {
        log.error("APNs registration failed: \(message, privacy: .public)")
        guard userRequested else { return }
        userRequested = false
        app.error = "Could not register notifications: \(message)"
    }

    static func forget() { uploaded = nil; userRequested = false }
}
