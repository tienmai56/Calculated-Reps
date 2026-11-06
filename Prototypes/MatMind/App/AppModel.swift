import Observation
import SwiftUI

/// Live services are supplied by the installed app; the preview keeps its demo adapter.
@MainActor
protocol AppRuntime: AnyObject {
    var busy: Bool { get }
    func authenticate() async
    func signOut() async
    func perform(_ operation: String, _ payload: [String: Any]) async -> Bool
    /// Someone's training partners, or nil when you can't see their list.
    func partners(of personID: String) async -> [Person]?
    func searchUsernames(_ query: String) async throws -> [Person]
    /// Asks for push permission and registers this device. Returns nil on success, or the
    /// message to show, so a caller inside a sheet can display it (the app-level alert sits under sheets).
    func enableNotifications() async -> String?
    func create(_ draft: SessionDraft, key: UUID) async -> String?
    func saveSessionPhoto(_ sessionID: String, photo: String) async -> Bool
    func publish(_ sessionID: String, photo: String?, caption: String, people: [String]) async -> PublishResult?
    /// Uploads a square JPEG (from `AppModel.avatarJPEG`) and makes it the signed-in member's profile photo.
    func saveAvatar(_ jpeg: Data) async -> Bool
    func friendCode() async -> String?
    func connect(_ value: String) async -> String?
    func sessionInvitationURL(_ sessionID: String) async -> URL?
    func copySessionLink(_ sessionID: String) async
    func saveFocus(_ sessionID: String, _ items: [TrainingFocus]) async -> Bool
    func editSession(_ sessionID: String, title: String, startsAt: Date, gym: String, note: String,
                     focusItems: [TrainingFocus], addedGuests: [String], removedGuests: [String]) async -> Bool
    /// Creates or updates the shared copy of one of your goals (photos included) and
    /// returns its id. Recipients see whatever was published last.
    func publishGoal(_ goal: MatGoal) async -> String?
    /// Copies a link to a shared goal. Anyone with an account who opens it gets an invitation.
    func copyGoalLink(_ sharedID: String) async -> Bool
    func scannerView(found: @escaping (String) -> Void) -> AnyView
    func exportView() -> AnyView
}

/// Shared UI state. Live models start empty; only an explicit preview model loads fixtures.
@MainActor
@Observable
final class AppModel {
    var runtime: (any AppRuntime)?
#if DEBUG
    var previewAction: (() -> Void)?

    /// A separate local model: entering review mode never authenticates the live app.
    static func uiReviewPreview() -> AppModel {
        let preview = AppModel(live: false)
        preview.enterDemo()
        return preview
    }
#endif
#if DEBUG || MAT_MIND_PROTOTYPE
    private(set) var quickLogMockScenario: QuickLogMockScenario = .hostPlan
    private(set) var quickLogMockRevision = UUID()

    static func quickTrainingLogMock(_ scenario: QuickLogMockScenario = .upcomingPrompt) -> AppModel {
        let model = AppModel(live: false)
        model.loadQuickLogMock(scenario)
        return model
    }

    /// UI-only fixtures can never replace or use a live account/runtime.
    func loadQuickLogMock(_ scenario: QuickLogMockScenario, now: Date = Date()) {
        guard !isLive, runtime == nil else { return }
        let techniqueAccount = quickLogAccount
        let techniqueDefaults = quickLogDefaults
        reset()
        if let techniqueAccount { loadQuickLogTechniques(account: techniqueAccount, defaults: techniqueDefaults) }
        quickLogMockRevision = UUID()
        quickLogMockScenario = scenario
        upcoming = SeedData.quickLogMockPlans(scenario, now: now)
        quickLogs = SeedData.quickLogMockLogs(scenario, now: now)
        if scenario == .quickLogs {
            quickLogHitsByID.merge(SeedData.quickLogMockTodayHits) { _, sample in sample }
        }
        if scenario == .techniqueStats {
            let samples = SeedData.quickLogMockTechniques(now: now)
            quickLogs += samples.logs
            quickLogHitsByID.merge(samples.hits) { _, sample in sample }
        }
        let shared = SeedData.quickLogMockShared(now: now)
        completedSessions = [shared.session] + SeedData.quickLogMockCompleted(now: now)
        sharedSessionIDs = [shared.session.id]
        toComplete = nil
        notifications = []
        posts = [shared.post] + SeedData.posts.enumerated().map { index, source in
            var post = source
            let date = TrainingCalendar.calendar.date(byAdding: .day, value: -(index + 1), to: now)!
            post.date = date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            post.ago = index == 0 ? "Yesterday" : "\(index + 1)d"
            post.occurredAt = date
            return post
        }
        monkeyPromptAnswered = true
        isSignedIn = true
        setTab(scenario == .techniqueStats || scenario == .noQuickLogs ? .profile : .activity)
    }

    /// Simulator-only time shortcut; no runtime or backend operation is used.
    func startMockPromptPlan(now: Date = Date()) {
        guard !isLive, runtime == nil, quickLogMockScenario == .upcomingPrompt,
              let session = findSession("mock-today"), trainingCompletionStatus(session) == nil else { return }
        let c = TrainingCalendar.calendar
        let start = max(c.startOfDay(for: now), now.addingTimeInterval(-60))
        updateSession(session.id) {
            $0.startsAt = start
            $0.day = start.formatted(.dateTime.weekday(.abbreviated))
            $0.date = c.component(.day, from: start)
            $0.month = start.formatted(.dateTime.month(.abbreviated))
            $0.time = start.formatted(.dateTime.hour().minute())
        }
    }
#endif
    let isLive: Bool
    /// Live quick logging stays off until the server exposes the deferred feature's snapshot fields.
    var quickTrainingLogBackendAvailable = false
    var quickTrainingLogEnabled: Bool { !isLive || quickTrainingLogBackendAvailable }
    var busy: Bool { creatingSessions || savingTraining || (runtime?.busy ?? false) }
    private(set) var creatingSessions = false
    private var createdSessions: [UUID: String] = [:]
    private var creationGeneration = UUID()

    init(live: Bool = true) {
#if DEBUG || MAT_MIND_PROTOTYPE
        isLive = live
#else
        isLive = true
#endif
        if !isLive { reset() }
    }

    func clearLiveData() {
        resetTrainingActions()
        quickLogs = []; sharedSessionIDs = []

        resetPeopleLookup()
        rhythmSessionDates = nil
        resetSessionCreation()
        me = Person(id: "me", name: "", belt: .white, stripes: 0, gym: "", hue: .coral)
        gyms = []; cameraRoll = []
        people = [:]; friends = []; circle = []; following = []; trainingInvitations = []; partnerLists = [:]; listedPeople = [:]; posts = []; upcoming = []; discoverableSessions = []; completedSessions = []; toComplete = nil
        notifications = []; drafts = []; path = []; toast = nil; highlight = nil; fresh = nil
        editingMonkey = false; monkeyPromptVisible = false; monkeyPromptAnswered = true; monkeyAccount = nil
        goals = []; sessionGoals = [:]; goalAccount = nil
        sharedGoals = []; sharedGoalIDs = [:]; goalRecipients = [:]; goalPublishes = [:]
        widgetQuickLogRequest = nil; widgetProfileSectionRequest = nil
    }

    private func send(_ operation: String, _ payload: [String: Any], success: (() -> Void)? = nil) {
        guard let runtime else { return }
        Task { if await runtime.perform(operation, payload) { success?() } }
    }

    // MARK: Data
    var me = Person(id: "me", name: "", belt: .white, stripes: 0, gym: "", hue: .coral)
    var people: [String: Person] = [:]
    var friends: [Friendship] = []
    /// People who train with your training partners, with the partners you share.
    var circle: [CirclePerson] = []
    /// Follow and QR scanning create mutual training partnerships for activity, invitations and note sharing.
    var following: Set<String> = []
    var trainingInvitations: [TrainingInvitation] = []
    var pendingTrainingInvitations: [TrainingInvitation] {
        let existing = Set(trainingInvitations.map(\.id))
        return trainingInvitations + upcoming.filter { $0.status(of: "me") == .invited && !existing.contains($0.id) }
            .map { TrainingInvitation(id: $0.id, organizer: $0.organizer) }
    }
    var feedPosts: [Post] {
        posts.filter { $0.organizer == "me" || following.contains($0.organizer) || $0.participants.contains("me") || $0.participants.contains { following.contains($0) } }
    }
    var invitees: [Person] { following.map(person).sorted { $0.name < $1.name } }
    func canInvite(_ id: String) -> Bool { id != "me" && following.contains(id) }
    /// Training partner lists loaded for profiles: person id → partner ids, your own partners first.
    var partnerLists: [String: [String]] = [:]
    /// People known only from a partner list (not your partners or in your circle).
    var listedPeople: [String: Person] = [:]
    /// Minimal profiles returned by an explicit username search, retained while opening a profile.
    private(set) var usernamePeople: [String: Person] = [:]
    private(set) var pendingFollows: Set<String> = []
    private var followGeneration = UUID()

    func resetPeopleLookup() {
        usernamePeople = [:]; pendingFollows = []; followGeneration = UUID()
    }
    var posts: [Post] = []
    var upcoming: [Session] = []
    var completedSessions: [Session] = []
    var sharedSessionIDs: Set<String> = []
    var quickLogs: [QuickLog] = []
    private(set) var quickLogTechniques = QuickLogTechnique.defaults
    private(set) var quickLogHitsByID: [String: [QuickLogHit]] = [:]
    private(set) var quickLogAccount: String?
    @ObservationIgnored private var quickLogDefaults = UserDefaults.standard
    var activityQuickLogPromptID: String?
    var trainingUndo: (() async -> Bool)?
    var trainingUndoToastID: UUID?
    var trainingUndoSessionID: String?
    private(set) var savingTraining = false
    private var trainingGeneration = UUID()

