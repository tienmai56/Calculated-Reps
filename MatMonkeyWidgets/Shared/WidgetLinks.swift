import AppIntents
import Foundation

/// Where a widget tap lands in the app. Every destination is an existing screen or sheet.
/// Compiled into the app and the widget extension.
enum WidgetDestination: Equatable {
    /// Today's Quick Log sheet, or the "What are you logging?" chooser when today has a plan.
    case quickLog
    /// Stats › Progress, Your rhythm.
    case rhythm
    /// A session you host or accepted.
    case session(String)
    /// The Plan a training flow.
    case plan
    /// The app as it is (signed out, loading).
    case home

    private static let scheme = "matmind"
    private static let host = "widget"

    var url: URL {
        var c = URLComponents()
        c.scheme = Self.scheme
        c.host = Self.host
        switch self {
        case .quickLog: c.path = "/quick-log"
        case .rhythm: c.path = "/rhythm"
        case .session(let id): c.path = "/session"; c.queryItems = [URLQueryItem(name: "id", value: id)]
        case .plan: c.path = "/plan"
        case .home: c.path = "/home"
        }
        return c.url!
    }

    /// Only `matmind://widget/…`. Invitation and friend links keep their own parser.
    init?(url: URL) {
        guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
              c.scheme?.lowercased() == Self.scheme, c.host?.lowercased() == Self.host else { return nil }
        switch c.path {
        case "/quick-log": self = .quickLog
        case "/rhythm": self = .rhythm
        case "/plan": self = .plan
        case "/home": self = .home
        case "/session":
            guard let id = c.queryItems?.first(where: { $0.name == "id" })?.value, !id.isEmpty else { return nil }
            self = .session(id)
        default: return nil
        }
    }
}

/// Hand-off for the Log training button. Its App Intent opens the app; the request waits
/// in the App Group so a cold launch still lands on Quick Log.
enum WidgetLaunchRequest {
    static let notification = Notification.Name("MatMonkeyWidgetLaunch")
    private static let urlKey = "matmonkey.widget.launch.url"
    private static let dateKey = "matmonkey.widget.launch.date"
    /// Older requests are ignored, so a later plain launch doesn't jump into a sheet.
    static let lifetime: TimeInterval = 60

    static func post(_ destination: WidgetDestination, defaults: UserDefaults? = WidgetStore.defaults, now: Date = Date()) {
        defaults?.set(destination.url.absoluteString, forKey: urlKey)
        defaults?.set(now.timeIntervalSince1970, forKey: dateKey)
        NotificationCenter.default.post(name: notification, object: nil)
    }

    static func take(defaults: UserDefaults? = WidgetStore.defaults, now: Date = Date()) -> WidgetDestination? {
        guard let defaults, let raw = defaults.string(forKey: urlKey) else { return nil }
        let posted = Date(timeIntervalSince1970: defaults.double(forKey: dateKey))
        defaults.removeObject(forKey: urlKey)
        defaults.removeObject(forKey: dateKey)
        guard now.timeIntervalSince(posted) <= lifetime, now >= posted, let url = URL(string: raw) else { return nil }
        return WidgetDestination(url: url)
    }
}

/// The Log training button. It only opens the app; nothing is saved from the widget.
struct LogTrainingIntent: AppIntent {
    static var title: LocalizedStringResource = "Log training"
    static var description = IntentDescription("Opens Mat Monkey on today’s quick log. Nothing is posted.")
    static var openAppWhenRun: Bool = true
    static var isDiscoverable: Bool = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        WidgetLaunchRequest.post(.quickLog)
        return .result()
    }
}
