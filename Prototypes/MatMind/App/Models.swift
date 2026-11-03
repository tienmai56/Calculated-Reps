import Foundation

struct Person: Identifiable, Hashable {
    let id: String
    var name: String
    var belt: BeltRank
    var stripes: Int
    var gym: String
    var hue: FriendHue
    var photo: String?
    var email: String?
    var username: String = ""

    var firstName: String { name.split(separator: " ").first.map(String.init) ?? name }
    var avatar: MMAvatarPerson { MMAvatarPerson(name: name, photo: photo) }
}

/// A friendship's weekly streak. `weeks` holds the last completed calendar
/// weeks, oldest to newest; `thisWeek` is the current Mon–Sun week.
struct Friendship: Identifiable, Hashable {
    let id: String
    var weeks: [Bool]
    var thisWeek: MMWeekState
    var best: Int
    var together: Int
    var brokeAgo: String?
    var currentStreak: Int? = nil

    /// Consecutive completed weeks ending now (this week counts once it's done).
    var streak: Int {
        if let currentStreak { return currentStreak }
        var n = 0
        for done in weeks.reversed() {
            if done { n += 1 } else { break }
        }
        return n + (thisWeek == .done ? 1 : 0)
    }
}

struct Comment: Identifiable, Hashable {
    let id = UUID()
    var who: String
    var text: String
    var fresh = false
    /// The cloud comment's ID (live only), used for reporting.
    var cloudID: String?
}

struct Post: Identifiable, Hashable {
    let id: String
    var organizer: String
    var title: String
    var gym: String
    var date: String
    var ago: String
    var photo: String?
    var participants: [String]
    var caption: String
    var likes: [String]
    var extraLikes: Int
    var comments: [Comment]
    var focusItems: [TrainingFocus] = []
    /// When the session happened, when known (live posts). Preview posts only have `date` text.
    var occurredAt: Date? = nil
}

enum RSVP: String {
    case going, invited, declined

    var badge: (variant: MMBadgeVariant, label: String) {
        switch self {
        case .going: (.success, "Going")
        case .invited: (.warning, "Invited")
        case .declined: (.neutral, "Declined")
        }
    }
}

enum Privacy: String {
    case friends, link
}

struct Attendee: Hashable {
    var id: String
    var status: RSVP
}

struct Session: Identifiable, Hashable {
    let id: String
    var title: String
    var day: String
    var date: Int
    var month: String
    var time: String
    var gym: String
    var organizer: String
    var privacy: Privacy = .friends
    var people: [Attendee]
    var note: String?
    var focusItems: [TrainingFocus] = []
    /// The exact start, when known (live sessions). Preview sessions only have day/month/time text.
    var startsAt: Date? = nil

    func status(of id: String) -> RSVP? { people.first { $0.id == id }?.status }

    mutating func set(_ id: String, _ status: RSVP) {
        if let i = people.firstIndex(where: { $0.id == id }) {
            people[i].status = status
        } else {
            people.append(Attendee(id: id, status: status))
        }
    }

    var going: [String] { people.filter { $0.status == .going }.map(\.id) }
}

struct AppNotification: Identifiable, Hashable {
    enum Kind: String { case invite, joined, comment, published, like, friend, mention }

    let id: String
    var kind: Kind
    var who: String
    var session: String?
    var text: String = ""
    var quote: String?
    var photo: String?
    var time: String
    var unread = false
}

enum AppTab: String, CaseIterable {
    case activity, training, goals, profile
}

/// Pushed screens. The tab bar only shows on the tab roots.
enum Route: Hashable {
    case post(id: String, menu: Bool = false, focus: Bool = false)
    case session(id: String)
    case create(past: Bool = false, friend: String? = nil, focus: [TrainingFocus] = [])
    case complete(id: String)
    case friend(id: String)
    /// Friends now open from Profile instead of a tab.
    case friends
    case goal(id: String)
    case qr(scan: Bool = false)
    case notifications
}

struct SessionDraft: Equatable {
    var title: String
    var day: String
    var date: Int
    var month: String
    var time: String
    var gym: String
    var note: String
    var invited: [String]
    var privacy: Privacy
    var past: Bool
    var focusItems: [TrainingFocus] = []
    var startsAt: Date? = nil
    var timezone: String = TimeZone.current.identifier

