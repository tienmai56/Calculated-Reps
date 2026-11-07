import Foundation

/// What the app hands its home-screen widgets. The app writes it into the shared
/// App Group after every sync, save, Undo and sign-out; widgets only read it.
/// Compiled into the app and the widget extension.
struct WidgetSnapshot: Codable, Equatable {
    static let currentVersion = 1

    var version = WidgetSnapshot.currentVersion
    var signedIn: Bool
    /// When the app last had fresh data. Shown as "As of …" once it is stale.
    var updatedAt: Date
    var rhythm: Rhythm?
    /// Soonest first: sessions you host or accepted that haven't ended. A few are kept so
    /// the widget can move on at each end time without waiting for the app.
    var sessions: [Session] = []
    /// First name of a host whose invitation is waiting. Never any session details.
    var invitationHost: String?

    struct Rhythm: Codable, Equatable {
        /// False on accounts whose backend doesn't support Quick Log yet: no Log button.
        var quickLogAvailable: Bool
        /// Entries per local day, keyed "yyyy-MM-dd". Quick logs plus past sessions you
        /// hosted or joined: the same entries behind the app's ×N day badges.
        var entries: [String: Int]
    }

    struct Session: Codable, Equatable, Identifiable {
        var id: String
        var title: String
        var venue: String
        var start: Date
        /// Sessions have no end time yet, so the app sends start + 2h.
        var end: Date
        var hostedByMe: Bool
        var hostName: String
        var hostHue: String
        /// Everyone going except you, host first.
        var partners: [Partner]
        var cancelled = false
        var cancelledBy: String?
    }

    struct Partner: Codable, Equatable {
        var firstName: String
        var initials: String
        var hue: String
    }

    static let signedOut = WidgetSnapshot(signedIn: false, updatedAt: .distantPast)
}

// MARK: - Store

enum WidgetStore {
    static let appGroup = "group.com.tienmai.intentionaltrainingnotes"
    static let key = "matmonkey.widget.snapshot"
    static let rhythmKind = "MatMonkeyRhythm"
    static let nextSessionKind = "MatMonkeyNextSession"

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func read(from defaults: UserDefaults? = WidgetStore.defaults) -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: key),
              let snapshot = try? decoder.decode(WidgetSnapshot.self, from: data),
              snapshot.version == WidgetSnapshot.currentVersion else { return nil }
        return snapshot
    }

    /// Returns true when the stored snapshot changed, so callers reload widgets only then.
    @discardableResult
    static func write(_ snapshot: WidgetSnapshot, to defaults: UserDefaults? = WidgetStore.defaults) -> Bool {
        guard let defaults, let data = try? encoder.encode(snapshot) else { return false }
        if let old = defaults.data(forKey: key), let previous = try? decoder.decode(WidgetSnapshot.self, from: old),
           previous.withoutTimestamp == snapshot.withoutTimestamp {
            // Same content: keep the newer timestamp without waking the widgets.
            defaults.set(data, forKey: key)
            return false
        }
        defaults.set(data, forKey: key)
        return true
    }

    private static var encoder: JSONEncoder { let e = JSONEncoder(); e.dateEncodingStrategy = .secondsSince1970; return e }
    private static var decoder: JSONDecoder { let d = JSONDecoder(); d.dateDecodingStrategy = .secondsSince1970; return d }
}

private extension WidgetSnapshot {
    var withoutTimestamp: WidgetSnapshot { var copy = self; copy.updatedAt = .distantPast; return copy }
}

// MARK: - Calendar math shared by the app, the widgets and tests

enum WidgetCalendar {
    /// Monday-first weeks, matching Stats › Your rhythm.
    static func calendar(_ base: Calendar = .current) -> Calendar {
        var c = base; c.firstWeekday = 2; c.minimumDaysInFirstWeek = 4; return c
    }

    static func key(_ date: Date, calendar: Calendar = WidgetCalendar.calendar()) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// `count` Monday–Sunday weeks ending with the current one, oldest first.
    static func weeks(_ count: Int, endingAt now: Date, calendar: Calendar = WidgetCalendar.calendar()) -> [[Date]] {
        let monday = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        return (0..<count).reversed().map { back in
            let start = calendar.date(byAdding: .day, value: -7 * back, to: monday)!
            return (0..<7).map { calendar.date(byAdding: .day, value: $0, to: start)! }
        }
    }
}

