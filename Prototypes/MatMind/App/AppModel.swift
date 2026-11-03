import Observation
import SwiftUI

/// Live services are supplied by the installed app; the preview keeps its demo adapter.
@MainActor
protocol AppRuntime: AnyObject {
    var busy: Bool { get }
    func authenticate() async
    func signOut() async
    func perform(_ operation: String, _ payload: [String: Any]) async -> Bool
    func create(_ draft: SessionDraft) async -> String?
    func publish(_ sessionID: String, photo: String?, caption: String, people: [String]) async -> PublishResult?
    func friendCode() async -> String?
    func connect(_ value: String) async -> String?
    func copySessionLink(_ sessionID: String) async
    func saveFocus(_ sessionID: String, _ items: [TrainingFocus]) async -> Bool
    func scannerView(found: @escaping (String) -> Void) -> AnyView
    func exportView() -> AnyView
}

/// All prototype state and actions, ported from `useApp()` in `ui_kits/app/App.jsx`.
/// Everything is in memory; "Reset demo" restores the seed.
@MainActor
@Observable
final class AppModel {
    var runtime: (any AppRuntime)?
#if DEBUG
    var previewAction: (() -> Void)?

    /// A separate local model: entering review mode never authenticates the live app.
    static func uiReviewPreview() -> AppModel {
        let preview = AppModel()
        preview.enterDemo()
        return preview
    }
#endif
    let isLive: Bool
    var busy: Bool { runtime?.busy ?? false }

    init(live: Bool = false) {
        isLive = live
        if live { clearLiveData() }
    }

    func clearLiveData() {
        me = Person(id: "me", name: "", belt: .white, stripes: 0, gym: "", hue: .coral)
        gyms = []; cameraRoll = []
        people = [:]; friends = []; posts = []; upcoming = []; toComplete = nil
        notifications = []; drafts = []; path = []; toast = nil; highlight = nil; fresh = nil
        goals = []; sessionGoals = [:]; goalAccount = nil
    }

    private func send(_ operation: String, _ payload: [String: Any], success: (() -> Void)? = nil) {
        guard let runtime else { return }
        Task { if await runtime.perform(operation, payload) { success?() } }
    }

    // MARK: Data
    var me = SeedData.me
    var people = SeedData.people
    var friends = SeedData.friends
    var posts = SeedData.posts
    var upcoming = SeedData.upcoming
    var toComplete: Session? = SeedData.toComplete
    var notifications = SeedData.notifications
    var drafts: [Session] = []
    var gyms = SeedData.gyms
    var cameraRoll = SeedData.cameraRoll
    /// What you're working on. Personal and local to this device.
    var goals = SeedData.goals
    /// Session id → goal id for sessions you've attached a goal to.
    var sessionGoals = SeedData.sessionGoals
    /// The signed-in account whose goals are loaded (installed app only).
    @ObservationIgnored private var goalAccount: String?

    // MARK: Navigation & feedback
    var tab: AppTab = .activity
    var path: [Route] = []
    var toast: MMToastData?
    /// Post to highlight in the feed right after publishing.
    var highlight: String?
    /// "sessionId + personId" of the attendee row that just joined (plays the join animation).
    var fresh: String?
    var showDemoPanel = false
    /// Prototype-only entry state; this is not a Google authentication session.
    var isSignedIn = false

    @ObservationIgnored private var timers: [Task<Void, Never>] = []

    // MARK: Lookups

    func person(_ id: String) -> Person {
        if id == "me" { return me }
        return people[id] ?? Person(id: id, name: "Someone", belt: .white, stripes: 0, gym: "", hue: .coral)
    }

    func post(_ id: String) -> Post? { posts.first { $0.id == id } }

    func findSession(_ id: String) -> Session? {
        if let s = upcoming.first(where: { $0.id == id }) { return s }
        if let s = toComplete, s.id == id { return s }
        return drafts.first(where: { $0.id == id })
    }

    func friendship(_ id: String) -> Friendship? { friends.first { $0.id == id } }

    func goal(_ id: String) -> MatGoal? { goals.first { $0.id == id } }

    /// The goal you attached to a session, if it still exists.
    func goal(forSession sessionID: String) -> MatGoal? { sessionGoals[sessionID].flatMap { goal($0) } }

    /// The soonest planned session this goal is attached to.
    func nextSession(forGoal goalID: String) -> Session? {
        plannedSessions.first { sessionGoals[$0.id] == goalID }
    }

    /// Invitations and accepted plans only; declined sessions do not fill the schedule.
    var plannedSessions: [Session] {
        upcoming.filter { ($0.status(of: "me") == .going || $0.status(of: "me") == .invited) && (!isLive || $0.id != toComplete?.id) }
    }

    var unreadCount: Int { notifications.filter(\.unread).count }

    /// The Friends tab shows a dot while any live streak still needs this week's session.
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

    func back() { if !path.isEmpty { path.removeLast() } }

    func replace(_ route: Route) {
        if !path.isEmpty { path.removeLast() }
        path.append(route)
    }

    func setTab(_ newTab: AppTab) {
        path = []
        tab = newTab
    }

    func copySessionLink(_ id: String) {
        if let runtime { Task { await runtime.copySessionLink(id) } }
        else { showToast("Invite link copied", .success) }
    }

    // MARK: Feedback