    static func suggestedTitle(weekday: String, time: String) -> String {
        if weekday == "Sat" { return "Saturday open mat" }
        if weekday == "Sun" { return "Sunday open mat" }
        if time.contains("AM") { return "Morning rolls" }
        if time.hasPrefix("12") { return "Lunch rolls" }
        return "Evening rolls"
    }

    /// One independent session per local calendar day, all at the chosen wall-clock time.
    func scheduled(on dates: [Date], calendar: Calendar = .current) -> [SessionDraft] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "h:mm a"
        formatter.isLenient = false
        guard let clock = formatter.date(from: time) else { return [] }
        let components = calendar.dateComponents([.hour, .minute], from: clock)
        let days = Set(dates.map { calendar.startOfDay(for: $0) }).sorted()
        return days.compactMap { day in
            guard let start = calendar.date(bySettingHour: components.hour ?? 0, minute: components.minute ?? 0, second: 0, of: day) else { return nil }
            var draft = self
            formatter.dateFormat = "EEE"; draft.day = formatter.string(from: day)
            formatter.dateFormat = "MMM"; draft.month = formatter.string(from: day)
            draft.date = calendar.component(.day, from: day)
            if draft.title.isEmpty { draft.title = Self.suggestedTitle(weekday: draft.day, time: time) }
            draft.startsAt = start
            draft.timezone = calendar.timeZone.identifier
            return draft
        }
    }
}

/// Kept by the form across retries so a lost response cannot create the same day twice.
struct SessionCreationRequest: Identifiable {
    let id: UUID
    let draft: SessionDraft

    init(draft: SessionDraft, id: UUID = UUID()) {
        self.id = id
        self.draft = draft
    }
}

struct StreakTick: Identifiable {
    var id: String
    var from: Int
    var to: Int
    var friendship: Friendship
}

struct PublishResult {
    var post: Post
    var streaks: [StreakTick]
}

/// Something you're working on for your own game, e.g. "Single leg from standing".
/// Goals are personal: they live on this device and are attached to sessions
/// only in your own schedule. There is no scoring or completion tracking.
struct MatGoal: Identifiable, Hashable, Codable {
    var id: String
    var title: String
    /// Where it happens on the mat. No longer shown or edited; kept so goals saved
    /// by earlier builds still decode.
    var position: String = ""
    /// Free-form notes; a line starting with "-" reads as a bullet.
    var notes: String = ""
    /// Reference links (instructionals, videos).
    var links: [String] = []
    /// Reference photos: asset names in the preview, or paths relative to `photoRoot`.
    var photos: [String] = []

    /// Private folder for goal photos (relative paths survive app updates moving the container).
    static var photoRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MatMonkeysGoalPhotos", isDirectory: true)
    }

    static func new() -> MatGoal {
        MatGoal(id: "g\(Int(Date().timeIntervalSince1970 * 1000))", title: "")
    }

    /// A stored photo reference as something `MMPhoto` can show: imported files live under `photoRoot`.
    static func photoSource(_ photo: String) -> String {
        let file = photoRoot.appendingPathComponent(photo)
        return FileManager.default.fileExists(atPath: file.path) ? file.path : photo
    }

    /// Notes collapsed to one line for card previews.
    var notesPreview: String {
        notes.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .map { $0.hasPrefix("-") ? String($0.dropFirst()).trimmingCharacters(in: .whitespaces) : $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

/// Shared grammar with emit_mentions in Postgres. Ranges use UTF-16 because
/// NSRegularExpression and text replacement must also work after emoji.
enum UsernameMention {
    static func pendingRange(in text: String) -> NSRange? {
        let regex = try! NSRegularExpression(pattern: #"(?<![a-z0-9_@.+-])@[a-z0-9_]{0,40}$"#, options: [.caseInsensitive])
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))?.range
    }

    static func query(in text: String) -> String? {
        guard let range = pendingRange(in: text), let swiftRange = Range(range, in: text) else { return nil }
        return String(text[swiftRange].dropFirst()).lowercased()
    }

    static func inserting(_ username: String, in text: String) -> String {
        guard let range = pendingRange(in: text), let swiftRange = Range(range, in: text) else { return text }
        return text.replacingCharacters(in: swiftRange, with: "@" + username + " ")
    }

    static func ranges(in text: String) -> [NSRange] {
        let regex = try! NSRegularExpression(pattern: #"(?<![a-z0-9_@.+-])@([a-z0-9_]{3,40})(?![a-z0-9_@])"#, options: [.caseInsensitive])
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).map(\.range)
    }
}