    func resetTrainingActions() {
        quickLogTechniques = QuickLogTechnique.defaults
        quickLogHitsByID = [:]
        quickLogAccount = nil
        activityQuickLogPromptID = nil
        quickTrainingLogBackendAvailable = false
        trainingGeneration = UUID()
        savingTraining = false
        trainingUndo = nil; trainingUndoToastID = nil; trainingUndoSessionID = nil
    }

    /// Full 17-week read, separate from the bounded Training list. nil uses the loaded session page.
    var rhythmSessionDates: [Date]? = nil
    /// Friends' open plans from Activity. They enter Training only after joining.
    var discoverableSessions: [Session] = []
    var toComplete: Session?
    var notifications: [AppNotification] = []
    var drafts: [Session] = []
    var gyms: [String] = []
    var cameraRoll: [String] = []
    /// What you're working on. Personal and local to this device.
    var goals: [MatGoal] = []
    /// Session id → goal id for sessions you've attached a goal to.
    var sessionGoals: [String: String] = [:]
    /// A goal waiting to be attached to the session being planned from its page.
    var pendingPlanGoal: String?
    /// Goals training partners shared with you: invitations and the ones you accepted.
    var sharedGoals: [SharedGoal] = []
    /// Your goal's id → the id of its shared copy, for goals you've shared.
    var sharedGoalIDs: [String: String] = [:]
    /// Shared copy id → who it's shared with and how they answered (person id → pending / accepted / declined).
    var goalRecipients: [String: [String: String]] = [:]
    /// Publishes of each goal, run one after another so the latest save always lands last.
    @ObservationIgnored private var goalPublishes: [String: Task<String?, Never>] = [:]
    /// The signed-in account whose goals are loaded (installed app only).
    @ObservationIgnored private var goalAccount: String?
    /// Reads an old-notebook export into goals. Supplied by the installed app, which
    /// owns the archive format; the shared preview has no importer.
    @ObservationIgnored var readGoalExport: (@Sendable (URL) throws -> [MatGoal])?
    var canImportGoals: Bool { readGoalExport != nil }

    // MARK: Navigation & feedback
    var tab: AppTab = .activity
    /// Which list Goals shows. Accepting a shared goal switches it to Shared.
    var goalsSection: GoalsSection = .mine
    var path: [Route] = []
    var toast: MMToastData?
    /// Post to highlight in the feed right after publishing.
    var highlight: String?
    /// "sessionId + personId" of the attendee row that just joined (plays the join animation).
    var fresh: String?
    var showDemoPanel = false
    /// Set by a widget's Log training tap; Activity's This week card opens today's Quick Log
    /// (or its planned-session chooser) and clears it.
    var widgetQuickLogRequest: UUID?
    /// Set by a Your rhythm widget tap; Profile switches to Progress and clears it.
    var widgetProfileSectionRequest: UUID?
    /// Prototype-only entry state; this is not a Google authentication session.
    var isSignedIn = false

    @ObservationIgnored private var timers: [Task<Void, Never>] = []

    // MARK: Lookups

    func person(_ id: String) -> Person {
        if id == "me" { return me }
        return people[id] ?? listedPeople[id] ?? usernamePeople[id] ?? Person(id: id, name: "Someone", belt: .white, stripes: 0, gym: "", hue: .coral)
    }

    func post(_ id: String) -> Post? { posts.first { $0.id == id } }

    func findSession(_ id: String) -> Session? {
        if let s = upcoming.first(where: { $0.id == id }) { return s }
        if let s = toComplete, s.id == id { return s }
        if let s = discoverableSessions.first(where: { $0.id == id }) { return s }
        return drafts.first(where: { $0.id == id }) ?? completedSessions.first(where: { $0.id == id })
    }

    func friendship(_ id: String) -> Friendship? { friends.first { $0.id == id } }

    /// Your training partners who also train with this person, most connected first.
    func mutualPartners(_ id: String) -> [String] { circle.first { $0.id == id }?.mutual ?? [] }

    func isFollowing(_ id: String) -> Bool { following.contains(id) }

    /// Username lookup lets you follow someone just as you would by scanning their code.
    func canFollow(_ id: String) -> Bool {
        id != "me" && (usernamePeople[id] != nil || isFollowing(id) || friendship(id) != nil || circle.contains { $0.id == id } || partnerLists.values.contains { $0.contains(id) })
    }

    static func usernameQuery(_ query: String) -> String {
        var value = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.hasPrefix("@") { value.removeFirst() }
        return value
    }

    static func canSearchUsername(_ query: String) -> Bool {
        let value = usernameQuery(query)
        return (3...40).contains(value.count) && value.utf8.allSatisfy { (97...122).contains($0) || (48...57).contains($0) || $0 == 95 }
    }

    func searchUsernames(_ query: String) async throws -> [Person] {
        guard Self.canSearchUsername(query) else { return [] }
        let value = Self.usernameQuery(query)
        let generation = followGeneration
        let found: [Person]
        if let runtime {
            found = try await runtime.searchUsernames(value)
        } else {
            guard !isLive else { return [] }
            found = people.values.filter { $0.id != "me" && $0.username.hasPrefix(value) }
                .sorted { $0.username < $1.username }
        }
        try Task.checkCancellation()
        guard generation == followGeneration else { throw CancellationError() }
        let matches = Array(found.filter { $0.id != "me" }.prefix(20))
        for p in matches { usernamePeople[p.id] = p }
        return matches
    }

    /// Loads (or refreshes) someone's training partner list into `partnerLists`.
    func loadPartners(of id: String) async {
        var list: [String]
        if let runtime {
            guard let found = await runtime.partners(of: id) else { partnerLists[id] = nil; return }
            for p in found where p.id != "me" && people[p.id] == nil { listedPeople[p.id] = p }
            list = found.map(\.id)
        } else {
            guard !isLive else { return }
#if DEBUG || MAT_MIND_PROTOTYPE
            list = SeedData.partnerLists[id] ?? []
#else
            list = []
#endif
        }
        func yours(_ p: String) -> Bool { p == "me" || friendship(p) != nil }
        partnerLists[id] = list.sorted { yours($0) != yours($1) ? yours($0) : person($0).name < person($1).name }
    }

    /// Suggested for you: everyone sharing at least one training partner with you, most shared partners first.
    var suggestedPeople: [Person] {
        circle.filter { !$0.mutual.isEmpty && people[$0.id] != nil && friendship($0.id) == nil }
            .sorted { $0.mutual.count != $1.mutual.count ? $0.mutual.count > $1.mutual.count : person($0.id).name < person($1.id).name }
            .map { person($0.id) }
    }

    /// Name search over your training partners and the people they train with.
    /// Matches the start of any word in the name, or the username.
    func searchPeople(_ query: String) -> [Person] {
        var q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.hasPrefix("@") { q.removeFirst() }
        guard !q.isEmpty else { return [] }
        let ids = Set(friends.map(\.id)).union(following).union(circle.filter { !$0.mutual.isEmpty }.map(\.id))
        func rank(_ p: Person) -> Int { friendship(p.id) != nil ? 1000 : mutualPartners(p.id).count }
        return ids.map(person)
            .filter { p in
                let name = p.name.lowercased()
                return name.hasPrefix(q) || name.split(separator: " ").contains { $0.hasPrefix(q) } || p.username.lowercased().hasPrefix(q)
            }
            .sorted { rank($0) != rank($1) ? rank($0) > rank($1) : $0.name < $1.name }
    }

    func goal(_ id: String) -> MatGoal? { goals.first { $0.id == id } }

    func sharedGoal(_ id: String) -> SharedGoal? { sharedGoals.first { $0.id == id } }

    /// Shared goals waiting for your answer, newest first.
    var goalInvites: [SharedGoal] {
        sharedGoals.filter { $0.status == .pending }.sorted { ($0.sharedAt ?? .distantPast) > ($1.sharedAt ?? .distantPast) }
    }

    /// Shared goals you accepted, newest first.
    var acceptedSharedGoals: [SharedGoal] {
        sharedGoals.filter { $0.status == .accepted }.sorted { ($0.sharedAt ?? .distantPast) > ($1.sharedAt ?? .distantPast) }
    }

    /// Who one of your goals is shared with (person id → pending / accepted / declined).
    func recipients(ofGoal goalID: String) -> [String: String] {
        sharedGoalIDs[goalID].flatMap { goalRecipients[$0] } ?? [:]
    }

    /// The goal you attached to a session, if it still exists.
    func goal(forSession sessionID: String) -> MatGoal? { sessionGoals[sessionID].flatMap { goal($0) } }

    /// The soonest planned session this goal is attached to.
    func nextSession(forGoal goalID: String) -> Session? {
        plannedSessions.first { sessionGoals[$0.id] == goalID }
    }

    /// Sessions you organized that have already happened but aren't shared yet, newest first.
    /// Every one of them can be completed, not just the most recent, so a logged past
    /// session always has a way into Activity.
    var readyToShare: [Session] {
        guard isLive else { return toComplete.map { [$0] } ?? [] }
        let now = Date()
        return upcoming.filter { $0.organizer == "me" && startDate(of: $0) <= now }
            .sorted { startDate(of: $0) > startDate(of: $1) }
    }

