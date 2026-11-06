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
    /// Shown right after their name. nil until they build one.
    var monkey: MMMonkeyLook? = nil

    var firstName: String { name.split(separator: " ").first.map(String.init) ?? name }
    var avatar: MMAvatarPerson { MMAvatarPerson(name: name, photo: photo) }
}

/// Someone who trains with at least one of your training partners but isn't one yet.
/// `mutual` lists those shared partners, most connected first.
struct CirclePerson: Identifiable, Hashable {
    let id: String
    var mutual: [String]
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
    /// The recorded posting time; nil for older comments without a timestamp.
    var createdAt: Date? = nil
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
    /// Start time text (e.g. "6:00 PM"). Live posts derive it from `occurredAt`.
    var time: String? = nil

    var timeText: String? {
        if let time { return time }
        guard let occurredAt else { return nil }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "h:mm a"
        return formatter.string(from: occurredAt)
    }
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
    var attended: Bool = false
}

enum TrainingCompletionStatus: String {
    case completed = "Completed"
}

struct SessionPhoto: Identifiable, Hashable {
    let id: String
    let author: String
    /// Nil while the private image is downloading; keep the author and slot visible.
    var source: String?
}

/// Present the sheet and its expected photo version as one immutable value.
/// Separate presentation/selection state can open a replacement as a new post.
struct ParticipantPhotoDraft: Identifiable {
    let id = UUID()
    let sessionID: String
    let replacingPhotoID: String?
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
    /// Saved session photos, including photos taken before publishing to Activity.
    var photos: [String] = []
    /// Nil for older servers/caches and legacy demo fixtures.
    var photoContributions: [SessionPhoto]? = nil

    var sessionPhotos: [SessionPhoto] {
        photoContributions ?? photos.map { SessionPhoto(id: $0, author: organizer, source: $0) }
    }

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

/// No session fields are delivered until this invitation is accepted.
struct TrainingInvitation: Identifiable, Hashable {
    let id: String
    let organizer: String
}

struct AppNotification: Identifiable, Hashable {
    enum Kind: String {
        case invite, joined, comment, published, like, friend, mention
        /// Someone shared a goal with you; `session` holds the shared goal's id.
        case goalShare = "goal_share"
        /// The owner updated a goal you've accepted; `session` holds its shared id.
        case goalUpdate = "goal_update"
    }

    let id: String
    var kind: Kind
    var who: String
    var session: String?
    var text: String = ""
    var quote: String?
    var photo: String?
    var time: String
    var unread = false

    /// `session` stores the entity id: a session, post, or shared goal depending on kind.
    var destination: Route? {
        Self.destination(kind: kind, entityID: kind == .friend ? who : session)
    }

    /// Shared by in-app rows, their thumbnails, and push notifications.
    static func destination(kind: Kind, entityID: String?) -> Route? {
        guard let id = entityID, !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        switch kind {
        case .invite, .joined: return .session(id: id)
        case .comment, .published, .like, .mention: return .post(id: id)
        case .friend: return .friend(id: id)
        case .goalShare, .goalUpdate: return .sharedGoal(id: id)
        }
    }
}

enum AppTab: String, CaseIterable {
    case activity, training, goals, profile
}

/// The two lists in Goals: your own, and the ones training partners shared with you.
enum GoalsSection: String {
    case mine, shared
}

/// Pushed screens. The tab bar only shows on the tab roots.
enum Route: Hashable {
    case post(id: String, menu: Bool = false, focus: Bool = false)
    case session(id: String)
    case create(past: Bool = false, friend: String? = nil, focus: [TrainingFocus] = [])
    case complete(id: String)
    /// A training partner's profile (the same screen as `.person`; kept for links and notifications).
    case friend(id: String)
    /// Friends now open from Profile instead of a tab.
    case friends
    case goal(id: String)
    /// A goal someone shared with you (an invitation, or one you accepted).
    case sharedGoal(id: String)
    case qr(scan: Bool = false)
    case notifications
    /// Search & discover people, opened from the Activity header.
    case people
    /// Someone who isn't your training partner (partners open `.friend`).
    case person(id: String)
    /// Someone's full training partner list, opened from their profile.
    case partners(of: String)
}

struct SessionDraft: Equatable {
    static let defaultTitle = "Jiu-Jitsu training"

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

    /// The suggested name for a session starting at `date`, in the device's time zone.
    static func suggestedTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE"
        let weekday = formatter.string(from: date)
        formatter.dateFormat = "h:mm a"
        return suggestedTitle(weekday: weekday, time: formatter.string(from: date))
    }