    func showToast(_ message: String, _ variant: MMToastVariant = .neutral) {
        let data = MMToastData(message: message, variant: variant)
        toast = data
        later(2.6) { [weak self] in
            if self?.toast?.id == data.id { self?.toast = nil }
        }
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
    }

    func like(_ id: String) {
        if isLive { send("set_like", ["post_id": id, "liked": !(post(id)?.likes.contains("me") ?? false)]); return }
        updatePost(id) { p in
            if p.likes.contains("me") { p.likes.removeAll { $0 == "me" } } else { p.likes.insert("me", at: 0) }
        }
    }

    func comment(_ id: String, _ text: String) {
        if isLive { send("add_comment", ["post_id": id, "body": text]); return }
        updatePost(id) { $0.comments.append(Comment(who: "me", text: text, fresh: true)) }
    }

    func editCaption(_ id: String, _ caption: String) {
        if isLive { send("edit_post", ["post_id": id, "caption": caption]); return }
        updatePost(id) { $0.caption = caption }
        showToast("Caption updated", .success)
    }

    func deletePost(_ id: String) {
        if isLive { send("delete_post", ["post_id": id], success: { self.back() }); return }
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
        if let runtime {
            Task { if let id = await runtime.create(d) { replace(d.past ? .complete(id: id) : .session(id: id)) } }
            return
        }
        guard !isLive else { return }
        guard TrainingFocusTree.isValid(d.focusItems) else {
            showToast("Name each focus, or remove the blank one.")
            return
        }
        let id = "n\(Int(Date().timeIntervalSince1970 * 1000))"
        var people = [Attendee(id: "me", status: .going)]
        people += d.invited.map { Attendee(id: $0, status: d.past ? .going : .invited) }
        let session = Session(id: id, title: d.title, day: d.day, date: d.date, month: d.month, time: d.time, gym: d.gym,
                              organizer: "me", privacy: d.privacy, people: people, note: d.note.isEmpty ? nil : d.note,
                              focusItems: TrainingFocusTree.normalized(d.focusItems))
        if d.past {
            drafts.append(session)
            replace(.complete(id: id))
            return
        }
        upcoming.append(session)
        replace(.session(id: id))
        showToast(d.invited.isEmpty ? "Session created" : "Invites sent to \(d.invited.count)", .success)
        // The first two invitees accept live, so the plan-together journey feels real.
        for (i, pid) in d.invited.prefix(2).enumerated() {
            later(2.2 + Double(i) * 2) { [weak self] in
                guard let self else { return }
                self.updateSession(id) { $0.set(pid, .going) }
                self.notifications.insert(AppNotification(id: "j\(UUID().uuidString)", kind: .joined, who: pid,
                                                          text: "joined \(d.title)", time: "now", unread: true), at: 0)
                self.fresh = id + pid
                self.showToast("\(self.person(pid).firstName) joined \(d.title)", .friend)
            }
        }
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
        } else if toComplete?.id == sessionID {
            toComplete?.focusItems = normalized
        } else {
            return false
        }
        showToast("Focus plan updated", .success)
        return true
    }

    func publish(_ sessionID: String, photo: String?, caption: String, people: [String]) -> PublishResult? {
        if isLive { return nil }
        guard let s = findSession(sessionID) else { return nil }
        let post = Post(id: "p\(Int(Date().timeIntervalSince1970 * 1000))", organizer: "me", title: s.title, gym: s.gym,
                        date: "\(s.day), \(s.month) \(s.date)", ago: "now", photo: photo, participants: people,
                        caption: caption, likes: [], extraLikes: 0, comments: [], focusItems: s.focusItems)
        let streaks = friends
            .filter { people.contains($0.id) && $0.thisWeek != .done }
            .map { StreakTick(id: $0.id, from: $0.streak, to: $0.streak + 1, friendship: $0) }
        posts.insert(post, at: 0)
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
                $0.comments.append(Comment(who: "alex", text: "Great rounds today. Same time next week?", fresh: true))
            }
            self?.showToast("Alex commented on your post")
        }
    }

    func addFriend(_ id: String) {
        if isLive { return }
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
        return true
    }

    func deleteGoal(_ id: String) {
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
        timers.forEach { $0.cancel() }
        timers = []
        me = SeedData.me
        people = SeedData.people
        friends = SeedData.friends
        posts = SeedData.posts
        upcoming = SeedData.upcoming
        toComplete = SeedData.toComplete
        notifications = SeedData.notifications
        goals = SeedData.goals
        sessionGoals = SeedData.sessionGoals
        drafts = []
        path = []
        toast = nil
        highlight = nil
        fresh = nil
    }

    /// Deep links from the web prototype's review panel (`index.html#…`).
    enum Preset: String, CaseIterable, Identifiable {
        case welcome, activity, training, create, complete, friends, qr, profile, notifications
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
        case .friends: setTab(.friends)
        case .profile: setTab(.profile)
        case .create: setTab(.training); go(.create())
        case .focusPlan: setTab(.training); go(.create(focus: TrainingFocusTree.example))
        case .complete: setTab(.training); go(.complete(id: "c1"))
        case .qr: setTab(.friends); go(.qr())
        case .scan: setTab(.friends); go(.qr(scan: true))
        case .notifications: setTab(.activity); go(.notifications)
        case .post: setTab(.activity); go(.post(id: "p1"))
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
        case .broken: setTab(.friends); go(.friend(id: "jamie"))
        case .active: setTab(.friends); go(.friend(id: "sarah"))
        }
    }
}