    func isReadyToShare(_ sessionID: String) -> Bool { readyToShare.contains { $0.id == sessionID } }

    /// Invitations and accepted future plans, soonest first.
    var plannedSessions: [Session] { trainingSessions(past: false) }

    /// Date, not publication or photo state, determines which Training tab owns a session.
    /// Label-only sample plans remain upcoming; draft and completion samples remain past.
    func trainingSessions(past: Bool, relativeTo now: Date = Date()) -> [Session] {
        let completedIDs = Set(completedSessions.map(\.id))
        let draftIDs = Set(drafts.map(\.id))
        var seen: Set<String> = []
        let sessions = upcoming + drafts + (toComplete.map { [$0] } ?? []) + completedSessions
        return sessions.filter { session in
            guard seen.insert(session.id).inserted,
                  session.status(of: "me") == .going || session.status(of: "me") == .invited else { return false }
            let elapsed = completedIDs.contains(session.id) || (session.startsAt.map { $0 <= now }
                ?? (draftIDs.contains(session.id) || session.id == toComplete?.id))
            return elapsed == past
        }.sorted {
            let first = startDate(of: $0), second = startDate(of: $1)
            return first == second ? $0.id < $1.id : (past ? first > second : first < second)
        }
    }

    func isCompleted(_ session: Session) -> Bool { completedSessions.contains { $0.id == session.id } }

    func trainingCompletionStatus(_ session: Session) -> TrainingCompletionStatus? {
        let current = findSession(session.id) ?? session
        if sharedSessionIDs.contains(current.id) || isCompleted(current)
            || current.people.contains(where: { $0.id == "me" && $0.attended }) { return .completed }
        return nil
    }

    /// The Training card action applies only to hosted past sessions with no attendance log or post.
    func canCompleteTraining(_ session: Session, now: Date = Date()) -> Bool {
        guard let current = findSession(session.id), current.organizer == "me",
              current.status(of: "me") == .going, trainingCompletionStatus(current) == nil else { return false }
        return trainingSessions(past: true, relativeTo: now).contains { $0.id == current.id }
    }

    /// Personal open plans remain in Activity until attendance is confirmed, including after their start.
    func activityPlans(at now: Date = Date()) -> [Session] {
        (upcoming + discoverableSessions)
            .filter { !isCompleted($0) && $0.status(of: "me") != .declined && ($0.organizer == "me" || $0.status(of: "me") == .going) && !$0.people.contains(where: { $0.id == "me" && $0.attended }) }
            .filter { quickTrainingLogEnabled || ($0.privacy == .link && startDate(of: $0) > now) }
            .sorted {
                let first = startDate(of: $0), second = startDate(of: $1)
                return first == second ? $0.id < $1.id : first < second
            }
    }

    /// Keep Activity tied to the nearest unshared session, on either side of now.
    /// Invitations and declined plans aren't training the member has committed to.
    func activityPrompt(at now: Date) -> Session? {
        var sessions = upcoming
        if let toComplete, !sessions.contains(where: { $0.id == toComplete.id }) {
            sessions.append(toComplete)
        }
        return sessions.filter { $0.organizer == "me" || $0.status(of: "me") == .going }
            .min {
                let first = startDate(of: $0), second = startDate(of: $1)
                let firstDistance = abs(first.timeIntervalSince(now))
                let secondDistance = abs(second.timeIntervalSince(now))
                if firstDistance != secondDistance { return firstDistance < secondDistance }
                // Prefer the past session on a tie, then keep equal-time rows stable.
                return first == second ? $0.id < $1.id : first < second
            }
    }

    /// Keep the selected plan after its start; day-only quick logs never complete a session.
    func quickLogActivityPrompt(keeping sessionID: String?, now: Date = Date()) -> Session? {
        let candidates = calendarSessions.filter {
            ($0.organizer == "me" || $0.status(of: "me") == .going)
                && $0.status(of: "me") != .declined && $0.status(of: "me") != .invited
                && trainingCompletionStatus($0) == nil
        }
        if let sessionID, let current = candidates.first(where: { $0.id == sessionID }) { return current }
        let future = candidates.filter { startDate(of: $0) >= now }
        return (future.isEmpty ? candidates : future).min {
            let a = startDate(of: $0), b = startDate(of: $1)
            let distanceA = abs(a.timeIntervalSince(now)), distanceB = abs(b.timeIntervalSince(now))
            return distanceA == distanceB ? $0.id < $1.id : distanceA < distanceB
        }
    }

    var unreadCount: Int { notifications.filter(\.unread).count }

    /// The Profile tab (home of Friends) shows a dot while any live streak still needs this week's session.
    /// Offer known partners only. The server independently checks visibility for
    /// every recipient, including blocks and changes made since this snapshot.
    func mentionCandidates(for post: Post? = nil, including attendees: [String] = []) -> [Person] {
        var ids = Set(attendees)
        if let post {
            ids.formUnion(post.participants)
            ids.insert(post.organizer)
            if post.participants.contains("me") || post.organizer == "me" {
                ids.formUnion(friends.map(\.id))
            }
        } else {
            ids.formUnion(friends.map(\.id))
        }
        return ids.filter { $0 != "me" }.compactMap { people[$0] }
            .filter { !$0.username.isEmpty }.sorted { $0.username < $1.username }
    }

    var friendsNeedAttention: Bool { friends.contains { $0.streak > 0 && $0.thisWeek == .pending } }

    // MARK: Navigation

    func enterDemo() {
        if let runtime { Task { await runtime.authenticate() }; return }
        guard !isLive else { return }
        setTab(.activity)
        isSignedIn = true
    }

    func signOutOfDemo() {
        if let runtime { Task { await runtime.signOut() }; return }
        reset()
        showDemoPanel = false
        isSignedIn = false
    }

    func go(_ route: Route) { path.append(route) }

    /// Opens someone's profile: yours is the Profile tab; everyone else, partners included, gets the same profile page.
    func openPerson(_ id: String) {
        if id == "me" { setTab(.profile); return }
        go(.person(id: id))
    }

    /// Follow or unfollow. The button flips right away; live, the next refresh confirms it.
    func setFollowing(_ id: String, _ follow: Bool) {
        guard id != "me", !pendingFollows.contains(id) else { return }
        guard !follow || canFollow(id) else { return }
        let previous = following.contains(id)
        if follow { following.insert(id) } else { following.remove(id) }
        if isLive, let runtime {
            let generation = followGeneration
            let username = follow ? usernamePeople[id]?.username : nil
            pendingFollows.insert(id)
            Task {
                guard generation == followGeneration else { return }
                let saved: Bool
                if let username {
                    saved = await runtime.perform("follow_username", ["username": username, "user_id": id])
                } else {
                    saved = await runtime.perform("set_follow", ["user_id": id, "follow": follow])
                }
                guard generation == followGeneration else { return }
                if !saved {
                    if previous { following.insert(id) } else { following.remove(id) }
                }
                pendingFollows.remove(id)
            }
        } else if !isLive, follow {
            addFriend(id)
        } else if !isLive {
            friends.removeAll { $0.id == id }
        }
    }

    func back() {
        guard !path.isEmpty else { return }
        if case .create = path.last { pendingPlanGoal = nil }
        path.removeLast()
    }

    func replace(_ route: Route) {
        if !path.isEmpty { path.removeLast() }
        path.append(route)
    }

    func setTab(_ newTab: AppTab) {
        pendingPlanGoal = nil
        path = []
        tab = newTab
    }

    func copySessionLink(_ id: String) {
        if let runtime { Task { await runtime.copySessionLink(id) } }
        else { showToast("Invite link copied", .success) }
    }

    func sessionInvitationURL(_ id: String) async -> URL? {
        await runtime?.sessionInvitationURL(id)
    }

    // MARK: Feedback

    func showToast(_ message: String, _ variant: MMToastVariant = .neutral) {
        let data = MMToastData(message: message, variant: variant)
        toast = data
        later(2.6) { [weak self] in
            if self?.toast?.id == data.id { self?.toast = nil }
        }
    }

    // MARK: Monkey

    /// The monkey builder, open over whatever screen the member was on.
    var editingMonkey = false
    /// The one-time "Your monkey's waiting" sheet for members who joined before monkeys.
    var monkeyPromptVisible = false
    /// Whether this account already answered that sheet (Build my monkey or Maybe later).
    private(set) var monkeyPromptAnswered = true
    @ObservationIgnored private var monkeyAccount: String?

    /// Ask once, on Activity with nothing pushed, after the profile exists.
    var shouldAskForMonkey: Bool {
        isSignedIn && !me.name.isEmpty && me.monkey == nil && !monkeyPromptAnswered
            && path.isEmpty && tab == .activity && !editingMonkey
    }

    private static func monkeyPromptKey(_ account: String) -> String { "matmonkeys.monkeyPrompt.\(account)" }

    /// Installed app: reads whether the signed-in account already answered the invitation.
    func loadMonkeyPrompt(account: String) {
        guard isLive, monkeyAccount != account else { return }
        monkeyAccount = account
        monkeyPromptAnswered = UserDefaults.standard.bool(forKey: Self.monkeyPromptKey(account))
    }

    /// Build or Maybe later: either way the sheet doesn't come back. Account keeps the row.
    func answerMonkeyPrompt() {
        monkeyPromptAnswered = true
        if isLive, let monkeyAccount { UserDefaults.standard.set(true, forKey: Self.monkeyPromptKey(monkeyAccount)) }
    }