    /// True when `title` is one of the names we suggest, i.e. the host never renamed it,
    /// so it should follow the session's day and time when those change.
    static func isSuggestedTitle(_ title: String) -> Bool {
        ["Saturday open mat", "Sunday open mat", "Morning rolls", "Lunch rolls", "Evening rolls"]
            .contains(title.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Additional occurrences of an edited session. Exact local times remain independently editable.
    func scheduled(at starts: [Date], calendar: Calendar = .current) -> [SessionDraft] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        let minutes = Set(starts.compactMap { calendar.dateInterval(of: .minute, for: $0)?.start }).sorted()
        return minutes.map { start in
            var draft = self
            formatter.dateFormat = "EEE"; draft.day = formatter.string(from: start)
            formatter.dateFormat = "MMM"; draft.month = formatter.string(from: start)
            formatter.dateFormat = "h:mm a"; draft.time = formatter.string(from: start)
            draft.date = calendar.component(.day, from: start)
            draft.startsAt = start
            draft.timezone = calendar.timeZone.identifier
            if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                draft.title = Self.defaultTitle
            } else if Self.isSuggestedTitle(draft.title) {
                draft.title = Self.suggestedTitle(weekday: draft.day, time: draft.time)
            }
            return draft
        }
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
            if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { draft.title = Self.defaultTitle }
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
    /// The goal broken down into parts (grip, head position, …). Not steps: there is
    /// no order to follow and nothing to tick off. Each part has its own notes,
    /// one video link and any number of photos.
    var parts: [GoalPart] = []

    enum CodingKeys: String, CodingKey {
        case id, title, position, notes, links, photos, parts
    }

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

    /// One line for goal cards: the notes, or else the names of the parts.
    var cardPreview: String {
        if !notesPreview.isEmpty { return notesPreview }
        return parts.map(\.title).filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// Every photo file the goal owns, its own and its parts'.
    var allPhotos: [String] { photos + parts.flatMap(\.photos) }

    var hasReferenceContent: Bool {
        !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !links.isEmpty || !photos.isEmpty || parts.contains { !$0.isBlank }
    }
}

extension MatGoal {
    /// Goals saved before a field existed still decode: anything missing gets its default.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        position = try c.decodeIfPresent(String.self, forKey: .position) ?? ""
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        links = try c.decodeIfPresent([String].self, forKey: .links) ?? []
        photos = try c.decodeIfPresent([String].self, forKey: .photos) ?? []
        parts = try c.decodeIfPresent([GoalPart].self, forKey: .parts) ?? []
    }
}

/// A goal a training partner shared with you. It's read-only and follows the
/// owner's saved edits. `pending` until you accept or decline it; declined goals
/// leave the list. Photos are displayable sources (sample asset names or local files).
struct SharedGoal: Identifiable, Hashable {
    enum Status: String { case pending, accepted }

    /// The shared copy's id (the same on every device).
    let id: String
    /// Who shared it (a person id).
    var owner: String
    var title: String
    var notes: String = ""
    var links: [String] = []
    var photos: [String] = []
    var parts: [GoalPart] = []
    var status: Status = .pending
    /// When it was shared with you, when known.
    var sharedAt: Date? = nil

    /// The same content as a goal, for the read-only views and card previews.
    var content: MatGoal {
        MatGoal(id: id, title: title, notes: notes, links: links, photos: photos, parts: parts)
    }

    /// "3 parts · 1 video · 4 photos · 2 links": what's inside, for invitations.
    var contentsSummary: String {
        let videos = parts.filter { !$0.link.isEmpty }.count
        let photoCount = photos.count + parts.reduce(0) { $0 + $1.photos.count }
        var bits: [String] = []
        if !parts.isEmpty { bits.append(parts.count == 1 ? "1 part" : "\(parts.count) parts") }
        if videos > 0 { bits.append(videos == 1 ? "1 video" : "\(videos) videos") }
        if photoCount > 0 { bits.append(photoCount == 1 ? "1 photo" : "\(photoCount) photos") }
        if !links.isEmpty { bits.append(links.count == 1 ? "1 link" : "\(links.count) links") }
        return bits.joined(separator: " · ")
    }
}

/// One part of a goal, e.g. "Grip on the near leg" under "Single leg from standing".
struct GoalPart: Identifiable, Hashable, Codable {
    var id: String
    var title: String = ""
    /// Free-form notes.
    var notes: String = ""
    /// One reference video (usually YouTube). Empty when there isn't one.
    var link: String = ""
    /// Paths relative to `MatGoal.photoRoot` (asset names in the preview).
    var photos: [String] = []

    init(id: String = GoalPart.newID(), title: String = "", notes: String = "", link: String = "", photos: [String] = []) {
        self.id = id
        self.title = title
        self.notes = notes
        self.link = link
        self.photos = photos
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? GoalPart.newID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        link = try c.decodeIfPresent(String.self, forKey: .link) ?? ""
        photos = try c.decodeIfPresent([String].self, forKey: .photos) ?? []
    }

    static func newID() -> String { "p" + UUID().uuidString.lowercased() }

    /// Nothing typed or added at all; such parts are dropped on save.
    var isBlank: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && link.isEmpty && photos.isEmpty
    }

    /// "2 notes · 1 video · 3 photos" for a closed part card.
    static func summary(notes: String, hasLink: Bool, photoCount: Int) -> String {
        var bits: [String] = []
        let lines = notes.split(whereSeparator: \.isNewline)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        if lines > 0 { bits.append(lines == 1 ? "1 note" : "\(lines) notes") }
        if hasLink { bits.append("1 video") }
        if photoCount > 0 { bits.append(photoCount == 1 ? "1 photo" : "\(photoCount) photos") }
        return bits.isEmpty ? "Nothing added yet" : bits.joined(separator: " · ")
    }

