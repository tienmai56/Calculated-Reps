import Observation
import SwiftUI

/// All prototype state and actions, ported from `useApp()` in `ui_kits/app/App.jsx`.
/// Everything is in memory; "Reset demo" restores the seed.
@MainActor
@Observable
final class AppModel {
    // MARK: Data
    var me = SeedData.me
    var people = SeedData.people
    var friends = SeedData.friends
    var posts = SeedData.posts
    var upcoming = SeedData.upcoming
    var toComplete: Session? = SeedData.toComplete
    var notifications = SeedData.notifications
    var drafts: [Session] = []
    let gyms = SeedData.gyms
    let cameraRoll = SeedData.cameraRoll

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

    /// Invitations and accepted plans only; declined sessions do not fill the schedule.
    var plannedSessions: [Session] {
        upcoming.filter { $0.status(of: "me") == .going || $0.status(of: "me") == .invited }
    }

    var unreadCount: Int { notifications.filter(\.unread).count }

    /// The Friends tab shows a dot while any live streak still needs this week's session.
    var friendsNeedAttention: Bool { friends.contains { $0.streak > 0 && $0.thisWeek == .pending } }

    // MARK: Navigation

    func enterDemo() {
        setTab(.activity)
        isSignedIn = true
    }

    func signOutOfDemo() {
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
        updatePost(id) { p in
            if p.likes.contains("me") { p.likes.removeAll { $0 == "me" } } else { p.likes.insert("me", at: 0) }
        }
    }

    func comment(_ id: String, _ text: String) {
        updatePost(id) { $0.comments.append(Comment(who: "me", text: text, fresh: true)) }
    }

    func editCaption(_ id: String, _ caption: String) {
        updatePost(id) { $0.caption = caption }
        showToast("Caption updated", .success)
    }

    func deletePost(_ id: String) {
        posts.removeAll { $0.id == id }
        back()
        showToast("Post deleted from every profile")
    }

    func removeMe(from id: String) {
        updatePost(id) { $0.participants.removeAll { $0 == "me" } }
        back()
        showToast("You're off that post. It's gone from your profile.")
    }

    func rsvp(_ sessionID: String, _ status: RSVP) {
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
        updateSession(sessionID) { $0.people.removeAll { $0.id == personID } }
        showToast("\(person(personID).firstName) removed")
    }

    func addParticipants(_ sessionID: String, _ ids: [String]) {
        updateSession(sessionID) { s in ids.forEach { s.set($0, .going) } }
        if let first = ids.first { fresh = sessionID + first }
        showToast("Added \(ids.count) to the session", .success)
    }

    func createSession(_ d: SessionDraft) {
        let id = "n\(Int(Date().timeIntervalSince1970 * 1000))"
        var people = [Attendee(id: "me", status: .going)]
        people += d.invited.map { Attendee(id: $0, status: d.past ? .going : .invited) }
        let session = Session(id: id, title: d.title, day: d.day, date: d.date, month: d.month, time: d.time, gym: d.gym,
                              organizer: "me", privacy: d.privacy, people: people, note: d.note.isEmpty ? nil : d.note)
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

    func publish(_ sessionID: String, photo: String?, caption: String, people: [String]) -> PublishResult? {
        guard let s = findSession(sessionID) else { return nil }
        let post = Post(id: "p\(Int(Date().timeIntervalSince1970 * 1000))", organizer: "me", title: s.title, gym: s.gym,
                        date: "\(s.day), \(s.month) \(s.date)", ago: "now", photo: photo, participants: people,
                        caption: caption, likes: [], extraLikes: 0, comments: [])
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
        guard !friends.contains(where: { $0.id == id }) else { return }
        friends.insert(Friendship(id: id, weeks: Array(repeating: false, count: 9), thisWeek: .pending, best: 0, together: 0), at: 0)
    }

    func readAll() {
        for i in notifications.indices { notifications[i].unread = false }
    }

    func updateMe(name: String, email: String, belt: BeltRank, stripes: Int) {
        me.name = name
        me.email = email
        me.belt = belt
        me.stripes = stripes
    }

    // MARK: Demo

    func reset() {
        timers.forEach { $0.cancel() }
        timers = []
        me = SeedData.me
        people = SeedData.people
        friends = SeedData.friends
        posts = SeedData.posts
        upcoming = SeedData.upcoming
        toComplete = SeedData.toComplete
        notifications = SeedData.notifications
        drafts = []
        path = []
        toast = nil
        highlight = nil
        fresh = nil
    }

    /// Deep links from the web prototype's review panel (`index.html#…`).
    enum Preset: String, CaseIterable, Identifiable {
        case welcome, activity, training, create, complete, friends, qr, profile, notifications
        case empty, firstSession, awaitingPhoto, invite, active, broken, scan, post
        var id: String { rawValue }
    }

    func run(_ preset: Preset) {
        reset()
        isSignedIn = preset != .welcome
        switch preset {
        case .welcome: break
        case .activity: setTab(.activity)
        case .training: setTab(.training)
        case .friends: setTab(.friends)
        case .profile: setTab(.profile)
        case .create: setTab(.training); go(.create())
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