    /// Saves the signed-in member's monkey: the set_monkey command when live, this device in preview.
    func saveMonkey(_ look: MMMonkeyLook) async -> Bool {
        if isLive {
            guard let runtime else { return false }
            // Closing Account (where Build my monkey lives) saves the profile. A command
            // that starts while another is running is dropped, so wait for that save first.
            let deadline = Date().addingTimeInterval(8)
            while runtime.busy && Date() < deadline {
                try? await Task.sleep(for: .milliseconds(100))
            }
            guard !runtime.busy else {
                showToast("Still saving your profile. Try again in a moment.")
                return false
            }
            guard await runtime.perform("set_monkey", ["monkey": look.code]) else { return false }
        }
        me.monkey = look
        answerMonkeyPrompt()
        return true
    }

    private func later(_ seconds: Double, _ work: @escaping @MainActor () -> Void) {
        let task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            work()
        }
        timers.append(task)
    }

    // MARK: Mutations

    private func updatePost(_ id: String, _ change: (inout Post) -> Void) {
        if let i = posts.firstIndex(where: { $0.id == id }) { change(&posts[i]) }
    }

    private func updateSession(_ id: String, _ change: (inout Session) -> Void) {
        if let i = upcoming.firstIndex(where: { $0.id == id }) { change(&upcoming[i]) }
        if let i = drafts.firstIndex(where: { $0.id == id }) { change(&drafts[i]) }
        if let i = completedSessions.firstIndex(where: { $0.id == id }) { change(&completedSessions[i]) }
        if var session = toComplete, session.id == id {
            change(&session)
            toComplete = session
        }
    }

    func like(_ id: String) {
        if isLive { send("set_like", ["post_id": id, "liked": !(post(id)?.likes.contains("me") ?? false)]); return }
        updatePost(id) { p in
            if p.likes.contains("me") { p.likes.removeAll { $0 == "me" } } else { p.likes.insert("me", at: 0) }
        }
    }

    func comment(_ id: String, _ text: String) {
        if isLive { send("add_comment", ["post_id": id, "body": text]); return }
        updatePost(id) { $0.comments.append(Comment(who: "me", text: text, fresh: true, createdAt: Date())) }
    }

    /// Your own comments, and any comment on a post you organized, can be deleted.
    func canDelete(_ comment: Comment, on postID: String) -> Bool {
        comment.who == "me" || post(postID)?.organizer == "me"
    }

    /// Deletes a comment. Live, the runtime hides it right away and brings it back if the delete fails.
    func deleteComment(_ comment: Comment, on postID: String) {
        if isLive {
            guard let cloudID = comment.cloudID else { return }
            send("delete_comment", ["comment_id": cloudID], success: { self.showToast("Comment deleted") })
            return
        }
        updatePost(postID) { $0.comments.removeAll { $0.id == comment.id } }
        showToast("Comment deleted")
    }

    /// Reasons offered when reporting a post or comment (sent as the report's text).
    static let reportReasons = ["Spam or scam", "Harassment or bullying", "Nudity or sexual content",
                                "Violence or threats", "Hate speech", "Something else"]

    /// Reports a post, or one of its comments when `commentID` is set. Reports go to the
    /// Mat Monkey team only; the person reported isn't told.
    @discardableResult
    func report(postID: String, commentID: String? = nil, reason: String) async -> Bool {
        if isLive {
            guard let runtime else { return false }
            let ok: Bool
            if let commentID {
                ok = await runtime.perform("report_comment", ["comment_id": commentID, "reason": reason])
            } else {
                ok = await runtime.perform("report_post", ["post_id": postID, "reason": reason])
            }
            guard ok else { return false }
        }
        showToast("Thanks for telling us. We'll take a look.", .success)
        return true
    }

    func editCaption(_ id: String, _ caption: String) {
        if isLive { send("edit_post", ["post_id": id, "caption": caption]); return }
        updatePost(id) { $0.caption = caption }
        showToast("Caption updated", .success)
    }

    func deletePost(_ id: String) {
        if isLive {
            // The runtime hides the post immediately; leave its page now rather than after the round trip.
            back()
            send("delete_post", ["post_id": id], success: { self.showToast("Post deleted from every profile") })
            return
        }
        posts.removeAll { $0.id == id }
        back()
        showToast("Post deleted from every profile")
    }

    func removeMe(from id: String) {
        if isLive { send("remove_tag", ["post_id": id], success: { self.back() }); return }
        updatePost(id) { $0.participants.removeAll { $0 == "me" } }
        back()
        showToast("You're off that post. It's gone from your profile.")
    }

    func rsvp(_ sessionID: String, _ status: RSVP) {
        if isLive { send("set_rsvp", ["session_id": sessionID, "rsvp": status.rawValue]); return }
        trainingInvitations.removeAll { $0.id == sessionID }
        updateSession(sessionID) { $0.set("me", status) }
        for i in notifications.indices where notifications[i].session == sessionID { notifications[i].unread = false }
        if status == .going {
            fresh = sessionID + "me"
            showToast("You're in. See you on the mat.", .success)
        } else {
            showToast("Declined. No hard feelings.")
        }
    }

    func removeParticipant(_ sessionID: String, _ personID: String) {
        if isLive { send("manage_participant", ["session_id": sessionID, "user_id": personID, "remove": true]); return }
        updateSession(sessionID) { $0.people.removeAll { $0.id == personID } }
        showToast("\(person(personID).firstName) removed")
    }

    func addParticipants(_ sessionID: String, _ ids: [String]) {
        if let runtime {
            Task { for id in ids { guard await runtime.perform("manage_participant", ["session_id": sessionID, "user_id": id, "remove": false]) else { return } } }
            return
        }
        guard !isLive else { return }
        updateSession(sessionID) { s in ids.forEach { s.set($0, .going) } }
        if let first = ids.first { fresh = sessionID + first }
        showToast("Added \(ids.count) to the session", .success)
    }

    func createSession(_ d: SessionDraft) {
        if runtime != nil {
            Task { await createSessions([SessionCreationRequest(draft: d)]) }
            return
        }
        guard !isLive else { return }
        guard TrainingFocusTree.isValid(d.focusItems) else {
            showToast("Name each focus, or remove the blank one.")
            return
        }
        let id = createPreviewSession(d)
        if !d.past, let goal = pendingPlanGoal { setGoal(goal, forSession: id) }
        pendingPlanGoal = nil
        replace(d.past ? .complete(id: id) : .session(id: id))
        showToast(d.invited.isEmpty ? "Session created" : "Invites sent to \(d.invited.count)", .success)
    }

    func createdCount(for requests: [SessionCreationRequest]) -> Int {
        requests.filter { createdSessions[$0.id] != nil }.count
    }

    /// Account changes invalidate both retry receipts and any in-flight batch.
    func resetSessionCreation() {
        creationGeneration = UUID()
        createdSessions = [:]
        creatingSessions = false
    }

    /// Editors use `presentingResult: false` to retain their route and leave pending planning goals alone.
    @discardableResult
    func createSessions(_ requests: [SessionCreationRequest], presentingResult: Bool = true) async -> Bool {
        guard !busy, !requests.isEmpty,
              requests.allSatisfy({ TrainingFocusTree.isValid($0.draft.focusItems) }),
              requests.count == 1 || requests.allSatisfy({ !$0.draft.past }),
              runtime != nil || !isLive else { return false }
        if isLive {
            guard requests.allSatisfy({ $0.draft.startsAt != nil && !$0.draft.gym.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { return false }
        }
        let generation = creationGeneration
        let goalToAttach = !presentingResult || requests[0].draft.past ? nil : pendingPlanGoal
        creatingSessions = true
        defer { if generation == creationGeneration { creatingSessions = false } }
        for request in requests {
            guard generation == creationGeneration, !Task.isCancelled else { return false }
            if createdSessions[request.id] != nil { continue }
            let id: String?
            if let runtime { id = await runtime.create(request.draft, key: request.id) }
            else { id = createPreviewSession(request.draft) }
            guard generation == creationGeneration, let id else { return false }
            createdSessions[request.id] = id
            if let goalToAttach { setGoal(goalToAttach, forSession: id) }
        }
        guard presentingResult else { return true }
        pendingPlanGoal = nil
        if requests.count == 1, let request = requests.first, let id = createdSessions[request.id] {
            replace(request.draft.past ? .complete(id: id) : .session(id: id))
            showToast(request.draft.invited.isEmpty ? "Session created" : "Invites sent to \(request.draft.invited.count)", .success)
        } else {
            setTab(.training)
            showToast("\(requests.count) sessions created", .success)
        }
        return true
    }

    private func createPreviewSession(_ d: SessionDraft) -> String {
        let id = "n\(UUID().uuidString)"
        var people = [Attendee(id: "me", status: .going)]
        people += d.invited.map { Attendee(id: $0, status: d.past ? .going : .invited) }
        let session = Session(id: id, title: d.title, day: d.day, date: d.date, month: d.month, time: d.time, gym: d.gym,
                              organizer: "me", privacy: d.privacy, people: people, note: d.note.isEmpty ? nil : d.note,
                              focusItems: TrainingFocusTree.normalized(d.focusItems), startsAt: d.startsAt)
        if d.past { drafts.append(session); return id }
        upcoming.append(session)
        // The first two invitees accept live, so the plan-together journey feels real.
        for (i, pid) in d.invited.prefix(2).enumerated() {
            later(2.2 + Double(i) * 2) { [weak self] in
                guard let self else { return }
                self.updateSession(id) { $0.set(pid, .going) }
                self.notifications.insert(AppNotification(id: "j\(UUID().uuidString)", kind: .joined, who: pid, session: id,
                                                          text: "joined \(d.title)", time: "now", unread: true), at: 0)
                self.fresh = id + pid
                self.showToast("\(self.person(pid).firstName) joined \(d.title)", .friend)
            }
        }
        return id
    }

    @discardableResult
    func updateSessionFocus(_ sessionID: String, _ items: [TrainingFocus]) -> Bool {
        if let runtime {
            Task { _ = await runtime.saveFocus(sessionID, items) }
            return false
        }
        guard let session = findSession(sessionID), session.organizer == "me", TrainingFocusTree.isValid(items) else { return false }
        let normalized = TrainingFocusTree.normalized(items)
        if let i = upcoming.firstIndex(where: { $0.id == sessionID }) {
            upcoming[i].focusItems = normalized
        } else if let i = drafts.firstIndex(where: { $0.id == sessionID }) {
            drafts[i].focusItems = normalized
        } else if let i = completedSessions.firstIndex(where: { $0.id == sessionID }) {
            completedSessions[i].focusItems = normalized
        } else if toComplete?.id == sessionID {
            toComplete?.focusItems = normalized
        } else {
            return false
        }
        showToast("Focus plan updated", .success)
        return true
    }

    @discardableResult
    func saveSessionPhoto(_ sessionID: String, photo: String) async -> Bool {
        guard let session = findSession(sessionID), session.organizer == "me", !isCompleted(session) else { return false }
        if let runtime { return await runtime.saveSessionPhoto(sessionID, photo: photo) }
        guard !isLive else { return false }
        updateSession(sessionID) { session in
            if !session.photos.contains(photo) { session.photos.insert(photo, at: 0) }
        }
        return true
    }

    func publish(_ sessionID: String, photo: String?, caption: String, people: [String]) -> PublishResult? {
        if isLive { return nil }
        guard var s = findSession(sessionID), s.organizer == "me", ShareRule.canPublish(hasPhoto: photo != nil, caption: caption) else { return nil }
        if let photo, !s.photos.contains(photo) { s.photos.insert(photo, at: 0) }
        let post = Post(id: "p\(Int(Date().timeIntervalSince1970 * 1000))", organizer: "me", title: s.title, gym: s.gym,
                        date: "\(s.day), \(s.month) \(s.date)", ago: "now", photo: photo, participants: people,
                        caption: caption, likes: [], extraLikes: 0, comments: [], focusItems: s.focusItems,
                        occurredAt: s.startsAt ?? Date(), time: s.time)
        let streaks = friends
            .filter { people.contains($0.id) && $0.thisWeek != .done }
            .map { StreakTick(id: $0.id, from: $0.streak, to: $0.streak + 1, friendship: $0) }
        posts.insert(post, at: 0)
        sharedSessionIDs.insert(s.id)
        completedSessions.removeAll { $0.id == s.id }
        var attended = s
        for i in attended.people.indices { attended.people[i].attended = people.contains(attended.people[i].id) }
        completedSessions.append(attended)
        upcoming.removeAll { $0.id == sessionID }
        drafts.removeAll { $0.id == sessionID }
        if toComplete?.id == sessionID { toComplete = nil }
        for i in friends.indices where people.contains(friends[i].id) { friends[i].thisWeek = .done }
        return PublishResult(post: post, streaks: streaks)
    }

    /// After publishing: jump to the feed, highlight the post, and let friends react.
    func showPost(_ id: String) {
        if isLive { path = []; tab = .activity; highlight = id; return }
        path = []
        tab = .activity
        highlight = id
        later(2.5) { [weak self] in self?.highlight = nil }
        later(1.8) { [weak self] in
            self?.updatePost(id) { $0.likes = ["sarah"]; $0.extraLikes = 0 }
            self?.showToast("Sarah liked your post", .friend)
        }
        later(3.8) { [weak self] in
            self?.updatePost(id) {
                $0.likes.append("alex")
                $0.comments.append(Comment(who: "alex", text: "Great rounds today. Same time next week?", fresh: true, createdAt: Date()))
            }
            self?.showToast("Alex commented on your post")
        }
    }

    func addFriend(_ id: String) {
        if isLive { return }
        guard id != "me" else { return }
        following.insert(id)
        if people[id] == nil, let person = listedPeople[id] ?? usernamePeople[id] { people[id] = person }
        guard !friends.contains(where: { $0.id == id }) else { return }
        friends.insert(Friendship(id: id, weeks: Array(repeating: false, count: 9), thisWeek: .pending, best: 0, together: 0), at: 0)
    }

    func readAll() {
        if isLive { send("read_notifications", [:]); return }
        for i in notifications.indices { notifications[i].unread = false }
    }

    func updateMe(name: String, email: String, belt: BeltRank, stripes: Int) {
        if isLive {
            send("save_profile", ["name": name, "belt": belt.rawValue, "stripes": stripes, "gym": me.gym, "timezone": TimeZone.current.identifier])
            return
        }
        me.name = name
        me.email = email
        me.belt = belt
        me.stripes = stripes
    }

    /// Sets the profile photo from picked image data. Live: uploaded to the cloud; preview: kept on this device.
    @discardableResult
    func updatePhoto(_ data: Data) async -> Bool {
        guard let image = UIImage(data: data), let jpeg = Self.avatarJPEG(image) else {
            showToast("That photo couldn't be read")
            return false
        }
        if isLive {
            guard let runtime, await runtime.saveAvatar(jpeg) else { return false }
            showToast("Profile photo updated", .success)
            return true
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("matmind-preview-avatar-\(UUID().uuidString).jpg")
        do { try jpeg.write(to: url, options: .atomic) } catch {
            showToast("That photo couldn't be saved")
            return false
        }
        if let old = me.photo, old.hasPrefix(FileManager.default.temporaryDirectory.path) { try? FileManager.default.removeItem(atPath: old) }
        me.photo = url.path
        showToast("Profile photo updated", .success)
        return true
    }

    /// Center-crops to a square, caps at 640px, and re-renders to strip EXIF (including location).
    nonisolated static func avatarJPEG(_ image: UIImage) -> Data? {
        let side = min(image.size.width, image.size.height)
        guard side > 0 else { return nil }
        let target = min(640, side)
        let scale = target / side
        let drawn = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: target, height: target), format: format).image { _ in
            image.draw(in: CGRect(x: (target - drawn.width) / 2, y: (target - drawn.height) / 2, width: drawn.width, height: drawn.height))
        }.jpegData(compressionQuality: 0.82)
    }

    // MARK: Hosting

    /// Host only. Omitted focus/guests keep their current values; retained guests keep their RSVPs.
    func editSession(_ id: String, title: String, startsAt: Date, gym: String, note: String,
                     focusItems: [TrainingFocus]? = nil, guestIDs: Set<String>? = nil) async -> Bool {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let gym = gym.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !gym.isEmpty, let session = findSession(id), session.organizer == "me" else { return false }
        let focus = focusItems ?? session.focusItems
        guard TrainingFocusTree.isValid(focus) else { return false }
        let existing = Set(session.people.map(\.id).filter { $0 != session.organizer })
        let guests = (guestIDs ?? existing).subtracting([session.organizer])
        let added = guests.subtracting(existing).sorted()
        let removed = existing.subtracting(guests).sorted()
        guard added.allSatisfy({ id in friends.contains { $0.id == id } }) else { return false }
        if let runtime {
            guard await runtime.editSession(id, title: title, startsAt: startsAt, gym: gym, note: note,
                                            focusItems: focus, addedGuests: added, removedGuests: removed) else { return false }
            showToast("Session updated", .success)
            return true
        }
        guard !isLive else { return false }
        updateSession(id) { s in
            s.title = title
            s.gym = gym
            s.note = note.isEmpty ? nil : note
            s.focusItems = TrainingFocusTree.normalized(focus)
            s.people.removeAll { removed.contains($0.id) }
            added.forEach { s.set($0, startsAt > Date() ? .invited : .going) }
            s.startsAt = startsAt
            s.day = Self.sessionText(startsAt, "EEE")
            s.date = Int(Self.sessionText(startsAt, "d")) ?? s.date
            s.month = Self.sessionText(startsAt, "MMM")
            s.time = Self.sessionText(startsAt, "h:mm a")
        }
        showToast("Session updated", .success)
        return true
    }

    /// Host only: calls a planned session off. It leaves everyone's schedule.
    func deleteSession(_ id: String) {
        guard findSession(id)?.organizer == "me" else { return }
        if isLive {
            send("cancel_session", ["session_id": id], success: {
                self.forgetGoal(forSession: id)
                self.showToast("Session deleted")
            })
            return
        }
        upcoming.removeAll { $0.id == id }
        drafts.removeAll { $0.id == id }
        if toComplete?.id == id { toComplete = nil }
        forgetGoal(forSession: id)
        showToast("Session deleted")
    }

    /// Where an edit starts: the exact start when known, else the ticket's day and time this year.
    func startDate(of session: Session) -> Date {
        if let startsAt = session.startsAt { return startsAt }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy MMM d h:mm a"
        let year = Calendar.current.component(.year, from: Date())
        return formatter.date(from: "\(year) \(session.month) \(session.date) \(session.time)") ?? Date()
    }

    private static func sessionText(_ date: Date, _ format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    private func forgetGoal(forSession id: String) {
        guard sessionGoals[id] != nil else { return }
        sessionGoals[id] = nil
        persistGoals()
    }

    // MARK: Goals

    /// Adds a new goal (newest first) or updates an existing one. Returns false for a blank name.
    @discardableResult
    func saveGoal(_ goal: MatGoal) -> Bool {
        var goal = goal
        goal.title = goal.title.trimmingCharacters(in: .whitespacesAndNewlines)
        goal.notes = goal.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !goal.title.isEmpty else { return false }
        if let i = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[i] = goal
            showToast("Goal updated", .success)
        } else {
            goals.insert(goal, at: 0)
            showToast("Added to what you're working on", .success)
        }
        persistGoals()
        goalChanged(goal.id)
        return true
    }

    /// Saves a goal together with its parts as edited on screen. New photos are written
    /// privately to disk, photos taken out of a part lose their file, and parts with
    /// nothing in them are dropped. Returns false for a blank goal name.
    @discardableResult
    func saveGoal(_ goal: MatGoal, parts drafts: [GoalPartDraft]) -> Bool {
        var goal = goal
        guard !goal.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        var parts: [GoalPart] = []
        for draft in drafts {
            var part = GoalPart(id: draft.id,
                                title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
                                notes: draft.notes.trimmingCharacters(in: .whitespacesAndNewlines),
                                link: Self.normalizedLink(draft.link) ?? "")
            for photo in draft.photos {
                if let stored = photo.stored {
                    part.photos.append(stored)
                } else if let data = photo.data, let saved = storeGoalPhoto(data, goalID: goal.id) {
                    part.photos.append(saved)
                }
            }
            if !part.isBlank { parts.append(part) }
        }
        let kept = Set(parts.flatMap(\.photos))
        self.goal(goal.id)?.parts.flatMap(\.photos).filter { !kept.contains($0) }.forEach(Self.deleteGoalPhotoFile)
        goal.parts = parts
        return saveGoal(goal)
    }

    func deleteGoal(_ id: String) {
        // People it was shared with lose it too.
        let publishing = goalPublishes.removeValue(forKey: id)
        if let shared = sharedGoalIDs.removeValue(forKey: id) {
            goalRecipients[shared] = nil
            if isLive, let runtime {
                // A save still being published would bring the shared copy back: unshare after it.
                Task { _ = await publishing?.value; _ = await runtime.perform("unshare_goal", ["goal_id": shared]) }
            }
        }
        goal(id)?.allPhotos.forEach(Self.deleteGoalPhotoFile)
        goals.removeAll { $0.id == id }
        sessionGoals = sessionGoals.filter { $0.value != id }
        persistGoals()
        showToast("Goal removed")
    }

    /// Attaches a goal to one of your sessions, or clears it with `nil`.
    func setGoal(_ goalID: String?, forSession sessionID: String) {
        if let goalID, goal(goalID) != nil {
            sessionGoals[sessionID] = goalID
        } else {
            sessionGoals[sessionID] = nil
        }
        persistGoals()
    }

    /// Adds goals brought over from an old-notebook export, newest import first.
    /// Goals already imported (same id) are skipped. Returns how many were added.
    @discardableResult
    func importGoals(_ imported: [MatGoal]) -> Int {
        let fresh = imported.filter { goal($0.id) == nil }
        goals.insert(contentsOf: fresh, at: 0)
        persistGoals()
        return fresh.count
    }

    /// "Plan a training for this": opens the plan form; the new session gets this goal.
    func planSession(forGoal id: String) {
        guard goal(id) != nil else { return }
        go(.create())
        pendingPlanGoal = id
    }

    /// Adds a reference link to a goal. Bare domains get https://. Returns false if it isn't a web link.
    @discardableResult
    func addLink(_ raw: String, toGoal id: String) -> Bool {
        guard let text = Self.normalizedLink(raw), let i = goals.firstIndex(where: { $0.id == id }) else {
            showToast("That doesn't look like a link")
            return false
        }
        if !goals[i].links.contains(text) { goals[i].links.append(text) }
        persistGoals()
        goalChanged(id)
        showToast("Link added", .success)
        return true
    }

    /// A web link with https:// added to bare domains, or nil when it isn't one.
    static func normalizedLink(_ raw: String) -> String? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty, !text.contains("://") { text = "https://" + text }
        guard !text.contains(where: \.isWhitespace), let url = URL(string: text),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme), url.host?.isEmpty == false else { return nil }
        return text
    }

    /// Saves a reference photo for a goal, privately on this device. The image is
    /// re-encoded as JPEG (no location or camera metadata) and capped at 2048 px.
    @discardableResult
    func addPhoto(_ data: Data, toGoal id: String, announce: Bool = true) -> Bool {
        guard let i = goals.firstIndex(where: { $0.id == id }) else { return false }
        guard let relative = storeGoalPhoto(data, goalID: id) else { return false }
        goals[i].photos.append(relative)
        persistGoals()
        goalChanged(id)
        if announce { showToast("Photo added", .success) }
        return true
    }

    func removePhoto(_ photo: String, fromGoal id: String) {
        guard let i = goals.firstIndex(where: { $0.id == id }), goals[i].photos.contains(photo) else { return }
        goals[i].photos.removeAll { $0 == photo }
        Self.deleteGoalPhotoFile(photo)
        persistGoals()
        goalChanged(id)
        showToast("Photo removed")
    }

    // MARK: Sharing goals

    /// A saved goal that's already shared: send the new version so recipients see it.
    private func goalChanged(_ id: String) {
        guard sharedGoalIDs[id] != nil else { return }
        _ = publishLatest(id)
    }

    /// Publishes the goal as it is when the publish runs, after any earlier one finishes.
    private func publishLatest(_ goalID: String) -> Task<String?, Never>? {
        guard let runtime else { return nil }
        let previous = goalPublishes[goalID]
        let task = Task { @MainActor [weak self] () -> String? in
            _ = await previous?.value
            guard !Task.isCancelled, let self, let goal = self.goal(goalID) else { return nil }
            let shared = await runtime.publishGoal(goal)
            if let shared, self.goal(goalID) != nil { self.sharedGoalIDs[goalID] = shared }
            return shared
        }
        goalPublishes[goalID] = task
        return task
    }

    /// The shared copy's id. A goal that's already shared is republished on every save, so
    /// reuse it (after any save still on its way) instead of uploading everything again.
    private func sharedCopy(_ goalID: String) async -> String? {
        if let shared = sharedGoalIDs[goalID] {
            if let pending = goalPublishes[goalID] { return await pending.value ?? shared }
            return shared
        }
        return await publishLatest(goalID)?.value
    }

    /// Shares one of your goals with training partners. Everything in it goes along:
    /// notes, parts, videos, photos and links. They get an invitation to accept or decline.
    @discardableResult
    func shareGoal(_ goalID: String, with people: [String]) async -> Bool {
        let people = people.filter { $0 != "me" }
        guard goal(goalID) != nil, !people.isEmpty else { return false }
        let names = people.count == 1 ? person(people[0]).firstName : "\(people.count) training partners"
        if let runtime {
            // The share sheet closes right away; this says it's on its way. Failures show the app's alert.
            showToast("Sharing with \(names)…")
            guard let shared = await sharedCopy(goalID),
                  await runtime.perform("share_goal", ["goal_id": shared, "recipients": people]) else { return false }
        } else {
            guard !isLive else { return false }
            sharedGoalIDs[goalID] = goalID
            var answers = goalRecipients[goalID] ?? [:]
            for person in people where answers[person] != "accepted" { answers[person] = "pending" }
            goalRecipients[goalID] = answers
        }
        showToast("Shared with \(names)", .success)
        return true
    }

    /// Copies a link to one of your goals for people who aren't training partners yet.
    @discardableResult
    func copyGoalLink(_ goalID: String) async -> Bool {
        guard goal(goalID) != nil else { return false }
        if let runtime {
            guard let shared = await sharedCopy(goalID), await runtime.copyGoalLink(shared) else { return false }
        } else {
            guard !isLive else { return false }
            sharedGoalIDs[goalID] = goalID
        }
        showToast("Goal link copied", .success)
        return true
    }

    /// Accepts a shared goal (it moves to Shared) or declines it. Declining one you
    /// already accepted removes it from Shared; the owner can share it again.
    @discardableResult
    func respondToSharedGoal(_ id: String, accept: Bool) async -> Bool {
        guard let shared = sharedGoal(id) else { return false }
        let wasAccepted = shared.status == .accepted
        if let runtime {
            guard await runtime.perform("respond_goal_share", ["goal_id": id, "accept": accept]) else { return false }
        } else {
            guard !isLive else { return false }
            if accept, let i = sharedGoals.firstIndex(where: { $0.id == id }) {
                sharedGoals[i].status = .accepted
            } else if !accept {
                sharedGoals.removeAll { $0.id == id }
            }
            for i in notifications.indices where notifications[i].kind == .goalShare && notifications[i].session == id {
                notifications[i].unread = false
            }
        }
        if accept {
            showToast("\(shared.title) is in Shared", .success)
        } else {
            showToast(wasAccepted ? "Removed from Shared" : "Declined. No hard feelings.")
        }
        return true
    }

    /// Writes a goal photo privately on this device (JPEG, no metadata, at most 2048 px)
    /// and returns its path relative to `MatGoal.photoRoot`, or nil with a toast.
    private func storeGoalPhoto(_ data: Data, goalID id: String) -> String? {
        guard let image = UIImage(data: data), let jpeg = Self.goalPhotoJPEG(image) else {
            showToast("That photo couldn't be read")
            return nil
        }
        let folder = id.replacingOccurrences(of: "/", with: "-")
        let relative = "\(folder)/\(UUID().uuidString.lowercased()).jpg"
        let url = MatGoal.photoRoot.appendingPathComponent(relative)
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try jpeg.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            showToast("That photo couldn't be saved")
            return nil
        }
        return relative
    }

    /// Deletes a goal photo saved under `MatGoal.photoRoot` (sample asset names are left alone).
    private static func deleteGoalPhotoFile(_ photo: String) {
        let url = MatGoal.photoRoot.appendingPathComponent(photo).standardizedFileURL
        guard url.path.hasPrefix(MatGoal.photoRoot.standardizedFileURL.path + "/"),
              FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func goalPhotoJPEG(_ image: UIImage) -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, 2048 / longest)
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format)
            .image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            .jpegData(compressionQuality: 0.85)
    }

    private struct StoredGoals: Codable {
        var goals: [MatGoal]
        var sessionGoals: [String: String]
    }

    private static func goalsKey(_ account: String) -> String { "matmonkeys.goals.\(account)" }

    /// Installed app: loads the signed-in account's goals from this device.
    func loadGoals(account: String) {
        guard isLive, goalAccount != account else { return }
        goalAccount = account
        let stored = UserDefaults.standard.data(forKey: Self.goalsKey(account))
            .flatMap { try? JSONDecoder().decode(StoredGoals.self, from: $0) }
        goals = stored?.goals ?? []
        sessionGoals = stored?.sessionGoals ?? [:]
    }

    private func persistGoals() {
        guard isLive, let goalAccount else { return }
        if let data = try? JSONEncoder().encode(StoredGoals(goals: goals, sessionGoals: sessionGoals)) {
            UserDefaults.standard.set(data, forKey: Self.goalsKey(goalAccount))
        }
    }

    // MARK: Demo

    func reset() {
        if isLive { return }
        resetPeopleLookup()
        resetSessionCreation()
        timers.forEach { $0.cancel() }
        timers = []
        completedSessions = []
        resetTrainingActions()
#if DEBUG || MAT_MIND_PROTOTYPE
        me = SeedData.me
        people = SeedData.people
        friends = SeedData.friends
        circle = SeedData.circle
        following = Set(SeedData.friends.map(\.id))
        for id in SeedData.following { addFriend(id) }
        partnerLists = [:]
        listedPeople = [:]
        posts = SeedData.posts
        trainingInvitations = []
        upcoming = SeedData.upcoming + SeedData.calendarPlans
        quickLogs = SeedData.quickLogs
        completedSessions = SeedData.calendarCompleted
        sharedSessionIDs = []
        discoverableSessions = []
        toComplete = SeedData.toComplete
        notifications = SeedData.notifications
        gyms = SeedData.gyms
        cameraRoll = SeedData.cameraRoll
        goals = SeedData.goals
        sessionGoals = SeedData.sessionGoals
        sharedGoals = SeedData.sharedGoals
        sharedGoalIDs = [:]
        goalRecipients = [:]
        // The preview account predates monkeys, so reviewers see the invitation.
        monkeyPromptAnswered = false
#endif
        drafts = []
        path = []
        toast = nil
        highlight = nil
        fresh = nil
        editingMonkey = false
        monkeyPromptVisible = false
    }

    /// Deep links from the web prototype's review panel (`index.html#…`).
    enum Preset: String, CaseIterable, Identifiable {
        case welcome, activity, training, create, complete, friends, qr, profile, notifications
        case people, person
        case empty, firstSession, awaitingPhoto, focusPlan, invite, active, broken, scan, post
        var id: String { rawValue }
    }

    func run(_ preset: Preset) {
        if isLive { return }
        reset()
        isSignedIn = preset != .welcome
        switch preset {
        case .welcome: break
        case .activity: setTab(.activity)
        case .training: setTab(.training)
        case .friends: setTab(.profile); go(.friends)
        case .profile: setTab(.profile)
        case .create: setTab(.training); go(.create())
        case .focusPlan: setTab(.training); go(.create(focus: TrainingFocusTree.example))
        case .complete: setTab(.training); go(.complete(id: "c1"))
        case .qr: setTab(.profile); go(.qr())
        case .scan: setTab(.profile); go(.qr(scan: true))
        case .notifications: setTab(.activity); go(.notifications)
        case .post: setTab(.activity); go(.post(id: "p1"))
        case .people: setTab(.activity); go(.people)
        case .person: setTab(.activity); go(.people); go(.person(id: "rafa"))
        case .empty:
            upcoming = []
            toComplete = nil
            notifications.removeAll { $0.kind == .invite || $0.kind == .joined }
            setTab(.training)
        case .firstSession:
            posts = []
            upcoming = []
            friends = []
            toComplete = nil
            notifications = []
            setTab(.activity)
        case .awaitingPhoto:
            posts = []
            toComplete = nil
            setTab(.activity)
        case .invite: setTab(.training); go(.session(id: "s2"))
        case .broken: setTab(.profile); go(.friends); go(.friend(id: "jamie"))
        case .active: setTab(.profile); go(.friends); go(.friend(id: "sarah"))
        }
    }
}


