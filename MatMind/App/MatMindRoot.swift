import SwiftUI
import PhotosUI
import CryptoKit

/// The installed app renders the same screens as MatMindPrototype, backed by live services.
struct MatMindRoot: View {
    @State var model: SocialAppModel
    @State private var ui = AppModel(live: true)
    @State private var runtime: LiveMatMindRuntime?
    @Environment(\.scenePhase) private var phase
#if DEBUG
    @State private var previewModel: AppModel?
#endif

    var body: some View {
#if DEBUG
        Group {
            if let previewModel {
                MMAppShell()
                    .environment(previewModel)
                    .safeAreaInset(edge: .top, spacing: 0) {
                        HStack {
                            Text("UI preview · sample data").mmFont(.body, 12, .semibold)
                            Spacer()
                            Button("Exit preview") { self.previewModel = nil }
                                .mmFont(.body, 12, .bold)
                        }
                        .foregroundStyle(MMColor.ink900)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(MMColor.sun100)
                    }
                    .preferredColorScheme(.light)
                    .tint(MMColor.accent)
            } else {
                liveShell
            }
        }
#else
        liveShell
#endif
    }

    private var liveShell: some View {
        MMAppShell()
            .disabled(model.busy)
            .environment(ui)
            .environment(model)
            .task {
                let services = LiveMatMindRuntime(model: model, ui: ui)
                runtime = services
                ui.runtime = services
                ui.readGoalExport = { url in try LegacyGoalImporter.read(url).goals }
#if DEBUG
                ui.previewAction = {
                    model.error = nil
                    previewModel = AppModel.uiReviewPreview()
                }
#endif
                await model.start()
                services.sync()
                await services.loadPhotos()
                openNotification()
                if model.me != nil { await SocialPushCoordinator.register(in: model) }
                if model.me != nil, let pending = model.pendingLink { await redeemLink(pending) }
            }
            .onChange(of: model.snapshot) { old, new in
                runtime?.sync()
                if old.profiles != new.profiles || old.shared_goals != new.shared_goals { Task { await runtime?.loadPhotos() } }
                if !old.profiles.contains(where: { $0.id == model.userID }), model.me != nil {
                    // Just signed in or finished profile setup: ask once for push, then keep the token current.
                    Task { await SocialPushCoordinator.register(in: model) }
                    if let pending = model.pendingLink { Task { await redeemLink(pending) } }
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
                Task { await SocialPushCoordinator.uploadToken(in: model) }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MatMindPushFailed"))) { note in
                SocialPushCoordinator.registrationFailed(note.userInfo?["message"] as? String ?? "Apple push registration failed.", in: model)
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MatMindPushReceived"))) { _ in
                Task { await model.refresh(); await runtime?.loadPhotos() }
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
        switch kind {
        case "invite", "joined": ui.go(.session(id: id))
        case "friend": ui.go(.friend(id: id))
        case "goal_share": ui.go(.sharedGoal(id: id))
        default: ui.go(.post(id: id))
        }
        SocialPushCoordinator.pending = nil
    }
}

/// First-run profile: photo, name, phone, home gym and belt. Stripes are edited
/// later from Profile; the phone number is optional and stored privately (account settings).
private struct LiveProfileSetup: View {
    private struct CountryCode: Hashable { let code: String; let name: String }
    private static let countryCodes = [
        CountryCode(code: "+1", name: "United States / Canada"), CountryCode(code: "+44", name: "United Kingdom"),
        CountryCode(code: "+61", name: "Australia"), CountryCode(code: "+64", name: "New Zealand"),
        CountryCode(code: "+353", name: "Ireland"), CountryCode(code: "+55", name: "Brazil"),
        CountryCode(code: "+49", name: "Germany"), CountryCode(code: "+33", name: "France"),
        CountryCode(code: "+81", name: "Japan"), CountryCode(code: "+84", name: "Vietnam")
    ]

    @Environment(SocialAppModel.self) private var app
    @State private var name = ""
    @State private var countryCode = "+1"
    @State private var phone = ""
    @State private var gym = ""
    @State private var belt: BeltRank?
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var photo: Data?
    @State private var photoKey = UUID()
    @State private var photoRequest = UUID()
    @State private var loadingPhoto = false
    @State private var saving = false

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedGym: String { gym.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var phoneDigits: String { phone.filter(\.isNumber) }
    /// Optional, but if entered it must be E.164: country code + number, 7–15 digits in total (the server checks the same).
    private var phoneValid: Bool {
        if phoneDigits.isEmpty { return true }
        let totalDigits = countryCode.filter(\.isNumber).count + phoneDigits.count
        return phoneDigits.count >= 6 && (7...15).contains(totalDigits)
    }
    private var canSave: Bool {
        !trimmedName.isEmpty && !trimmedGym.isEmpty && belt != nil && phoneValid && !loadingPhoto && !saving && !app.busy
    }

    var body: some View {
        MMScreen {
            HStack {
                MMWordmark(size: 24)
                Spacer()
                MMButton("Sign out", variant: .ghost) {
                    Task { await app.logout() }
                }
                .disabled(saving || app.busy)
                .accessibilityIdentifier("profile-setup-sign-out")
            }
            .padding(.horizontal, MMLayout.gutter)
            .frame(height: MMLayout.headerHeight)
        } content: {
            VStack(alignment: .leading, spacing: 20) {
                Text("First, who's rolling?").mmFont(.display, 30).foregroundStyle(MMColor.textPrimary)
                photoRow
                MMTextField(label: "Name", required: true, placeholder: "What your partners call you", text: $name)
                    .textContentType(.name)
                phoneField
                gymField
                beltPicker
            }
            .padding(.horizontal, MMLayout.gutter)
            .padding(.top, 8)
            .padding(.bottom, 24)
        } footer: {
            MMButton("Complete my profile", size: .lg, fullWidth: true) { Task { await save() } }
                .disabled(!canSave)
        }
        .onChange(of: pickedPhoto) { _, item in
            let request = UUID()
            photoRequest = request
            loadingPhoto = item != nil
            Task { await loadPhoto(item, request: request) }
        }
    }

    private var gymField: some View {
        MMPlaceSearchField(label: "Home gym", required: true, placeholder: "Search for your academy", text: $gym)
    }

    private func fieldLabel(_ text: String, required: Bool = false) -> some View {
        MMFieldLabel(text, required: required)
    }

    private var photoRow: some View {
        HStack(spacing: 16) {
            PhotosPicker(selection: $pickedPhoto, matching: .images, photoLibrary: .shared()) {
                ZStack {
                    if let photo, let image = UIImage(data: photo) {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        Circle().fill(MMColor.paper2)
                        Circle().strokeBorder(MMColor.ink300, style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                        MMIcon("camera", size: 28, color: MMColor.textSecondary)
                    }
                }
                .frame(width: 96, height: 96)
                .clipShape(Circle())
            }
            .accessibilityLabel(photo == nil ? "Add a profile photo" : "Change profile photo")
            VStack(alignment: .leading, spacing: 4) {
                Text(photo == nil ? "Add a photo" : "Looking sharp")
                    .mmFont(.display, 17).foregroundStyle(MMColor.textPrimary)
                Text("Optional. Helps your partners spot you on the mat.")
                    .mmFont(.body, 14).foregroundStyle(MMColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if photo != nil {
                    Button("Remove photo") { photo = nil; pickedPhoto = nil }
                        .mmFont(.body, 14, .semibold)
                        .foregroundStyle(MMColor.textLink)
                        .frame(minHeight: MMLayout.tapTarget)
                }
            }
        }
    }

    private var phoneField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                fieldLabel("Phone number")
                Text("Optional").mmFont(.body, 13).foregroundStyle(MMColor.textTertiary)
            }
            HStack(spacing: 8) {
                Menu {
                    ForEach(Self.countryCodes, id: \.self) { country in
                        Button("\(country.name) \(country.code)") { countryCode = country.code }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(countryCode).font(MMFont.body(16))
                        MMIcon("chevron-down", size: 16, color: MMColor.textTertiary)
                    }
                    .foregroundStyle(MMColor.textPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: 50)
                    .background(MMColor.surfaceInput, in: RoundedRectangle(cornerRadius: MMRadius.md, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: MMRadius.md, style: .continuous).strokeBorder(MMColor.borderDefault, lineWidth: 1.5))
                }
                .accessibilityLabel("Country code \(countryCode)")
                MMTextField(placeholder: "(555) 000-0000", text: $phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .accessibilityLabel("Phone number")
            }
            Text("Private. Only you can see your number.")
                .mmFont(.body, 13).foregroundStyle(MMColor.textTertiary)
        }
    }

    private var beltPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Belt", required: true)
            HStack(spacing: 6) {
                ForEach(BeltRank.adultRanks, id: \.self) { rank in
                    let selected = belt == rank
                    Button { belt = rank } label: {
                        VStack(spacing: 7) {
                            HStack(spacing: 0) {
                                Spacer(minLength: 0)
                                Rectangle().fill(rank.barColor).frame(width: 10)
                            }
                            .frame(width: 40, height: 10)
                            .background(rank.color)
                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(MMColor.ink900.opacity(0.16), lineWidth: 1))
                            Text(rank.title).mmFont(.body, 12, .bold).foregroundStyle(MMColor.textPrimary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(selected ? MMColor.paper2 : MMColor.surfaceCard, in: RoundedRectangle(cornerRadius: MMRadius.md, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: MMRadius.md, style: .continuous)
                            .strokeBorder(selected ? MMColor.ink900 : MMColor.borderDefault, lineWidth: selected ? 2 : 1.5))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(rank.title) belt")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?, request: UUID) async {
        guard let item else { return }
        defer { if photoRequest == request { loadingPhoto = false } }
        guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data),
              let jpeg = AppModel.avatarJPEG(image) else {
            if photoRequest == request { app.error = "Couldn't read that photo. Try another one." }
            return
        }
        guard photoRequest == request else { return }
        photo = jpeg
        photoKey = UUID()
    }

    private func save() async {
        guard canSave, let belt, let userID = app.userID else { return }
        saving = true; defer { saving = false }
        var payload: [String: Any] = [
            "name": trimmedName, "gym": trimmedGym, "belt": belt.rawValue, "stripes": 0,
            "timezone": TimeZone.current.identifier
        ]
        if !phoneDigits.isEmpty { payload["phone"] = countryCode + phoneDigits }
        if let photo {
            let key = "\(userID.lowercased())/\(photoKey.uuidString.lowercased()).jpg"
            do { try await app.backend.upload(photo, objectKey: key, bucket: "avatars") }
            catch {
                // A retry after a dropped response finds the earlier upload already stored.
                guard let existing = try? await app.backend.image(key: key, bucket: "avatars"), existing == photo else {
                    app.error = "Couldn't upload your photo: \(error.localizedDescription)"
                    return
                }
            }
            payload["avatar_key"] = key
        }
        await app.perform("save_profile", payload)
    }
}

@MainActor
final class LiveMatMindRuntime: AppRuntime {
    let model: SocialAppModel
    unowned let ui: AppModel
    private var photos: [String: String] = [:]
    private var avatarPhotos: [String: String] = [:]
    private var loadingAvatars: Set<String> = []
    private var photoOwner: String?
    private let imageLoader: (String, String) async throws -> Data
    private var connecting = false
    private var publishKeys: [String: UUID] = [:]
    private var mediaKeys: [String: UUID] = [:]
    private var publishRequests: [String: String] = [:]
    private var mediaPhotos: [String: String] = [:]
    private var avatarUploadKey: UUID?
    private var avatarUploadPhoto: Data?
    /// Photos of goals shared with you: object key → downloaded file.
    private var goalPhotos: [String: String] = [:]
    private var loadingGoalPhotos: Set<String> = []
    /// Your own goal photos already in the goal-media bucket (named by content).
    private var uploadedGoalPhotos: Set<String> = []
    var busy: Bool { model.busy }

    init(model: SocialAppModel, ui: AppModel, imageLoader: ((String, String) async throws -> Data)? = nil) {
        self.model = model
        self.ui = ui
        self.imageLoader = imageLoader ?? { key, bucket in try await model.backend.image(key: key, bucket: bucket) }
    }
    private func localID(_ id: String) -> String { id == model.userID ? "me" : id }
    private func cloudID(_ id: String) -> String { id == "me" ? model.userID ?? "" : id }
    private func dateText(_ date: Date, _ format: String) -> String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = format
        return formatter.string(from: date)
    }
    private func person(_ row: SocialRow) -> Person {
        Person(id: localID(row.id), name: row.text("name"), belt: BeltRank(rawValue: row.text("belt")) ?? .white,
               stripes: row.number("stripes"), gym: row.text("gym"), hue: .mint, photo: avatarPhotos[row.text("avatar_key")], username: row.text("username"))
    }
    func sync() {
        if photoOwner != model.userID {
            ui.resetSessionCreation()
            for path in Array(photos.values) + Array(avatarPhotos.values) + Array(goalPhotos.values) { try? FileManager.default.removeItem(atPath: path) }
            photos = [:]
            avatarPhotos = [:]
            goalPhotos = [:]
            uploadedGoalPhotos = []
            photoOwner = model.userID
        }
        guard let userID = model.userID else { ui.clearLiveData(); ui.isSignedIn = false; return }
        ui.isSignedIn = true
        ui.loadGoals(account: userID)
        ui.me = model.me.map(person) ?? Person(id: "me", name: "", belt: .white, stripes: 0, gym: "", hue: .coral)
        ui.people = Dictionary(uniqueKeysWithValues: model.snapshot.profiles.filter { $0.id != model.userID }.map { (localID($0.id), person($0)) })
        ui.gyms = Array(Set(model.snapshot.profiles.map { $0.text("gym") }.filter { !$0.isEmpty })).sorted()
        var calendar = Calendar(identifier: .gregorian); calendar.firstWeekday = 2; calendar.minimumDaysInFirstWeek = 4
        ui.friends = model.snapshot.friendships.filter { $0.flag("active") }.map { row in
            calendar.timeZone = TimeZone(identifier: row.text("timezone")) ?? .current
            let clock = ISO8601DateFormatter(); clock.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let serverNow = model.snapshot.server_time.flatMap { clock.date(from: $0) ?? ISO8601DateFormatter().date(from: $0) } ?? Date()
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
                           note: content.note.isEmpty ? nil : content.note, focusItems: content.focus, startsAt: date)
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
                        comments: model.snapshot.comments.filter { $0.text("post_id") == row.id }.map { Comment(who: localID($0.text("author")), text: $0.text("body"), cloudID: $0.id) },
                        focusItems: model.session(row.text("session_id")).map { SessionNoteCodec.decode($0.text("note")).focus } ?? [],
                        occurredAt: date)
        }
        syncSharedGoals(userID)
        ui.notifications = model.snapshot.notifications.map { row in
            AppNotification(id: row.id, kind: AppNotification.Kind(rawValue: row.text("kind")) ?? .published,
                            who: localID(row.text("actor")), session: row.text("entity_id"), text: row.text("message"),
                            time: RelativeDateTimeFormatter().localizedString(for: row.date("created_at") ?? Date(), relativeTo: Date()), unread: row.text("read_at").isEmpty)
        }
    }
    func loadPhotos() async {
        sync()
        guard let owner = model.userID else { return }
        for row in model.snapshot.media where photos[row.id] == nil {
            do {
                let data = try await imageLoader(row.text("object_key"), "session-photos")
                guard model.userID == owner else { return }
                let path = FileManager.default.temporaryDirectory.appendingPathComponent("matmind-\(row.id).jpg")
                try data.write(to: path, options: .atomic); photos[row.id] = path.path
            } catch { continue }
        }
        let keys = Set(model.snapshot.profiles.map { $0.text("avatar_key") }.filter { !$0.isEmpty })
        for key in keys where avatarPhotos[key] == nil {
            let request = owner + ":" + key
            guard loadingAvatars.insert(request).inserted else { continue }
            defer { loadingAvatars.remove(request) }
            do {
                let data = try await imageLoader(key, "avatars")
                guard model.userID == owner else { return }
                let path = FileManager.default.temporaryDirectory.appendingPathComponent("matmind-avatar-\(UUID().uuidString).jpg")
                try data.write(to: path, options: .atomic)
                avatarPhotos[key] = path.path
            } catch { continue }
        }
        let visibleKeys = Set(model.snapshot.profiles.map { $0.text("avatar_key") })
        for key in Array(avatarPhotos.keys) where !visibleKeys.contains(key) {
            if let path = avatarPhotos.removeValue(forKey: key) { try? FileManager.default.removeItem(atPath: path) }
        }
        // Photos of goals shared with you. Your own goals show the files on this device.
        let goalKeys = Set((model.snapshot.shared_goals ?? []).filter { $0.text("owner") != owner }.flatMap { $0.values["media"]?.strings ?? [] })
        for key in goalKeys where goalPhotos[key] == nil {
            let request = owner + ":" + key
            guard loadingGoalPhotos.insert(request).inserted else { continue }
            defer { loadingGoalPhotos.remove(request) }
            do {
                let data = try await imageLoader(key, "goal-media")
                guard model.userID == owner else { return }
                let path = FileManager.default.temporaryDirectory.appendingPathComponent("matmind-goal-\(UUID().uuidString).jpg")
                try data.write(to: path, options: .atomic)
                goalPhotos[key] = path.path
            } catch { continue }
        }
        for key in Array(goalPhotos.keys) where !goalKeys.contains(key) {
            if let path = goalPhotos.removeValue(forKey: key) { try? FileManager.default.removeItem(atPath: path) }
        }
        sync()
    }

    /// Goals shared with you (pending or accepted), and who your own shared goals went to.
    private func syncSharedGoals(_ userID: String) {
        let goalRows = model.snapshot.shared_goals ?? []
        let shareRows = model.snapshot.goal_shares ?? []
        let mine = goalRows.filter { $0.text("owner") == userID }
        ui.sharedGoalIDs = Dictionary(mine.map { ($0.text("client_id"), $0.id) }, uniquingKeysWith: { first, _ in first })
        for row in mine { uploadedGoalPhotos.formUnion(row.values["media"]?.strings ?? []) }
        let mineIDs = Set(mine.map(\.id))
        var answers: [String: [String: String]] = [:]
        for row in shareRows where mineIDs.contains(row.text("goal_id")) {
            answers[row.text("goal_id"), default: [:]][localID(row.text("recipient"))] = row.text("status")
        }
        ui.goalRecipients = answers
        ui.sharedGoals = goalRows.filter { $0.text("owner") != userID }.compactMap { row in
            guard let share = shareRows.first(where: { $0.text("goal_id") == row.id && $0.text("recipient") == userID }),
                  let status = SharedGoal.Status(rawValue: share.text("status")) else { return nil }
            return SharedGoal(id: row.id, owner: localID(row.text("owner")), title: row.text("title"), notes: row.text("notes"),
                              links: row.values["links"]?.strings ?? [],
                              photos: (row.values["photos"]?.strings ?? []).compactMap { goalPhotos[$0] },
                              parts: sharedParts(row.values["parts"], goal: row.id),
                              status: status, sharedAt: share.date("created_at"))
        }
    }

    private func sharedParts(_ value: ArchiveValue?, goal: String) -> [GoalPart] {
        guard let value, case .array(let items) = value else { return [] }
        return items.enumerated().compactMap { index, item in
            guard case .object(let part) = item else { return nil }
            return GoalPart(id: part["id"]?.string ?? "\(goal)-\(index)", title: part["title"]?.string ?? "",
                            notes: part["notes"]?.string ?? "", link: part["link"]?.string ?? "",
                            photos: (part["photos"]?.strings ?? []).compactMap { goalPhotos[$0] })
        }
    }
    func authenticate() async {
        await model.authenticate("google"); sync()
        if model.userID != nil, model.me != nil, let pending = model.pendingLink { _ = await connect(pending.absoluteString) }
    }
    func signOut() async { await model.logout(); sync() }
    func perform(_ operation: String, _ payload: [String: Any]) async -> Bool {
        if operation == "sign_in_apple" { await model.authenticate("apple"); sync(); return model.userID != nil }
        if operation == "enable_notifications" { return await enableNotifications() == nil }
        if operation == "delete_account" { await model.deleteAccount(); sync(); return model.userID == nil }
        if operation == "load_more_feed" { await model.loadMoreFeed(); await loadPhotos(); return true }
        if operation == "hydrate_post", let id = payload["post_id"] as? String { await model.hydratePost(id); await loadPhotos(); return true }
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
    func enableNotifications() async -> String? {
        model.error = nil
        await SocialPushCoordinator.register(in: model, userInitiated: true)
        // Hand the failure to the caller instead of the root alert, which can't show over the Account sheet.
        defer { model.error = nil }
        return model.error
    }
    func create(_ draft: SessionDraft, key: UUID) async -> String? {
        guard let date = draft.startsAt, !draft.gym.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            model.error = "Choose a date, time and gym."; return nil
        }
        let result = await model.perform("create_session", ["title": draft.title, "starts_at": ISO8601DateFormatter().string(from: date), "timezone": draft.timezone,
                                                          "venue": draft.gym, "note": SessionNoteCodec.encode(note: draft.note, focus: draft.focusItems),
                                                          "invited": draft.invited.map(cloudID), "join_mode": draft.privacy.rawValue], key: key)
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
    func saveAvatar(_ jpeg: Data) async -> Bool {
        guard let userID = model.userID, let row = model.me else { model.error = "Sign in to change your photo."; return false }
        if avatarUploadPhoto != jpeg { avatarUploadKey = UUID(); avatarUploadPhoto = jpeg }
        let key = "\(userID.lowercased())/\((avatarUploadKey ?? UUID()).uuidString.lowercased()).jpg"
        do { try await model.backend.upload(jpeg, objectKey: key, bucket: "avatars") }
        catch {
            // A retry after a dropped response finds the earlier upload already stored.
            guard let existing = try? await model.backend.image(key: key, bucket: "avatars"), existing == jpeg else {
                model.error = "Couldn't upload your photo: \(error.localizedDescription)"
                return false
            }
        }
        let payload: [String: Any] = ["name": row.text("name"), "belt": row.text("belt"), "stripes": row.number("stripes"),
                                      "gym": row.text("gym"), "timezone": TimeZone.current.identifier, "avatar_key": key]
        guard await model.perform("save_profile", payload) != nil else { sync(); return false }
        avatarUploadKey = nil; avatarUploadPhoto = nil
        await loadPhotos()
        return true
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
        guard model.userID != nil, token.count == 64, token.allSatisfy(\.isHexDigit), ["friend", "session", "goal"].contains(kind ?? "") else {
            model.error = "Sign in and open a valid invitation link."; return nil
        }
        let operation = kind == "friend" ? "redeem_friend" : kind == "goal" ? "redeem_goal_link" : "join_link"
        guard let result = await model.perform(operation, ["token": token]) else { return nil }
        model.pendingLink = nil; sync()
        if kind == "session", let id = result["id"]?.string { ui.go(.session(id: id)); return nil }
        if kind == "goal", let id = result["id"]?.string {
            // Your own link opens your goal; anyone else's opens the invitation.
            if result["own"] == .bool(true) {
                if let local = ui.sharedGoalIDs.first(where: { $0.value == id })?.key { ui.go(.goal(id: local)) }
            } else {
                ui.go(.sharedGoal(id: id))
            }
            return nil
        }
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
    func editSession(_ sessionID: String, title: String, startsAt: Date, gym: String, note: String) async -> Bool {
        guard let row = model.session(sessionID) else { return false }
        // Keep the focus plan that shares the note field.
        let old = SessionNoteCodec.decode(row.text("note"))
        let result = await model.perform("edit_session", ["session_id": sessionID, "version": row.number("version"), "title": title,
                                                       "starts_at": ISO8601DateFormatter().string(from: startsAt), "timezone": row.text("timezone"),
                                                       "venue": gym, "note": SessionNoteCodec.encode(note: note, focus: old.focus)])
        sync(); return result != nil
    }
    func publishGoal(_ goal: MatGoal) async -> String? {
        guard let owner = model.userID else { model.error = "Sign in to share goals."; return nil }
        do {
            var photos: [String] = []
            for photo in goal.photos { if let key = try await uploadGoalPhoto(photo, owner: owner) { photos.append(key) } }
            var parts: [[String: Any]] = []
            for part in goal.parts {
                var keys: [String] = []
                for photo in part.photos { if let key = try await uploadGoalPhoto(photo, owner: owner) { keys.append(key) } }
                parts.append(["id": part.id, "title": part.title, "notes": part.notes, "link": part.link, "photos": keys])
            }
            // Not `model.perform`: saving a shared goal republishes in the background
            // and must not be refused while another command is running.
            let result = try await model.backend.command("publish_goal", payload: [
                "client_id": goal.id, "title": goal.title, "notes": goal.notes,
                "links": goal.links, "photos": photos, "parts": parts])
            guard model.userID == owner, let id = result["id"]?.string else { return nil }
            await model.refresh(force: true)
            sync()
            return id
        } catch {
            if model.userID == owner { model.error = "Couldn't share \(goal.title): \(error.localizedDescription)" }
            return nil
        }
    }
    /// Uploads one goal photo, named by its content, so re-saves and retries reuse it.
    /// Files missing from this device (none in the installed app) are left out.
    private func uploadGoalPhoto(_ photo: String, owner: String) async throws -> String? {
        guard let data = try? Data(contentsOf: MatGoal.photoRoot.appendingPathComponent(photo)) else { return nil }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let key = "\(owner.lowercased())/\(digest).jpg"
        if uploadedGoalPhotos.contains(key) { return key }
        do { try await model.backend.upload(data, objectKey: key, bucket: "goal-media") }
        catch {
            // Already there from an earlier save or a lost response: same name, same photo.
            guard let existing = try? await model.backend.image(key: key, bucket: "goal-media"), existing == data else { throw error }
        }
        uploadedGoalPhotos.insert(key)
        return key
    }
    func copyGoalLink(_ sharedID: String) async -> Bool {
        guard let result = await model.perform("goal_token", ["goal_id": sharedID]), let token = result["token"]?.string else { return false }
        UIPasteboard.general.url = model.link(kind: "goal", token: token)
        return true
    }
    func scannerView(found: @escaping (String) -> Void) -> AnyView { AnyView(LiveScannerView(found: found)) }
    func exportView() -> AnyView {
        AnyView(NavigationStack { PreviousTrainingDataScreen(model: model.archive, exportOnly: true) })
    }
}
