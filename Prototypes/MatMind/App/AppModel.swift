import Observation
import SwiftUI

/// Live services are supplied by the installed app; the preview keeps its demo adapter.
@MainActor
protocol AppRuntime: AnyObject {
    var busy: Bool { get }
    func authenticate() async
    func signOut() async
    func perform(_ operation: String, _ payload: [String: Any]) async -> Bool
    /// Asks for push permission and registers this device. Returns nil on success, or the
    /// message to show, so a caller inside a sheet can display it (the app-level alert sits under sheets).
    func enableNotifications() async -> String?
    func create(_ draft: SessionDraft, key: UUID) async -> String?
    func publish(_ sessionID: String, photo: String?, caption: String, people: [String]) async -> PublishResult?
    /// Uploads a square JPEG (from `AppModel.avatarJPEG`) and makes it the signed-in member's profile photo.
    func saveAvatar(_ jpeg: Data) async -> Bool
    func friendCode() async -> String?
    func connect(_ value: String) async -> String?
    func copySessionLink(_ sessionID: String) async
    func saveFocus(_ sessionID: String, _ items: [TrainingFocus]) async -> Bool
    func editSession(_ sessionID: String, title: String, startsAt: Date, gym: String, note: String) async -> Bool
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
    let isLive: Bool
    var busy: Bool { creatingSessions || (runtime?.busy ?? false) }
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
        resetSessionCreation()
        me = Person(id: "me", name: "", belt: .white, stripes: 0, gym: "", hue: .coral)
        gyms = []; cameraRoll = []
        people = [:]; friends = []; posts = []; upcoming = []; completedSessions = []; toComplete = nil
        notifications = []; drafts = []; path = []; toast = nil; highlight = nil; fresh = nil
        goals = []; sessionGoals = [:]; goalAccount = nil
        sharedGoals = []; sharedGoalIDs = [:]; goalRecipients = [:]; goalPublishes = [:]
    }

    private func send(_ operation: String, _ payload: [String: Any], success: (() -> Void)? = nil) {
        guard let runtime else { return }
        Task { if await runtime.perform(operation, payload) { success?() } }
    }

    // MARK: Data
    var me = Person(id: "me", name: "", belt: .white, stripes: 0, gym: "", hue: .coral)
    var people: [String: Person] = [:]
    var friends: [Friendship] = []
    var posts: [Post] = []
    var upcoming: [Session] = []
    var completedSessions: [Session] = []
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
        return drafts.first(where: { $0.id == id }) ?? completedSessions.first(where: { $0.id == id })
    }

    func friendship(_ id: String) -> Friendship? { friends.first { $0.id == id } }

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
        if let i = drafts.firstIndex(where: { $0.id == id }) { change(&drafts[i]) }
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
        updatePost(id) { $0.comments.append(Comment(who: "me", text: text, fresh: true)) }
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

    @discardableResult
    func createSessions(_ requests: [SessionCreationRequest]) async -> Bool {
        guard !busy, !requests.isEmpty,
              requests.allSatisfy({ TrainingFocusTree.isValid($0.draft.focusItems) }),
              requests.count == 1 || requests.allSatisfy({ !$0.draft.past }),
              runtime != nil || !isLive else { return false }
        if isLive {
            guard requests.allSatisfy({ $0.draft.startsAt != nil && !$0.draft.gym.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { return false }
        }
        let generation = creationGeneration
        let goalToAttach = requests[0].draft.past ? nil : pendingPlanGoal
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
                self.notifications.insert(AppNotification(id: "j\(UUID().uuidString)", kind: .joined, who: pid,
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
                        caption: caption, likes: [], extraLikes: 0, comments: [], focusItems: s.focusItems,
                        occurredAt: s.startsAt ?? Date(), time: s.time)
        let streaks = friends
            .filter { people.contains($0.id) && $0.thisWeek != .done }
            .map { StreakTick(id: $0.id, from: $0.streak, to: $0.streak + 1, friendship: $0) }
        posts.insert(post, at: 0)
        completedSessions.append(s)
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

    /// Host only: change a planned session's name, time, gym or note. People and focus plan stay.
    func editSession(_ id: String, title: String, startsAt: Date, gym: String, note: String) async -> Bool {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let gym = gym.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !gym.isEmpty, findSession(id)?.organizer == "me" else { return false }
        if let runtime {
            guard await runtime.editSession(id, title: title, startsAt: startsAt, gym: gym, note: note) else { return false }
            showToast("Session updated", .success)
            return true
        }
        guard !isLive else { return false }
        updateSession(id) { s in
            s.title = title
            s.gym = gym
            s.note = note.isEmpty ? nil : note
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

    /// "Plan a session for this": opens the plan form; the new session gets this goal.
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
        resetSessionCreation()
        timers.forEach { $0.cancel() }
        timers = []
#if DEBUG || MAT_MIND_PROTOTYPE
        me = SeedData.me
        people = SeedData.people
        friends = SeedData.friends
        posts = SeedData.posts
        upcoming = SeedData.upcoming
        toComplete = SeedData.toComplete
        notifications = SeedData.notifications
        gyms = SeedData.gyms
        cameraRoll = SeedData.cameraRoll
        goals = SeedData.goals
        sessionGoals = SeedData.sessionGoals
        sharedGoals = SeedData.sharedGoals
        sharedGoalIDs = [:]
        goalRecipients = [:]
#endif
        drafts = []
        completedSessions = []
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
        case .friends: setTab(.profile); go(.friends)
        case .profile: setTab(.profile)
        case .create: setTab(.training); go(.create())
        case .focusPlan: setTab(.training); go(.create(focus: TrainingFocusTree.example))
        case .complete: setTab(.training); go(.complete(id: "c1"))
        case .qr: setTab(.profile); go(.qr())
        case .scan: setTab(.profile); go(.qr(scan: true))
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
        case .broken: setTab(.profile); go(.friends); go(.friend(id: "jamie"))
        case .active: setTab(.profile); go(.friends); go(.friend(id: "sarah"))
        }
    }
}