extension AppModel {
    var calendarSessions: [Session] {
        var seen = Set<String>()
        return (upcoming + completedSessions + drafts + (toComplete.map { [$0] } ?? []))
            .filter { seen.insert($0.id).inserted }
    }
    func dayLogs(_ date: Date) -> [QuickLog] { quickLogs.filter { $0.loggedOn == TrainingCalendar.key(date) } }
    func daySessions(_ date: Date) -> [Session] {
        calendarSessions.filter { s in
            s.startsAt.map { TrainingCalendar.calendar.isDate($0, inSameDayAs: date) } == true
                && s.people.contains { $0.id == "me" && $0.attended }
        }
    }
    func openPlans(_ date: Date) -> [Session] {
        calendarSessions.filter { s in
            s.startsAt.map { TrainingCalendar.calendar.isDate($0, inSameDayAs: date) } == true
                && (s.organizer == "me" || s.status(of: "me") == .going)
                && !s.people.contains { $0.id == "me" && $0.attended }
                && !isCompleted(s)
        }.sorted { startDate(of: $0) < startDate(of: $1) }
    }
    func entryCount(_ date: Date) -> Int { dayLogs(date).count + daySessions(date).count }
    func trainedDays(_ week: [Date]) -> Int { week.filter { entryCount($0) > 0 }.count }
    func trainingTap(_ date: Date, now: Date = Date(), isActivity: Bool = false) -> TrainingTap {
        let planned = !openPlans(date).isEmpty
        let future = TrainingCalendar.calendar.startOfDay(for: date) > TrainingCalendar.calendar.startOfDay(for: now)
        // Activity can show a future plan's chooser without allowing an early log.
        if future && !(isActivity && planned) { return .disabled }
        if planned { return .choose }
        return isActivity || entryCount(date) == 0 ? .quickLog : .entries
    }
    func canMarkTrainingDone(_ session: Session, now: Date = Date()) -> Bool {
        guard let current = findSession(session.id), let start = current.startsAt else { return false }
        return start <= now && !isCompleted(current) && !sharedSessionIDs.contains(current.id)
            && current.status(of: "me") == .going
            && !current.people.contains { $0.id == "me" && $0.attended }
    }

