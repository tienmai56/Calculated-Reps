import SwiftUI

/// The installed app renders the same screens as MatMindPrototype, backed by live services.
struct MatMindRoot: View {
    @State var model: SocialAppModel
    @State private var ui = AppModel(live: true)
    @State private var runtime: LiveMatMindRuntime?
    @Environment(\.scenePhase) private var phase

    var body: some View {
        MMAppShell()
            .disabled(model.busy)
            .environment(ui)
            .environment(model)
            .task {
                let services = LiveMatMindRuntime(model: model, ui: ui)
                runtime = services
                ui.runtime = services
                await model.start()
                services.sync()
                await services.loadPhotos()
                openNotification()
                if model.me != nil, let pending = model.pendingLink { await redeemLink(pending) }
            }
            .onChange(of: model.snapshot) { old, new in
                runtime?.sync()
                if !old.profiles.contains(where: { $0.id == model.userID }), model.me != nil, let pending = model.pendingLink {
                    Task { await redeemLink(pending) }
                }
            }
            .onChange(of: model.userID) { _, _ in runtime?.sync() }
            .onChange(of: phase) { _, phase in
                if phase == .active { Task { await model.refresh(); await runtime?.loadPhotos() } }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MatMindPushOpen"))) { _ in
                Task { await model.refresh(); runtime?.sync(); openNotification() }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MatMindPushToken"))) { _ in
                Task { await SocialPushCoordinator.register(in: model) }
            }
            .onOpenURL { url in
                model.handle(url)
                guard model.pendingLink == url else { return }
            }
            .onChange(of: model.pendingLink) { _, value in
                if let value, model.me != nil { Task { await redeemLink(value) } }
            }
            .overlay {
                if model.userID != nil && model.me == nil { LiveProfileSetup() .environment(model) }
            }
            .overlay(alignment: .top) {
                if model.busy { ProgressView().padding(12).background(.regularMaterial, in: Capsule()) }
            }
            .alert("Couldn’t complete that", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                Button("OK") { model.error = nil }
            } message: { Text(model.error ?? "") }
            .refreshable { await model.refresh(); await runtime?.loadPhotos() }
            .preferredColorScheme(.light)
            .tint(MMColor.accent)
    }

    private func redeemLink(_ url: URL) async {
        if let friendID = await runtime?.connect(url.absoluteString) { ui.go(.friend(id: friendID)) }
    }

    private func openNotification() {
        guard model.userID != nil, let info = SocialPushCoordinator.pending,
              let id = info["entity_id"] as? String else { return }
        let kind = info["kind"] as? String
        ui.go(kind == "invite" || kind == "joined" ? .session(id: id) : .post(id: id))
        SocialPushCoordinator.pending = nil
    }
}