    /// "YouTube video", or the site's name for other links.
    static func linkTitle(_ link: String) -> String {
        guard let host = URL(string: link)?.host?.lowercased() else { return link }
        if host.hasSuffix("youtube.com") || host == "youtu.be" { return "YouTube video" }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// The start time in a video link (`t=102`, `t=1m42s`, `start=102`) as "1:42", or nil.
    static func linkStart(_ link: String) -> String? {
        guard let items = URLComponents(string: link)?.queryItems,
              let raw = items.first(where: { $0.name == "t" || $0.name == "start" })?.value?.lowercased(),
              !raw.isEmpty else { return nil }
        var seconds = 0
        if let plain = Int(raw.hasSuffix("s") ? String(raw.dropLast()) : raw) {
            seconds = plain
        } else {
            var number = ""
            for ch in raw {
                if ch.isNumber { number.append(ch); continue }
                guard let n = Int(number) else { return nil }
                switch ch {
                case "h": seconds += n * 3600
                case "m": seconds += n * 60
                case "s": seconds += n
                default: return nil
                }
                number = ""
            }
            guard number.isEmpty else { return nil }
        }
        guard seconds > 0 else { return nil }
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
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

struct QuickLogTechnique: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String

    static let defaults = [
        QuickLogTechnique(id: "heel-hook", name: "Heel hook"),
        QuickLogTechnique(id: "back-take", name: "Back take"),
        QuickLogTechnique(id: "armbar", name: "Armbar")
    ]
}

/// A name snapshot keeps saved reps intact when the usual list changes later.
struct QuickLogHit: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var count: Int
}

/// Private training marker, deliberately unrelated to sessions and posts.
struct QuickLog: Identifiable, Hashable {
    var id: String
    var loggedOn: String
    var loggedAt: Date
    var timezone: String

    /// Postgres serializes UUIDs in lowercase; local details use the same key.
    /// Keep non-UUID preview identifiers unchanged.
    static func canonicalID(_ id: String) -> String {
        UUID(uuidString: id)?.uuidString.lowercased() ?? id
    }
}

enum TrainingCalendar {
    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current; c.firstWeekday = 2; c.minimumDaysInFirstWeek = 4
        return c
    }
    static func key(_ date: Date, timezone: TimeZone = .current) -> String {
        let f = DateFormatter(); f.calendar = calendar; f.timeZone = timezone
        f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
    static func week(_ date: Date) -> [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: date)!.start
        return (0..<7).map { calendar.date(byAdding: .day, value: $0, to: start)! }
    }
    static func matches(_ log: QuickLog, session: Session) -> Bool {
        guard let start = session.startsAt else { return false }
        return log.loggedOn == key(start, timezone: TimeZone(identifier: log.timezone) ?? .current) && abs(log.loggedAt.timeIntervalSince(start)) <= 3 * 3600
    }
}

enum TrainingTap: Equatable { case disabled, choose, entries, quickLog }

/// Read-only session metadata for the private Profile calendar. This is not a new log type.
struct RhythmSession: Codable, Equatable, Identifiable {
    struct Participation: Codable, Equatable {
        var user_id: String
        var rsvp: String
        var attended: Bool
    }
    var id: String
    var starts_at: String
    var status: String
    var organizer: String
    var session_participants: [Participation]

    var start: Date? {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: starts_at) ?? ISO8601DateFormatter().date(from: starts_at)
    }
    func loggedDate(for owner: String, now: Date) -> Date? {
        guard ["planned", "completed"].contains(status), let start, start <= now,
              let mine = session_participants.first(where: { $0.user_id == owner }), mine.rsvp == "going",
              status != "completed" || mine.attended else { return nil }
        return start
    }
}

/// Monday–Sunday calendar days, independent of posts and their optional photos.
struct ProfileRhythmHistory {
    let calendar: Calendar
    let now: Date
    let weeks: [[Date]]
    let trained: Set<Date>

    init(dates: [Date], now: Date = Date(), calendar: Calendar = .current) {
        var c = calendar; c.firstWeekday = 2; c.minimumDaysInFirstWeek = 4
        self.calendar = c; self.now = now
        let currentMonday = c.dateInterval(of: .weekOfYear, for: now)!.start
        weeks = (-16...0).map { offset in
            let monday = c.date(byAdding: .weekOfYear, value: offset, to: currentMonday)!
            return (0..<7).map { c.date(byAdding: .day, value: $0, to: monday)! }
        }
        trained = Set(dates.filter { $0 <= now }.map { c.startOfDay(for: $0) })
    }
    func isTrained(_ date: Date) -> Bool { trained.contains(calendar.startOfDay(for: date)) }
    func isFuture(_ date: Date) -> Bool { calendar.startOfDay(for: date) > calendar.startOfDay(for: now) }
    var visibleCount: Int { weeks.flatMap { $0 }.filter(isTrained).count }
}