    /// Selecting an existing plan is navigation only. Attendance is confirmed by
    /// the organizer in the existing composer, never by the Quick Log chooser.
    func canOpenQuickLogPlan(_ session: Session, now: Date = Date()) -> Bool {
        guard let current = findSession(session.id), let start = current.startsAt else { return false }
        return start <= now && current.status(of: "me") == .going
            && trainingCompletionStatus(current) == nil
    }

    @discardableResult func openQuickLogPlan(_ session: Session, now: Date = Date()) -> Bool {
        guard quickTrainingLogEnabled, !busy, canOpenQuickLogPlan(session, now: now),
              let current = findSession(session.id) else { return false }
        go(current.organizer == "me" ? .complete(id: current.id) : .session(id: current.id))
        return true
    }
    func canUndoTrainingToast(_ id: UUID) -> Bool {
        quickTrainingLogEnabled && trainingUndoToastID == id && trainingUndo != nil
            && !savingTraining && !(trainingUndoSessionID.map { sharedSessionIDs.contains($0) } ?? false)
    }
    func trainingToast(_ text: String, sessionID: String? = nil, undo: @escaping () async -> Bool) {
        let data = MMToastData(message: text, variant: .success)
        toast = data; trainingUndo = undo; trainingUndoToastID = data.id; trainingUndoSessionID = sessionID
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard let self, self.trainingUndoToastID == data.id else { return }
            if self.toast?.id == data.id { self.toast = nil }
            self.trainingUndo = nil; self.trainingUndoToastID = nil; self.trainingUndoSessionID = nil
        }
    }
    func undoTrainingToast(_ id: UUID) async {
        guard !busy, canUndoTrainingToast(id), let undo = trainingUndo else { return }
        let generation = trainingGeneration
        savingTraining = true
        defer { if generation == trainingGeneration { savingTraining = false } }
        let saved = await undo()
        guard generation == trainingGeneration else { return }
        if saved {
            if toast?.id == id { toast = nil }
            if trainingUndoToastID == id { trainingUndo = nil; trainingUndoToastID = nil; trainingUndoSessionID = nil }
        } else if toast?.id == id {
            toast?.message = "Couldn't undo. Try again."
        }
    }
    // Like goals, technique preferences and rep details are private, account-scoped device data.
    private struct StoredQuickLogTechniques: Codable {
        var techniques: [QuickLogTechnique]
        var hitsByID: [String: [QuickLogHit]]
    }

    private static func quickLogKey(_ account: String) -> String { "matmonkeys.quickLogTechniques.\(account)" }

    func loadQuickLogTechniques(account: String, defaults: UserDefaults = .standard) {
        guard quickLogAccount != account else { return }
        if quickLogAccount != nil {
            trainingGeneration = UUID()
            savingTraining = false
            trainingUndo = nil; trainingUndoToastID = nil; trainingUndoSessionID = nil
        }
        quickLogAccount = account
        quickLogDefaults = defaults
        let stored = defaults.data(forKey: Self.quickLogKey(account))
            .flatMap { try? JSONDecoder().decode(StoredQuickLogTechniques.self, from: $0) }
        quickLogTechniques = stored?.techniques ?? QuickLogTechnique.defaults
        let savedHits = stored?.hitsByID ?? [:]
        quickLogHitsByID = [:]
        for id in savedHits.keys.sorted() {
            let canonical = QuickLog.canonicalID(id)
            // Prefer a canonical entry if an older cache contains both spellings.
            if id == canonical || quickLogHitsByID[canonical] == nil {
                quickLogHitsByID[canonical] = savedHits[id]
            }
        }
        if quickLogHitsByID != savedHits { persistQuickLogTechniques() }
    }

    private func persistQuickLogTechniques() {
        guard let quickLogAccount,
              let data = try? JSONEncoder().encode(StoredQuickLogTechniques(techniques: quickLogTechniques, hitsByID: quickLogHitsByID)) else { return }
        quickLogDefaults.set(data, forKey: Self.quickLogKey(quickLogAccount))
    }

    @discardableResult func addQuickLogTechnique(_ name: String) -> QuickLogTechnique? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !quickLogTechniques.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return nil }
        let technique = QuickLogTechnique(name: trimmed)
        quickLogTechniques.append(technique)
        persistQuickLogTechniques()
        return technique
    }

    func removeQuickLogTechnique(_ id: String) {
        quickLogTechniques.removeAll { $0.id == id }
        persistQuickLogTechniques()
    }

    func restoreQuickLogTechnique(_ technique: QuickLogTechnique, at index: Int) {
        guard !quickLogTechniques.contains(where: { $0.id == technique.id || $0.name.caseInsensitiveCompare(technique.name) == .orderedSame }) else { return }
        quickLogTechniques.insert(technique, at: min(max(0, index), quickLogTechniques.count))
        persistQuickLogTechniques()
    }

    /// Each sheet begins with fresh counts; only positive reps enter the saved log.
    func quickLogHits(counts: [String: Int]) -> [QuickLogHit] {
        quickLogTechniques.compactMap { technique in
            guard let count = counts[technique.id], count > 0 else { return nil }
            return QuickLogHit(id: technique.id, name: technique.name, count: count)
        }
    }

    @discardableResult func addQuickLog(_ date: Date, counts: [String: Int]? = nil) async -> Bool {
        guard quickTrainingLogEnabled, !busy, !isLive || runtime != nil, trainingTap(date) != .disabled else { return false }
        let hits = counts.map { quickLogHits(counts: $0) } ?? []
        guard counts == nil || !hits.isEmpty else { return false }
        let generation = trainingGeneration
        savingTraining = true
        defer { if generation == trainingGeneration { savingTraining = false } }
        let log = QuickLog(id: UUID().uuidString.lowercased(), loggedOn: TrainingCalendar.key(date), loggedAt: Date(), timezone: TimeZone.current.identifier)
        if let runtime {
            let saved = await runtime.perform("create_quick_log", ["id": log.id, "logged_on": log.loggedOn, "timezone": log.timezone])
            guard generation == trainingGeneration else { return false }
            guard saved else { showToast("Couldn't save training. Try again.", .danger); return false }
        } else { quickLogs.append(log) }
        if !hits.isEmpty {
            quickLogHitsByID[log.id] = hits
            persistQuickLogTechniques()
        }
        trainingToast("Training logged") { [weak self] in await self?.deleteQuickLog(log.id) ?? false }
        return true
    }
    @discardableResult func deleteQuickLog(_ id: String) async -> Bool {
        guard quickTrainingLogEnabled else { return false }
        let generation = trainingGeneration
        if let runtime {
            guard await runtime.perform("delete_quick_log", ["id": id]), generation == trainingGeneration else { return false }
        } else {
            guard !isLive else { return false }
            quickLogs.removeAll { $0.id == id }
        }
        quickLogHitsByID.removeValue(forKey: id)
        persistQuickLogTechniques()
        return true
    }
    @discardableResult func removeOwnTrainingAttendance(_ session: Session) async -> Bool {
        guard !busy, let current = findSession(session.id),
              current.people.contains(where: { $0.id == "me" && $0.attended }) else { return false }
        if let runtime {
            return await runtime.perform("correct_attendance", ["session_id": session.id, "user_id": "me", "attended": false])
        }
        guard !isLive else { return false }
        updateSession(session.id) { session in
            for i in session.people.indices where session.people[i].id == "me" { session.people[i].attended = false }
        }
        showToast("Attendance removed")
        return true
    }
    func canRemoveQuickLog(on date: Date) -> Bool {
        trainingTap(date) != .disabled && openPlans(date).isEmpty && daySessions(date).isEmpty && !dayLogs(date).isEmpty
    }
    /// The strip removes one private log, never confirmed session attendance.
    @discardableResult func removeLatestQuickLog(on date: Date) async -> Bool {
        guard !busy, !isLive || runtime != nil, canRemoveQuickLog(on: date),
              let log = dayLogs(date).max(by: {
                  $0.loggedAt == $1.loggedAt ? $0.id < $1.id : $0.loggedAt < $1.loggedAt
              }) else { return false }
        let generation = trainingGeneration
        savingTraining = true
        defer { if generation == trainingGeneration { savingTraining = false } }
        let saved = await deleteQuickLog(log.id)
        guard generation == trainingGeneration else { return false }
        guard saved else { showToast("Couldn't remove the quick log. Try again.", .danger); return false }
        trainingUndo = nil; trainingUndoToastID = nil; trainingUndoSessionID = nil
        showToast("Quick log removed")
        return true
    }
    @discardableResult func markTrainingDone(_ session: Session) async -> Bool {
        guard quickTrainingLogEnabled, !busy, !isLive || runtime != nil, canMarkTrainingDone(session),
              let current = findSession(session.id) else { return false }
        let generation = trainingGeneration
        savingTraining = true
        defer { if generation == trainingGeneration { savingTraining = false } }
        let actionID = UUID().uuidString
        var done = current
        let changed = current.people.filter { $0.status == .going && !$0.attended && (current.organizer == "me" || $0.id == "me") }.map(\.id)
        for i in done.people.indices where changed.contains(done.people[i].id) { done.people[i].attended = true }
        if let runtime {
            let saved = await runtime.perform("mark_training_done", ["session_id": current.id, "action_id": actionID, "timezone": TimeZone.current.identifier])
            guard generation == trainingGeneration else { return false }
            guard saved else { showToast("Couldn't mark training done. Try again.", .danger); return false }
        } else if current.organizer == "me" {
            completedSessions.removeAll { $0.id == current.id }; completedSessions.append(done)
            upcoming.removeAll { $0.id == current.id }
            if toComplete?.id == current.id { toComplete = nil }
        } else if let i = upcoming.firstIndex(where: { $0.id == current.id }) { upcoming[i] = done }
        let others = current.going.filter { $0 != "me" }.map { person($0).firstName }.joined(separator: " and ")
        let message = "Marked done for you" + (current.organizer == "me" && !others.isEmpty ? " and " + others : "")
        let applied = done
        trainingToast(message, sessionID: current.id) { [weak self] in
            guard let self, !self.sharedSessionIDs.contains(current.id) else { return false }
            if let runtime = self.runtime {
                return await runtime.perform("undo_training_done", ["action_id": actionID])
            }
            guard !self.isLive, self.findSession(current.id) == applied else { return false }
            self.completedSessions.removeAll { $0.id == current.id }
            self.upcoming.removeAll { $0.id == current.id }; self.upcoming.append(current)
            return true
        }
        return true
    }
}

extension AppModel {
    func trainingRhythm(now: Date = Date(), calendar: Calendar = .current) -> ProfileRhythmHistory {
        if isLive, let rhythmSessionDates {
            return ProfileRhythmHistory(dates: rhythmSessionDates, now: now, calendar: calendar)
        }
        let dates = trainingSessions(past: true, relativeTo: now)
            .filter { $0.organizer == "me" || $0.status(of: "me") == .going }
            .map { startDate(of: $0) }
        // Preview posts have no backing server session rows. Live history never depends on feed pagination.
        let previewDates = isLive ? [] : ProfileHistory(posts: posts.filter { $0.organizer == "me" || $0.participants.contains("me") }, now: now).items.map(\.day)
        return ProfileRhythmHistory(dates: dates + previewDates, now: now, calendar: calendar)
    }
}