private struct LiveProfileSetup: View {
    @Environment(SocialAppModel.self) private var app
    @State private var name = ""
    @State private var gym = ""
    @State private var belt = "white"
    @State private var stripes = "0"
    var body: some View {
        MMScreen {
            MMHeader(title: "Your mat profile")
        } content: {
            VStack(alignment: .leading, spacing: 20) {
                Text("Let your people find you.").mmFont(.display, 30)
                MMTextField(label: "Name", text: $name)
                MMTextField(label: "Home gym", text: $gym)
                MMSelect(label: "Belt", options: BeltRank.adultRanks.map(\.rawValue), selection: $belt)
                MMSelect(label: "Stripes", options: ["0", "1", "2", "3", "4"], selection: $stripes)
                MMButton("Sign out", variant: .ghost) { Task { await app.logout() } }
            }.padding(24)
        } footer: {
            MMButton("Continue", size: .lg, fullWidth: true) {
                Task { await app.perform("save_profile", ["name": name.trimmingCharacters(in: .whitespacesAndNewlines), "gym": gym, "belt": belt, "stripes": Int(stripes) ?? 0, "timezone": TimeZone.current.identifier]) }
            }.disabled(app.busy || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

@MainActor
final class LiveMatMindRuntime: AppRuntime {
    let model: SocialAppModel
    unowned let ui: AppModel
    private var photos: [String: String] = [:]
    private var connecting = false
    private var publishKeys: [String: UUID] = [:]
    private var mediaKeys: [String: UUID] = [:]
    private var publishRequests: [String: String] = [:]
    private var mediaPhotos: [String: String] = [:]
    var busy: Bool { model.busy }

    init(model: SocialAppModel, ui: AppModel) { self.model = model; self.ui = ui }
    private func localID(_ id: String) -> String { id == model.userID ? "me" : id }
    private func cloudID(_ id: String) -> String { id == "me" ? model.userID ?? "" : id }
    private func dateText(_ date: Date, _ format: String) -> String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = format
        return formatter.string(from: date)
    }
    private func person(_ row: SocialRow) -> Person {
        Person(id: localID(row.id), name: row.text("name"), belt: BeltRank(rawValue: row.text("belt")) ?? .white,
               stripes: row.number("stripes"), gym: row.text("gym"), hue: .mint)
    }
    func sync() {
        guard model.userID != nil else { ui.clearLiveData(); ui.isSignedIn = false; return }
        ui.isSignedIn = true
        ui.me = model.me.map(person) ?? Person(id: "me", name: "", belt: .white, stripes: 0, gym: "", hue: .coral)
        ui.people = Dictionary(uniqueKeysWithValues: model.snapshot.profiles.filter { $0.id != model.userID }.map { (localID($0.id), person($0)) })
        ui.gyms = Array(Set(model.snapshot.profiles.map { $0.text("gym") }.filter { !$0.isEmpty })).sorted()
        var calendar = Calendar(identifier: .gregorian); calendar.firstWeekday = 2; calendar.minimumDaysInFirstWeek = 4
        ui.friends = model.snapshot.friendships.filter { $0.flag("active") }.map { row in
            calendar.timeZone = TimeZone(identifier: row.text("timezone")) ?? .current
            let serverNow = model.snapshot.server_time.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()
            let week = calendar.dateInterval(of: .weekOfYear, for: serverNow)!.start
            let credits = model.snapshot.credits.filter { $0.text("friendship_id") == row.id }
            let formatter = DateFormatter(); formatter.calendar = calendar; formatter.timeZone = calendar.timeZone; formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"
            let buckets = Set(credits.map { $0.text("week_start") })
            let weeks = (-9 ... -1).map { offset in buckets.contains(formatter.string(from: calendar.date(byAdding: .weekOfYear, value: offset, to: week)!)) }
            let other = row.text("a") == model.userID ? row.text("b") : row.text("a")
            return Friendship(id: other, weeks: weeks, thisWeek: buckets.contains(formatter.string(from: week)) ? .done : .pending,
                              best: model.streak(row).best, together: credits.count, currentStreak: model.streak(row).current)
        }
        ui.upcoming = model.snapshot.sessions.filter { $0.text("status") == "planned" }.map { row in
            let date = row.date("starts_at") ?? Date()
            let content = SessionNoteCodec.decode(row.text("note"))
            return Session(id: row.id, title: row.text("title"), day: dateText(date, "EEE"), date: Int(dateText(date, "d")) ?? 1,
                           month: dateText(date, "MMM"), time: dateText(date, "h:mm a"), gym: row.text("venue"), organizer: localID(row.text("organizer")),
                           privacy: Privacy(rawValue: row.text("join_mode")) ?? .friends,
                           people: model.attendees(row.id).map { Attendee(id: localID($0.text("user_id")), status: RSVP(rawValue: $0.text("rsvp")) ?? .invited) },
                           note: content.note.isEmpty ? nil : content.note, focusItems: content.focus)
        }
        ui.toComplete = ui.upcoming.first { session in
            session.organizer == "me" && (model.session(session.id)?.date("starts_at") ?? .distantFuture) <= Date()
        }
        ui.posts = model.snapshot.posts.filter { $0.text("deleted_at").isEmpty }.map { row in
            let date = row.date("occurred_at") ?? Date()
            return Post(id: row.id, organizer: localID(row.text("author")), title: row.text("title"), gym: row.text("venue"),
                        date: dateText(date, "EEE, MMM d"), ago: RelativeDateTimeFormatter().localizedString(for: row.date("published_at") ?? date, relativeTo: Date()),
                        photo: photos[row.text("media_id")], participants: model.snapshot.tags.filter { $0.text("post_id") == row.id && $0.flag("visible") }.map { localID($0.text("user_id")) },
                        caption: row.text("caption"), likes: model.snapshot.likes.filter { $0.text("post_id") == row.id }.map { localID($0.text("user_id")) }, extraLikes: 0,
                        comments: model.snapshot.comments.filter { $0.text("post_id") == row.id }.map { Comment(who: localID($0.text("author")), text: $0.text("body")) },
                        focusItems: model.session(row.text("session_id")).map { SessionNoteCodec.decode($0.text("note")).focus } ?? [])
        }
        ui.notifications = model.snapshot.notifications.map { row in
            AppNotification(id: row.id, kind: AppNotification.Kind(rawValue: row.text("kind")) ?? .published,
                            who: localID(row.text("actor")), session: row.text("entity_id"), text: row.text("message"),
                            time: RelativeDateTimeFormatter().localizedString(for: row.date("created_at") ?? Date(), relativeTo: Date()), unread: row.text("read_at").isEmpty)
        }
    }
    func loadPhotos() async {
        let owner = model.userID
        for row in model.snapshot.media where photos[row.id] == nil {
            do {
                let data = try await model.backend.image(key: row.text("object_key"))
                guard model.userID == owner else { return }
                let path = FileManager.default.temporaryDirectory.appendingPathComponent("matmind-\(row.id).jpg")
                try data.write(to: path, options: .atomic); photos[row.id] = path.path
            } catch { continue }
        }
        sync()
    }
    func authenticate() async {
        await model.authenticate("google"); sync()
        if model.userID != nil, model.me != nil, let pending = model.pendingLink { _ = await connect(pending.absoluteString) }
    }
    func signOut() async { await model.logout(); photos = [:]; sync() }
    func perform(_ operation: String, _ payload: [String: Any]) async -> Bool {
        if operation == "sign_in_apple" { await model.authenticate("apple"); sync(); return model.userID != nil }
        if operation == "enable_notifications" { await SocialPushCoordinator.register(in: model); return model.error == nil }
        if operation == "delete_account" { await model.deleteAccount(); sync(); return model.userID == nil }
        if operation == "load_more_feed" { await model.loadMoreFeed(); await loadPhotos(); return true }
        if operation == "load_more_comments", let id = payload["post_id"] as? String { await model.loadMoreComments(id); sync(); return true }
        var body = payload
        if let id = body["user_id"] as? String { body["user_id"] = cloudID(id) }
        if ["edit_post", "delete_post"].contains(operation), let id = body["post_id"] as? String {
            body["version"] = model.snapshot.posts.first { $0.id == id }?.number("version")
        }
        let result = await model.perform(operation, body)
        sync()
        return result != nil
    }
    func create(_ draft: SessionDraft) async -> String? {
        guard let date = draft.startsAt, !draft.gym.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            model.error = "Choose a date, time and gym."; return nil
        }
        let result = await model.perform("create_session", ["title": draft.title, "starts_at": ISO8601DateFormatter().string(from: date), "timezone": TimeZone.current.identifier,
                                                          "venue": draft.gym, "note": SessionNoteCodec.encode(note: draft.note, focus: draft.focusItems),
                                                          "invited": draft.invited.map(cloudID), "join_mode": draft.privacy.rawValue])
        // Past sessions require the organizer to confirm attendance before publishing.
        if draft.past, let id = result?["id"]?.string {
            for person in draft.invited { _ = await model.perform("manage_participant", ["session_id": id, "user_id": cloudID(person), "remove": false]) }
        }
        sync(); return result?["id"]?.string
    }
    func publish(_ sessionID: String, photo: String?, caption: String, people: [String]) async -> PublishResult? {
        let before = ui.friends
        do {
            var payload: [String: Any] = ["session_id": sessionID, "caption": caption, "attendees": people.map(cloudID)]
            if let photo {
                let data = try Data(contentsOf: URL(fileURLWithPath: photo))
                if mediaPhotos[sessionID] != photo { mediaKeys[sessionID] = UUID(); mediaPhotos[sessionID] = photo }
                let mediaKey = mediaKeys[sessionID] ?? UUID(); mediaKeys[sessionID] = mediaKey
                let media = try await model.backend.command("prepare_media", payload: ["session_id": sessionID], key: mediaKey)
                guard let id = media["id"]?.string, let objectKey = media["object_key"]?.string else { throw CloudError(message: "Could not prepare photo.") }
                do { try await model.backend.upload(data, objectKey: objectKey) }
                catch { let existing = try await model.backend.image(key: objectKey); guard existing == data else { throw error } }
                payload["media_id"] = id
            }
            let request = caption + "|" + people.sorted().joined(separator: ",") + "|" + (photo ?? "")
            if publishRequests[sessionID] != request { publishKeys[sessionID] = UUID(); publishRequests[sessionID] = request }
            let key = publishKeys[sessionID] ?? UUID(); publishKeys[sessionID] = key
            guard let result = await model.perform("complete_and_publish", payload, key: key), let id = result["id"]?.string else { return nil }
            await loadPhotos()
            guard let post = ui.post(id) else { model.error = "Published. Refresh Activity to see your post."; return nil }
            let ticks = ui.friends.compactMap { friend -> StreakTick? in
                guard let old = before.first(where: { $0.id == friend.id }), friend.streak > old.streak else { return nil }
                return StreakTick(id: friend.id, from: old.streak, to: friend.streak, friendship: old)
            }
            return PublishResult(post: post, streaks: ticks)
        } catch { model.error = error.localizedDescription; return nil }
    }
    func friendCode() async -> String? {
        guard let result = await model.perform("friend_token", [:]), let token = result["token"]?.string else { return nil }
        return model.link(kind: "friend", token: token).absoluteString
    }
    func connect(_ value: String) async -> String? {
        guard !connecting, !model.busy else { return nil }
        connecting = true
        defer { connecting = false }
        guard let url = URL(string: value) else { model.error = "Invalid invitation link."; return nil }
        model.handle(url)
        guard model.pendingLink == url else { model.error = "Invalid invitation link."; return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        let kind = url.scheme == "matmind" ? url.host : parts.first
        let token = parts.last ?? ""
        guard model.userID != nil, token.count == 64, token.allSatisfy(\.isHexDigit), ["friend", "session"].contains(kind ?? "") else {
            model.error = "Sign in and open a valid invitation link."; return nil
        }
        guard let result = await model.perform(kind == "friend" ? "redeem_friend" : "join_link", ["token": token]) else { return nil }
        model.pendingLink = nil; sync()
        if kind == "session", let id = result["id"]?.string { ui.go(.session(id: id)); return nil }
        return result["id"]?.string
    }
    func copySessionLink(_ sessionID: String) async {
        guard let result = await model.perform("session_token", ["session_id": sessionID]), let token = result["token"]?.string else { return }
        UIPasteboard.general.url = model.link(kind: "session", token: token)
        ui.showToast("Invite link copied", .success)
    }
    func saveFocus(_ sessionID: String, _ items: [TrainingFocus]) async -> Bool {
        guard let row = model.session(sessionID), TrainingFocusTree.isValid(items) else { return false }
        let old = SessionNoteCodec.decode(row.text("note"))
        let result = await model.perform("edit_session", ["session_id": sessionID, "version": row.number("version"), "title": row.text("title"),
                                                       "starts_at": row.text("starts_at"), "timezone": row.text("timezone"), "venue": row.text("venue"),
                                                       "note": SessionNoteCodec.encode(note: old.note, focus: items)])
        sync(); return result != nil
    }
    func scannerView(found: @escaping (String) -> Void) -> AnyView { AnyView(LiveScannerView(found: found)) }
    func exportView() -> AnyView {
        AnyView(NavigationStack { PreviousTrainingDataScreen(model: model.archive, exportOnly: true) })
    }
}