/// The numbers Your rhythm shows, worked out at render time so a new month or day
/// is right even if the app hasn't opened since.
struct RhythmSummary: Equatable {
    var sessionsThisMonth: Int
    var daysThisMonth: Int
    var today: Int

    init(entries: [String: Int], now: Date, calendar: Calendar = WidgetCalendar.calendar()) {
        let month = calendar.dateComponents([.year, .month], from: now)
        let todayKey = WidgetCalendar.key(now, calendar: calendar)
        var sessions = 0, days = 0
        for (key, count) in entries where count > 0 {
            let parts = key.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3, parts[0] == month.year, parts[1] == month.month, key <= todayKey else { continue }
            sessions += count; days += 1
        }
        sessionsThisMonth = sessions
        daysThisMonth = days
        today = entries[todayKey] ?? 0
    }
}

// MARK: - Next session selection and wording

enum NextSessionPicker {
    /// The session to show at `now`: the first that hasn't ended. A cancelled one is
    /// shown until its original start time, then skipped.
    static func current(_ sessions: [WidgetSnapshot.Session], at now: Date) -> WidgetSnapshot.Session? {
        sessions.sorted { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }
            .first { $0.cancelled ? $0.start > now : $0.end > now }
    }

    /// The one after `session`, named under a cancellation.
    static func following(_ session: WidgetSnapshot.Session, in sessions: [WidgetSnapshot.Session], at now: Date) -> WidgetSnapshot.Session? {
        sessions.filter { !$0.cancelled && $0.id != session.id && $0.start >= session.start && $0.end > now }
            .min { $0.start < $1.start }
    }

    /// Moments when what the widget shows changes on its own: starts, ends, cancellations
    /// expiring and midnights (Today/Tomorrow labels).
    static func boundaries(_ sessions: [WidgetSnapshot.Session], after now: Date, calendar: Calendar = .current) -> [Date] {
        var dates = Set<Date>()
        for s in sessions {
            dates.insert(s.start)
            if !s.cancelled { dates.insert(s.end) }
        }
        var midnight = calendar.startOfDay(for: now)
        for _ in 0..<3 {
            midnight = calendar.date(byAdding: .day, value: 1, to: midnight)!
            dates.insert(midnight)
        }
        return dates.filter { $0 > now }.sorted()
    }
}

enum WidgetWording {
    /// Today, Tomorrow, a weekday within 6 days, else "Sat, Nov 21".
    static func relativeDay(_ date: Date, now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let start = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case 2...6:
            let f = DateFormatter(); f.calendar = calendar; f.locale = locale; f.timeZone = calendar.timeZone
            f.setLocalizedDateFormatFromTemplate("EEEE"); return f.string(from: date)
        default:
            let f = DateFormatter(); f.calendar = calendar; f.locale = locale; f.timeZone = calendar.timeZone
            f.setLocalizedDateFormatFromTemplate("EEE MMM d"); return f.string(from: date)
        }
    }

    /// A clock time in the phone's 12/24-hour setting, never "in 2h".
    static func time(_ date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let f = DateFormatter(); f.calendar = calendar; f.locale = locale; f.timeZone = calendar.timeZone
        f.dateStyle = .none; f.timeStyle = .short
        return f.string(from: date)
    }

    static func stub(_ date: Date, calendar: Calendar = .current, locale: Locale = .current) -> (day: String, date: String, month: String) {
        let f = DateFormatter(); f.calendar = calendar; f.locale = locale; f.timeZone = calendar.timeZone
        f.setLocalizedDateFormatFromTemplate("EEE"); let day = f.string(from: date).uppercased()
        f.setLocalizedDateFormatFromTemplate("MMM"); let month = f.string(from: date)
        return (day, String(calendar.component(.day, from: date)), month)
    }

    /// "with Sarah", "with Kenji & Lena", "with Sarah, Alex & Priya", "with Sarah, Alex +5".
    static func partners(_ names: [String]) -> String {
        switch names.count {
        case 0: return "Just you. The mat’s all yours."
        case 1: return "with \(names[0])"
        case 2: return "with \(names[0]) & \(names[1])"
        case 3: return "with \(names[0]), \(names[1]) & \(names[2])"
        default: return "with \(names[0]), \(names[1]) +\(names.count - 2)"
        }
    }

    static func sessions(_ count: Int) -> String { count == 1 ? "session" : "sessions" }
    static func days(_ count: Int) -> String { count == 1 ? "day" : "days" }
}
