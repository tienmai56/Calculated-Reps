import SwiftUI
import PhotosUI
import UserNotifications

/// Tab 4: me, my belt and friends, then three sections: Progress (stats, streak, goals),
/// Activity (past sessions) and Gallery (photos from every session).
struct ProfileScreen: View {
    @Environment(AppModel.self) private var mm
    @State private var showSettings = false
    @State private var name = ""
    @State private var username = ""
    @State private var savingUsername = false
    @State private var gym = ""
    @State private var showExport = false
    @State private var deleteAccount = false
    @State private var email = ""
    @State private var belt = BeltRank.purple.rawValue
    @State private var stripes = "2"
    @State private var section: ProfileSection = .progress
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var savingPhoto = false
    @State private var pushStatus: UNAuthorizationStatus?
    @State private var pushNote: (text: String, ok: Bool)?
    @State private var enablingPush = false
    @Environment(\.scenePhase) private var phase
    @Environment(\.openURL) private var openURL

    var body: some View {
        let me = mm.me
        let history = ProfileHistory(posts: mm.posts.filter { $0.participants.contains("me") })
        MMScreen(tabPadding: true) {
            MMHeader(title: "Profile", large: true, trailing: {
                MMHeaderActions()
                MMIconButton("settings", variant: .filled, label: "Settings") { openSettings() }
            })
        } content: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 16) {
                    MMAvatar(name: me.name, photo: me.photo, size: 80, belt: me.belt)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(me.name).mmFont(.display, 28, tracking: -0.03, lineHeight: 1.05).foregroundStyle(MMColor.ink900)
                            .mmMonkey(me.monkey, size: 28)
                        if !me.username.isEmpty {
                            Text("@" + me.username).mmFont(.body, 13).foregroundStyle(MMColor.textTertiary)
                        }
                        if !me.gym.isEmpty {
                            Text(me.gym).mmFont(.body, 13).foregroundStyle(MMColor.textTertiary)
                        }
                        MMBelt(rank: me.belt, stripes: me.stripes, size: .sm, width: 120, showLabel: true)
                    }
                    Spacer(minLength: 0)
                }
                streakLine(history)
                friendsRow
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)

            ProfileSectionTabs(selection: $section)
                .padding(.top, 18)

            switch section {
            case .progress: ProfileProgressSection(history: history)
            case .activity: ProfileActivitySection(history: history)
            case .gallery: ProfileGallerySection(history: history)
            }
        }
        .mmSheet(isPresented: $showSettings, title: "Account") {
            VStack(alignment: .leading, spacing: 16) {
                // Build my monkey (Maybe later, or never asked) or Edit my monkey.
                MonkeyAccountRow {
                    showSettings = false
                    Task {
                        // Let the sheet finish closing before the builder covers the screen.
                        try? await Task.sleep(for: .seconds(0.35))
                        mm.editingMonkey = true
                    }
                }
                photoRow
                MMTextField(label: "Name", text: $name)
                if mm.isLive {
                    MMTextField(label: "Username", placeholder: "hippo", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Use 3–40 letters, numbers or underscores. Friends can tag you with @username.")
                        .mmFont(.body, 13).foregroundStyle(MMColor.textTertiary)
                    MMButton("Save username", variant: .secondary) {
                        savingUsername = true
                        Task {
                            defer { savingUsername = false }
                            if await mm.runtime?.perform("set_username", ["username": username]) == true {
                                username = mm.me.username
                                mm.showToast("Username saved")
                            }
                        }
                    }
                    .disabled(savingUsername || username == mm.me.username)
                }
                if mm.isLive { MMTextField(label: "Home gym", text: $gym) }
                VStack(alignment: .leading, spacing: 8) {
                    MMTextField(label: "Email", text: $email, iconLeft: "mail").disabled(mm.isLive)
                    HStack(spacing: 6) {
                        MMIcon("lock", size: 14, color: MMColor.textTertiary)
                        Text("Private. Only you can see this.").mmFont(.body, 13).foregroundStyle(MMColor.textTertiary)
                    }
                }
                HStack(alignment: .bottom, spacing: 10) {
                    MMSelect(label: "Belt", options: BeltRank.adultRanks.map(\.rawValue), selection: $belt)
                    MMSelect(label: "Stripes", options: ["0", "1", "2", "3", "4"], selection: $stripes)
                        .frame(width: 110)
                }
                if mm.isLive {
                    Text("Export").mmFont(.display, 18)
                    MMButton("Export local sessions", variant: .secondary, iconLeft: "download") { showExport = true }
                    notificationsRow
                    MMButton("Delete account", variant: .ghost, iconLeft: "trash-2") { deleteAccount = true }
                }
                MMButton("Sign out", variant: .ghost, iconLeft: "log-out") {
                    showSettings = false
                    mm.signOutOfDemo()
                }
                    .padding(.leading, -10)
            }
            .sheet(isPresented: $showExport) { mm.runtime?.exportView() }
            .mmSheet(isPresented: $deleteAccount,
                     title: "Delete account?",
                     description: "Your cloud account and shared training data will be deleted. This cannot be undone.") {
                VStack(spacing: 12) {
                    MMButton("Delete account", variant: .danger, iconLeft: "trash-2", fullWidth: true) {
                        deleteAccount = false
                        Task { _ = await mm.runtime?.perform("delete_account", [:]) }
                    }
                    MMButton("Cancel", variant: .secondary, fullWidth: true) { deleteAccount = false }
                }
            }
        }
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            savingPhoto = true
            Task {
                defer { savingPhoto = false; pickedPhoto = nil }
                guard let data = try? await item.loadTransferable(type: Data.self) else {
                    mm.showToast("That photo couldn't be read")
                    return
                }
                await mm.updatePhoto(data)
            }
        }
        .onChange(of: showSettings) { _, open in
            guard !open, mm.isSignedIn else { return }
            if mm.isLive { mm.me.gym = gym }
            mm.updateMe(name: name.isEmpty ? mm.me.name : name, email: email,
                        belt: BeltRank(rawValue: belt) ?? mm.me.belt, stripes: Int(stripes) ?? mm.me.stripes)
        }
    }

    /// Account sheet: push permission. Results show here because the app's alert and toasts
    /// sit under this sheet, and iOS never re-asks once someone has declined.
    private var notificationsRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            if pushStatus == .denied {
                MMButton("Turn on in Settings", variant: .ghost, iconLeft: "bell") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                }
                Text("Notifications are off for Mat Monkey, so you could miss an invite to train.")
                    .mmFont(.body, 13).foregroundStyle(MMColor.textTertiary)
            } else {
                MMButton(enablingPush ? "Enabling…" : "Enable notifications", variant: .ghost, iconLeft: "bell") {
                    Task { await enablePush() }
                }
                .disabled(enablingPush)
            }
            if let pushNote {
                HStack(spacing: 6) {
                    MMIcon(pushNote.ok ? "circle-check" : "circle-alert", size: 14,
                           color: pushNote.ok ? MMColor.mint700 : MMColor.coral700)
                    Text(pushNote.text).mmFont(.body, 13)
                        .foregroundStyle(pushNote.ok ? MMColor.mint700 : MMColor.coral700)
                }
            }
        }
        .task { pushNote = nil; await refreshPushStatus() }
        .onChange(of: phase) { _, phase in
            // Back from iOS Settings: register right away if they switched notifications on.
            guard phase == .active else { return }
            Task {
                let wasDenied = pushStatus == .denied
                await refreshPushStatus()
                if wasDenied, pushStatus != .denied, pushStatus != .notDetermined { await enablePush() }
            }
        }
    }

    private func refreshPushStatus() async {
        pushStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    private func enablePush() async {
        guard !enablingPush, let runtime = mm.runtime else { return }
        enablingPush = true
        defer { enablingPush = false }
        let failure = await runtime.enableNotifications()
        await refreshPushStatus()
        if pushStatus == .denied { pushNote = nil }
        else if let failure { pushNote = (failure, false) }
        else { pushNote = ("Notifications are on. We'll ping you when friends invite you to train.", true) }
    }

    /// Account sheet: tap the avatar (or the link beside it) to pick a new profile photo.
    private var photoRow: some View {
        let me = mm.me
        return HStack(spacing: 16) {
            PhotosPicker(selection: $pickedPhoto, matching: .images, photoLibrary: .shared()) {
                MMAvatar(name: me.name.isEmpty ? name : me.name, photo: me.photo, size: 72)
                    .overlay {
                        if savingPhoto {
                            Circle().fill(MMColor.ink900.opacity(0.35))
                            ProgressView().tint(MMColor.white)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        MMIcon("camera", size: 14, color: MMColor.ink900)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(MMColor.white))
                            .mmShadowCard()
                    }
            }
            .buttonStyle(MMPressStyle())
            .disabled(savingPhoto)
            .accessibilityLabel(me.photo == nil ? "Add a profile photo" : "Change profile photo")
            VStack(alignment: .leading, spacing: 2) {
                Text("Profile photo").mmFont(.body, 15, .bold).foregroundStyle(MMColor.textPrimary)
                PhotosPicker(selection: $pickedPhoto, matching: .images, photoLibrary: .shared()) {
                    Text(savingPhoto ? "Saving…" : me.photo == nil ? "Add a photo" : "Change photo")
                        .mmFont(.body, 14, .semibold)
                        .foregroundStyle(MMColor.textLink)
                        .frame(minHeight: MMLayout.tapTarget)
                }
                .disabled(savingPhoto)
                .accessibilityHidden(true)
            }
            Spacer(minLength: 0)
        }
    }

    private func streakLine(_ history: ProfileHistory) -> some View {
        let streak = history.currentStreak
        return HStack(spacing: 8) {
            MMIcon("flame", size: 20, filled: streak > 0, color: streak > 0 ? MMColor.flame500 : MMColor.ink300)
            Text(streak > 0 ? "\(streak)-week streak" : "No streak yet")
                .mmFont(.body, 15, .bold).foregroundStyle(MMColor.textPrimary)
            Text("·").mmFont(.body, 15).foregroundStyle(MMColor.textTertiary)
            Text(history.items.count == 1 ? "1 session" : "\(history.items.count) sessions")
                .mmFont(.body, 15).foregroundStyle(MMColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var friendsRow: some View {
        Button { mm.friends.isEmpty ? mm.go(.qr()) : mm.go(.friends) } label: {
            HStack(spacing: 10) {
                if mm.friends.isEmpty {
                    MMIcon("user-plus", size: 20, color: MMColor.ink700)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(MMColor.paper2))
                    Text("Add your first training partner").mmFont(.body, 15, .semibold).foregroundStyle(MMColor.textPrimary)
                } else {
                    MMAvatarStack(people: mm.friends.map { mm.person($0.id).avatar }, size: 30, max: 3, ring: MMColor.bgApp)
                    Text(mm.friends.count == 1 ? "1 training partner" : "\(mm.friends.count) training partners")
                        .mmFont(.body, 15, .semibold).foregroundStyle(MMColor.textPrimary)
                }
                Spacer(minLength: 4)
                MMIcon("chevron-right", size: 18, color: MMColor.ink500)
            }
            .frame(minHeight: MMLayout.tapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(MMPressStyle())
    }

    private func openSettings() {
        gym = mm.me.gym
        name = mm.me.name
        username = mm.me.username
        email = mm.me.email ?? ""
        belt = mm.me.belt.rawValue
        stripes = String(mm.me.stripes)
        showSettings = true
    }
}

// MARK: - Profile sections

enum ProfileSection: String, CaseIterable, Identifiable {
    case progress, activity, gallery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .progress: "Progress"
        case .activity: "Activity"
        case .gallery: "Gallery"
        }
    }

    var icon: String {
        switch self {
        case .progress: "chart-column"
        case .activity: "activity"
        case .gallery: "images"
        }
    }
}

/// Icon + label tabs across the full width, with a coral underline on the active one.
private struct ProfileSectionTabs: View {
    @Binding var selection: ProfileSection
    /// Someone else's profile leaves out Progress: it's private to its owner.
    var sections: [ProfileSection] = ProfileSection.allCases

    var body: some View {
        HStack(spacing: 0) {
            ForEach(sections) { item in
                let on = item == selection
                Button {
                    withAnimation(MMMotion.easeOut(MMMotion.base)) { selection = item }
                } label: {
                    VStack(spacing: 4) {
                        MMIcon(item.icon, size: 24, weight: on ? .bold : .regular, color: on ? MMColor.textPrimary : MMColor.textTertiary)
                        Text(item.title)
                            .mmFont(.display, 13, on ? .extraBold : .bold, tracking: -0.01, lineHeight: 1)
                            .foregroundStyle(on ? MMColor.textPrimary : MMColor.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .overlay(alignment: .bottom) {
                        if on {
                            Capsule().fill(MMColor.accent)
                                .frame(height: 3)
                                .padding(.horizontal, 24)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(MMColor.borderDefault).frame(height: 1)
        }
    }
}

// MARK: - History (my completed sessions, dated)

/// My completed sessions with a real calendar day each, newest first,
/// bucketed into Monday–Sunday weeks to match the friendship streaks.
struct ProfileHistory {
    struct Item: Identifiable {
        let post: Post
        let day: Date
        var id: String { post.id }
    }

    struct Group: Identifiable {
        let title: String
        var items: [Item]
        var id: String { title }
    }

    struct Bar: Identifiable {
        let id: Int
        let label: String
        let count: Int
        let isCurrent: Bool
    }

    let items: [Item]
    let calendar: Calendar
    let now: Date

    init(posts: [Post], now: Date = Date()) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        self.calendar = calendar
        self.now = now
        items = posts
            .map { Item(post: $0, day: $0.occurredAt ?? Self.parse($0.date, now: now, calendar: calendar) ?? now) }
            .sorted { $0.day > $1.day }
    }

    /// Preview posts only carry "Sun, Nov 1": read the month and day, in the most recent year that isn't in the future.
    private static func parse(_ text: String, now: Date, calendar: Calendar) -> Date? {
        let monthDay = text.split(separator: ",").last.map { $0.trimmingCharacters(in: .whitespaces) } ?? text
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        guard let parsed = formatter.date(from: monthDay) else { return nil }
        let parts = calendar.dateComponents([.month, .day], from: parsed)
        var components = DateComponents()
        components.year = calendar.component(.year, from: now)
        components.month = parts.month
        components.day = parts.day
        components.hour = 12
        guard let guess = calendar.date(from: components) else { return nil }
        return guess > now ? calendar.date(byAdding: .year, value: -1, to: guess) : guess
    }

    var thisWeek: DateInterval { calendar.dateInterval(of: .weekOfYear, for: now)! }
    var thisMonth: DateInterval { calendar.dateInterval(of: .month, for: now)! }

    func sessions(in interval: DateInterval) -> [Item] {
        items.filter { $0.day >= interval.start && $0.day < interval.end }
    }

    func partners(in items: [Item]) -> Set<String> {
        Set(items.flatMap(\.post.participants).filter { $0 != "me" })
    }

    private func week(_ offset: Int) -> DateInterval {
        let start = calendar.date(byAdding: .weekOfYear, value: offset, to: thisWeek.start)!
        return calendar.dateInterval(of: .weekOfYear, for: start)!
    }

    private func month(_ offset: Int) -> DateInterval {
        let start = calendar.date(byAdding: .month, value: offset, to: thisMonth.start)!
        return calendar.dateInterval(of: .month, for: start)!
    }

    private func monthName(_ date: Date, _ format: String = "MMM") -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    /// Sessions per week, oldest first; a month label sits under the first week of each month.
    func weeklyBars(_ count: Int) -> [Bar] {
        var lastMonth: Int?
        return (0..<count).map { i in
            let interval = week(i - (count - 1))
            let month = calendar.component(.month, from: interval.start)
            let label = month == lastMonth ? "" : monthName(interval.start)
            lastMonth = month
            return Bar(id: i, label: label, count: sessions(in: interval).count, isCurrent: i == count - 1)
        }
    }

    /// Sessions per calendar month, oldest first.
    func monthlyBars(_ count: Int) -> [Bar] {
        (0..<count).map { i in
            let interval = month(i - (count - 1))
            return Bar(id: i, label: monthName(interval.start), count: sessions(in: interval).count, isCurrent: i == count - 1)
        }
    }

    /// The last `count` completed weeks, oldest first: did I train?
    func pastWeeks(_ count: Int) -> [Bool] {
        (0..<count).map { i in !sessions(in: week(i - count)).isEmpty }
    }

    var trainedThisWeek: Bool { !sessions(in: thisWeek).isEmpty }

    /// Consecutive weeks with a session, ending now (this week counts once trained).
    var currentStreak: Int {
        var n = trainedThisWeek ? 1 : 0
        var offset = -1
        while !sessions(in: week(offset)).isEmpty {
            n += 1
            offset -= 1
        }
        return n
    }

    /// The longest run of consecutive trained weeks.
    var bestStreak: Int {
        let weeks = Set(items.map { calendar.dateInterval(of: .weekOfYear, for: $0.day)!.start })
        var best = 0
        for start in weeks {
            let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: start)!
            guard !weeks.contains(previous) else { continue }
            var run = 1
            var next = calendar.date(byAdding: .weekOfYear, value: 1, to: start)!
            while weeks.contains(next) {
                run += 1
                next = calendar.date(byAdding: .weekOfYear, value: 1, to: next)!
            }
            best = max(best, run)
        }
        return best
    }

    /// Newest first, grouped "This week", "Last week", then by month.
    func activityGroups() -> [Group] {
        group(items, by: { item in
            if item.day >= thisWeek.start { return "This week" }
            if item.day >= week(-1).start { return "Last week" }
            return monthTitle(item.day)
        })
    }

    /// Newest first, grouped by month.
    func photoGroups() -> [Group] {
        group(items.filter { $0.post.photo != nil }, by: { monthTitle($0.day) })
    }

    private func monthTitle(_ date: Date) -> String {
        calendar.component(.year, from: date) == calendar.component(.year, from: now)
            ? monthName(date, "MMMM") : monthName(date, "MMMM yyyy")
    }

    private func group(_ source: [Item], by key: (Item) -> String) -> [Group] {
        var groups: [Group] = []
        for item in source {
            let title = key(item)
            if groups.last?.title == title {
                groups[groups.count - 1].items.append(item)
            } else {
                groups.append(Group(title: title, items: [item]))
            }
        }
        return groups
    }
}

// MARK: - Progress

private struct ProfileProgressSection: View {
    @Environment(AppModel.self) private var mm
    let history: ProfileHistory
    @State private var range = "week"

    var body: some View {
        let weekly = range == "week"
        let period = history.sessions(in: weekly ? history.thisWeek : history.thisMonth)
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                MMTabs(items: [MMTabItem("week", "Weekly"), MMTabItem("month", "Monthly")], selection: $range)
                Text(weekly ? "This week" : "This month")
                    .mmFont(.display, 22, tracking: -0.015, lineHeight: 1.15)
                    .foregroundStyle(MMColor.textPrimary)
                HStack(alignment: .top, spacing: 12) {
                    stat("Sessions", period.count)
                    stat("Partners", history.partners(in: period).count)
                    stat("Photos", period.filter { $0.post.photo != nil }.count)
                }
                ProfileSessionBars(
                    bars: weekly ? history.weeklyBars(12) : history.monthlyBars(6),
                    caption: weekly ? "Past 12 weeks" : "Past 6 months"
                )
            }
            .padding(18)
            .mmCardSurface(radius: MMRadius.lg)
            .padding(.horizontal, 16)
            .padding(.top, 16)

            streakCard
                .padding(.horizontal, 16)
                .padding(.top, 16)

            MMEyebrow(title: "Goals you're working on") {
                if !mm.goals.isEmpty {
                    Button("See all") { mm.setTab(.goals) }
                        .mmFont(.body, 13, .semibold)
                        .foregroundStyle(MMColor.textLink)
                        .frame(minHeight: MMLayout.tapTarget)
                }
            }
            goals
                .padding(.horizontal, 16)
        }
    }

    private func stat(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).mmFont(.body, 12).foregroundStyle(MMColor.textTertiary)
            Text("\(value)").mmFont(.display, 28, tracking: -0.03, lineHeight: 1.05).foregroundStyle(MMColor.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var streakCard: some View {
        let streak = history.currentStreak
        let best = history.bestStreak
        let message: String = {
            if streak == 0 {
                return best > 0 ? "Pick it back up · best \(best) week\(best == 1 ? "" : "s")" : "Train once this week to start your streak."
            }
            if streak >= best && streak > 1 { return "Your best run yet. Keep rolling." }
            return "\(streak) week\(streak == 1 ? "" : "s") in a row · best \(best)"
        }()
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Weekly streak").mmFont(.display, 18, tracking: -0.02, lineHeight: 1.2).foregroundStyle(MMColor.textPrimary)
                Spacer(minLength: 8)
                if streak > 0 {
                    MMBadge("\(streak) week\(streak == 1 ? "" : "s")", variant: .flame, icon: "flame")
                }
            }
            MMStreakBelt(weeks: history.pastWeeks(9), thisWeek: history.trainedThisWeek ? .done : .pending, hue: .coral)
            Text(message).mmFont(.body, 15, lineHeight: 1.45).foregroundStyle(MMColor.textSecondary)
        }
        .padding(18)
        .mmCardSurface(radius: MMRadius.lg)
    }

    @ViewBuilder
    private var goals: some View {
        if mm.goals.isEmpty {
            Button { mm.setTab(.goals) } label: {
                HStack(spacing: 12) {
                    MMIcon("notebook-pen", size: 20, color: MMColor.ink700)
                        .frame(width: 44, height: 44)
                        .background(RoundedRectangle(cornerRadius: MMRadius.md, style: .continuous).fill(MMColor.paper2))
                    Text("Add something you're working on").mmFont(.body, 15, .semibold).foregroundStyle(MMColor.textPrimary)
                    Spacer(minLength: 4)
                    MMIcon("chevron-right", size: 18, color: MMColor.ink500)
                }
                .padding(16)
                .mmCardSurface(radius: MMRadius.lg)
            }
            .buttonStyle(MMPressStyle())
        } else {
            VStack(spacing: 12) {
                ForEach(mm.goals.prefix(3)) { goal in
                    Button { mm.go(.goal(id: goal.id)) } label: { goalCard(goal) }
                        .buttonStyle(MMPressStyle())
                }
            }
        }
    }

    private func goalCard(_ goal: MatGoal) -> some View {
        let next = mm.nextSession(forGoal: goal.id)
        return HStack(alignment: .top, spacing: 14) {
            MMIcon("notebook-pen", size: 20, color: MMColor.ink800)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: MMRadius.md, style: .continuous).fill(MMColor.paper2))
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title.isEmpty ? "Untitled goal" : goal.title)
                    .mmFont(.display, 16, tracking: -0.015, lineHeight: 1.25)
                    .foregroundStyle(MMColor.textPrimary)
                    .multilineTextAlignment(.leading)
                if !goal.cardPreview.isEmpty {
                    Text(goal.cardPreview)
                        .mmFont(.body, 13, lineHeight: 1.4)
                        .foregroundStyle(MMColor.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                if let next {
                    HStack(spacing: 6) {
                        MMIcon("calendar", size: 14, color: MMColor.textTertiary)
                        Text("Next: \(next.day), \(next.month) \(next.date) · \(next.title)")
                            .mmFont(.body, 12, .semibold)
                            .foregroundStyle(MMColor.textTertiary)
                            .lineLimit(1)
                    }
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            MMIcon("chevron-right", size: 18, color: MMColor.ink500)
        }
        .padding(16)
        .mmCardSurface(radius: MMRadius.lg)
    }
}

/// Sessions per period as columns; the current period is hatched while it's still in progress.
private struct ProfileSessionBars: View {
    let bars: [ProfileHistory.Bar]
    let caption: String

    private let plotHeight: CGFloat = 96

    var body: some View {
        let top = max(bars.map(\.count).max() ?? 0, 1)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(caption).mmFont(.body, 13, .semibold).foregroundStyle(MMColor.textSecondary)
                Spacer()
                Text("Sessions").mmFont(.body, 12).foregroundStyle(MMColor.textTertiary)
            }
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(bars) { bar in
                    VStack(spacing: 4) {
                        Text(bar.count == 0 ? "–" : "\(bar.count)")
                            .mmFont(.body, 11, .semibold, lineHeight: 1)
                            .foregroundStyle(MMColor.textSecondary)
                        column(bar, height: bar.count == 0 ? 4 : max(8, plotHeight * CGFloat(bar.count) / CGFloat(top)))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: plotHeight + 20, alignment: .bottom)
            .overlay(alignment: .bottom) {
                Rectangle().fill(MMColor.borderDefault).frame(height: 1)
            }
            HStack(spacing: 6) {
                ForEach(bars) { bar in
                    Text(bar.label)
                        .mmFont(.body, 11, lineHeight: 1)
                        .foregroundStyle(MMColor.textTertiary)
                        .fixedSize()
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let counts = bars.map { bar -> String in
            bar.label.isEmpty ? String(bar.count) : bar.label + " " + String(bar.count)
        }
        return caption + " sessions: " + counts.joined(separator: ", ")
    }

    @ViewBuilder
    private func column(_ bar: ProfileHistory.Bar, height: CGFloat) -> some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 3, bottomTrailingRadius: 3, topTrailingRadius: 6, style: .continuous)
        Group {
            if bar.isCurrent {
                MMHatch(color: MMColor.ink300, spacing: 6, lineWidth: 2)
                    .background(MMColor.paper3)
                    .clipShape(shape)
            } else if bar.count == 0 {
                shape.fill(MMColor.paper3)
            } else {
                shape.fill(MMColor.ink800)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Activity

private struct ProfileActivitySection: View {
    @Environment(AppModel.self) private var mm
    let history: ProfileHistory
    /// Whose profile this is: the ticket's "with …" line lists everyone else.
    var owner = "me"
    var emptyText = "Your finished sessions land here, with notes and who you rolled with."

    var body: some View {
        let groups = history.activityGroups()
        VStack(alignment: .leading, spacing: 0) {
            if groups.isEmpty {
                emptyNote(emptyText)
            }
            ForEach(groups) { group in
                MMEyebrow(title: group.title, topPadding: 18) {
                    MMMeta(group.items.count == 1 ? "1 session" : "\(group.items.count) sessions")
                }
                VStack(spacing: 12) {
                    ForEach(group.items) { item in
                        PastSessionTicket(item: item, owner: owner) { mm.go(.post(id: item.post.id)) }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

private struct ProfileDashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return p
    }
}

/// A finished session as a ticket stub, tinted with the organizer's hue.
private struct PastSessionTicket: View {
    @Environment(AppModel.self) private var mm
    let item: ProfileHistory.Item
    var owner = "me"
    let onTap: () -> Void

    private let stubWidth: CGFloat = 76

    private func text(_ format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter.string(from: item.day)
    }

    var body: some View {
        let post = item.post
        let organizer = mm.person(post.organizer)
        let hue: FriendHue = post.organizer == "me" ? .coral : organizer.hue
        let partnerIDs = ([post.organizer] + post.participants).reduce(into: [String]()) { ids, id in
            if id != owner && !ids.contains(id) { ids.append(id) }
        }
        let partners = partnerIDs.map { mm.person($0).avatar }
        let withLabel = partnerIDs.count == 1 ? "with \(partnerIDs[0] == "me" ? "you" : mm.person(partnerIDs[0]).firstName)" : "\(partnerIDs.count) partners"
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text(text("EEE").uppercased()).mmFont(.display, 12, tracking: 0.04, lineHeight: 1)
                Text(text("d")).mmFont(.display, 30, tracking: -0.04, lineHeight: 1)
                Text(text("MMM")).mmFont(.body, 12, .bold, lineHeight: 1)
            }
            .foregroundStyle(hue.ink)
            .padding(.vertical, 14)
            .frame(width: stubWidth)
            .frame(maxHeight: .infinity)
            .background(hue.tint)

            ProfileDashedLine()
                .stroke(MMColor.ink200, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .frame(width: 2)
                .padding(.vertical, 10)

            VStack(alignment: .leading, spacing: 6) {
                Text(post.title)
                    .mmFont(.display, 16, tracking: -0.015, lineHeight: 1.25)
                    .foregroundStyle(MMColor.textPrimary)
                    .multilineTextAlignment(.leading)
                if !post.gym.isEmpty {
                    HStack(spacing: 6) {
                        MMIcon("map-pin", size: 14, color: MMColor.textTertiary)
                        Text(post.gym).mmFont(.body, 12, .medium).foregroundStyle(MMColor.textTertiary).lineLimit(1)
                    }
                }
                if !post.caption.isEmpty {
                    Text(post.caption)
                        .mmFont(.body, 13, lineHeight: 1.4)
                        .foregroundStyle(MMColor.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                HStack(spacing: 8) {
                    if !partners.isEmpty {
                        if partnerIDs.count == 1 {
                            PersonProfileButton(person: mm.person(partnerIDs[0])) {
                                MMAvatarStack(people: partners, size: 24, max: 3, ring: .white, label: withLabel)
                            }
                        } else {
                            MMAvatarStack(people: partners, size: 24, max: 3, ring: .white, label: withLabel)
                        }
                    }
                    Spacer(minLength: 0)
                    if post.photo != nil {
                        MMIcon("image", size: 14, color: MMColor.textTertiary)
                    }
                }
                .padding(.top, 2)
            }
            .padding(.vertical, 14)
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .clipShape(RoundedRectangle(cornerRadius: MMRadius.lg, style: .continuous))
        .mmCardSurface(radius: MMRadius.lg)
        .overlay(alignment: .topLeading) {
            Circle().fill(MMColor.bgApp).frame(width: 16, height: 16).offset(x: stubWidth - 7, y: -8)
        }
        .overlay(alignment: .bottomLeading) {
            Circle().fill(MMColor.bgApp).frame(width: 16, height: 16).offset(x: stubWidth - 7, y: 8)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityAction(named: Text("Open memory"), onTap)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Gallery

private struct ProfileGallerySection: View {
    @Environment(AppModel.self) private var mm
    let history: ProfileHistory
    var emptyText = "Photos from your sessions collect here. Add one when you finish a session."

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        let groups = history.photoGroups()
        VStack(alignment: .leading, spacing: 0) {
            if groups.isEmpty {
                emptyNote(emptyText)
            }
            ForEach(groups) { group in
                MMEyebrow(title: group.title, topPadding: 18) {
                    MMMeta(group.items.count == 1 ? "1 photo" : "\(group.items.count) photos")
                }
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(group.items) { item in
                        Button { mm.go(.post(id: item.post.id)) } label: {
                            MMColor.paper3
                                .aspectRatio(1, contentMode: .fit)
                                .overlay {
                                    if let photo = item.post.photo {
                                        MMPhoto(source: photo).scaledToFill()
                                    }
                                }
                                .clipped()
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(MMPressStyle(scale: 0.97))
                        .accessibilityLabel("Photo from \(item.post.title), \(item.post.date)")
                    }
                }
            }
        }
    }
}

private func emptyNote(_ text: String) -> some View {
    Text(text)
        .mmFont(.body, 15, lineHeight: 1.45)
        .foregroundStyle(MMColor.textSecondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.top, 40)
}

// MARK: - Notifications

struct NotificationsScreen: View {
    @Environment(AppModel.self) private var mm

    var body: some View {
        let fresh = mm.notifications.filter(\.unread)
        let old = mm.notifications.filter { !$0.unread }
        MMScreen {
            MMHeader(title: "Notifications", leading: {
                MMIconButton("chevron-left", label: "Back") { mm.back() }
            })
        } content: {
            if !fresh.isEmpty {
                MMEyebrow("New", topPadding: 6)
                ForEach(fresh) { n in NotificationRow(note: n) }
            }
            MMEyebrow("Earlier")
            ForEach(old) { n in NotificationRow(note: n) }
            Color.clear.frame(height: 30)
        }
        .onDisappear { mm.readAll() }
    }
}

private struct NotificationRow: View {
    @Environment(AppModel.self) private var mm
    let note: AppNotification

    private var kindIcon: (name: String, color: Color) {
        switch note.kind {
        case .invite: ("calendar", MMColor.accent)
        case .joined: ("user-check", MMColor.mint500)
        case .comment, .mention: ("message-circle", MMColor.sky500)
        case .published: ("images", MMColor.plum500)
        case .like: ("heart", MMColor.coral500)
        case .friend: ("user-plus", MMColor.sun600)
        case .goalShare: ("notebook-pen", MMColor.sky500)
        }
    }

    var body: some View {
        let p = mm.person(note.who)
        let session = note.session.flatMap { sid in mm.upcoming.first { $0.id == sid } }
        HStack(alignment: .top, spacing: 12) {
            PersonProfileButton(person: p) {
                MMAvatar(name: p.name, photo: p.photo, size: 46)
                .overlay(alignment: .bottomTrailing) {
                    MMIcon(kindIcon.name, size: 12, weight: .bold, color: .white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(kindIcon.color))
                        .background(Circle().fill(MMColor.bgApp).padding(-2.5))
                        .offset(x: 3, y: 3)
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                if note.kind == .invite, let invitation = mm.pendingTrainingInvitations.first(where: { $0.id == note.session }) {
                    Text("\(p.firstName) invited you to train").mmFont(.body, 15, .bold)
                    Text("Accept to see the session details.").mmFont(.body, 13).foregroundStyle(MMColor.textTertiary)
                    HStack(spacing: 8) {
                        MMButton("Decline", variant: .secondary, size: .sm) { mm.rsvp(invitation.id, .declined) }
                        MMButton("Accept", size: .sm, iconLeft: "check") { mm.rsvp(invitation.id, .going) }
                    }.padding(.top, 10)
                } else if note.kind == .invite, let s = session {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        PersonProfileButton(person: p) {
                            Text(p.firstName).mmFont(.body, 15, .bold).foregroundStyle(MMColor.textPrimary)
                                .mmMonkey(p.monkey, size: 18)
                        }
                        mmRich([.body(" invited you to ", 15), .body(s.title, 15, .bold)])
                    }
                    Text("\(s.day), \(s.month) \(s.date) · \(s.time) · \(s.gym)").mmFont(.body, 13).foregroundStyle(MMColor.textTertiary)
                    if s.status(of: "me") == .invited {
                        HStack(spacing: 8) {
                            MMButton("Decline", variant: .secondary, size: .sm) { mm.rsvp(s.id, .declined) }
                            MMButton("Join", size: .sm, iconLeft: "check") { mm.rsvp(s.id, .going) }
                        }
                        .padding(.top, 10)
                    } else {
                        let going = s.status(of: "me") == .going
                        MMBadge(going ? "You're going" : "Declined", variant: going ? .success : .neutral, dot: true)
                            .padding(.top, 8)
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        PersonProfileButton(person: p) {
                            Text(p.firstName).mmFont(.body, 15, .bold).foregroundStyle(MMColor.textPrimary)
                                .mmMonkey(p.monkey, size: 18)
                        }
                        Text(note.kind == .invite ? " invited you to train" : " \(note.text)").mmFont(.body, 15).foregroundStyle(MMColor.textPrimary)
                    }
                    if let quote = note.quote {
                        Text("“\(quote)”").mmFont(.body, 14).foregroundStyle(MMColor.textSecondary).padding(.top, 4)
                    }
                }
                Text(note.time).mmFont(.body, 12, .semibold).foregroundStyle(MMColor.textTertiary).padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let photo = note.photo {
                Button { mm.go(.post(id: "p1")) } label: {
                    MMPhotoTile(photo: photo, height: 48, radius: 10).frame(width: 48)
                }
                .buttonStyle(MMPressStyle(scale: 0.95))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(note.unread ? MMColor.coral500.opacity(0.06) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            // Shared goals open in the preview too, so the invitation flow can be reviewed.
            if note.kind == .goalShare, let entity = note.session {
                if mm.sharedGoal(entity) != nil { mm.go(.sharedGoal(id: entity)) }
                return
            }
            guard mm.isLive else { return }
            switch note.kind {
            case .friend: mm.go(.friend(id: note.who))
            case .invite, .joined: if let entity = note.session { mm.go(.session(id: entity)) }
            case .comment, .published, .like, .mention: if let entity = note.session { mm.go(.post(id: entity)) }
            case .goalShare: break
            }
        }
    }
}

// MARK: - Someone else's profile

/// Another practitioner's profile: the personal profile without Progress, which stays private.
/// It shows only sessions you can already see: ones you or your training partners were in.
struct PersonProfileScreen: View {
    @Environment(AppModel.self) private var mm
    let id: String
    @State private var section: ProfileSection = .activity
    @State private var confirmUnfollow = false
    @State private var confirmBlock = false

    var body: some View {
        let p = mm.person(id)
        let history = ProfileHistory(posts: mm.posts.filter { $0.organizer == id || $0.participants.contains(id) })
        MMScreen {
            HStack(spacing: 8) {
                MMIconButton("chevron-left", label: "Back") { mm.back() }
                Spacer()
                if mm.isLive {
                    Menu {
                        Button("Block \(p.firstName)", role: .destructive) { confirmBlock = true }
                    } label: {
                        MMIcon("ellipsis", size: 20, weight: .bold, color: MMColor.textPrimary)
                            .frame(width: MMLayout.tapTarget, height: MMLayout.tapTarget)
                            .background(Circle().fill(MMColor.paper2))
                    }
                    .accessibilityLabel("More options")
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 2)
        } content: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 16) {
                    MMAvatar(name: p.name, photo: p.photo, size: 80, belt: p.belt)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(p.name).mmFont(.display, 28, tracking: -0.03, lineHeight: 1.05).foregroundStyle(MMColor.ink900)
                            .mmMonkey(p.monkey, size: 28)
                        let handle = [p.username.isEmpty ? nil : "@" + p.username, p.gym.isEmpty ? nil : p.gym].compactMap { $0 }
                        if !handle.isEmpty {
                            Text(handle.joined(separator: " · ")).mmFont(.body, 13).foregroundStyle(MMColor.textTertiary)
                        }
                        MMBelt(rank: p.belt, stripes: p.stripes, size: .sm, width: 120, showLabel: true)
                    }
                    Spacer(minLength: 0)
                }
                if let f = mm.friendship(id) { streakLine(f) }
                partnersRow
                HStack(spacing: 10) {
                    if mm.canFollow(id) { followButton(p) }
                    if mm.canInvite(id) {
                        MMButton("Invite to train", variant: .secondary, iconLeft: "calendar-plus", fullWidth: true) {
                            mm.go(.create(friend: id))
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)

            ProfileSectionTabs(selection: $section, sections: [.activity, .gallery])
                .padding(.top, 18)

            switch section {
            case .gallery:
                ProfileGallerySection(history: history,
                                      emptyText: "No photos yet from sessions with you or your training partners.")
            default:
                ProfileActivitySection(history: history, owner: id,
                                       emptyText: "No sessions yet with you or your training partners.")
            }

            Text("You see the sessions \(p.firstName) trained in with you or your training partners.")
                .mmFont(.body, 13, lineHeight: 1.45).foregroundStyle(MMColor.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)
                .padding(.top, 24)
                .padding(.bottom, 16)
        }
        .mmSheet(isPresented: $confirmUnfollow, title: "Unfollow \(p.firstName)?",
                 description: "You can follow again anytime.") {
            VStack(spacing: 12) {
                MMButton("Unfollow", variant: .danger, iconLeft: "user-minus", fullWidth: true) {
                    confirmUnfollow = false
                    mm.setFollowing(id, false)
                }
                MMButton("Keep following", variant: .secondary, fullWidth: true) { confirmUnfollow = false }
            }
        }
        .task(id: id) { await mm.loadPartners(of: id) }
        .confirmationDialog("Block \(p.firstName)?", isPresented: $confirmBlock, titleVisibility: .visible) {
            Button("Block user", role: .destructive) {
                Task { if await mm.runtime?.perform("block_user", ["user_id": id]) == true { mm.back() } }
            }
        }
    }

    /// Your weekly streak with a training partner, in the same shape as the line on your own profile.
    private func streakLine(_ f: Friendship) -> some View {
        let n = f.streak
        return HStack(spacing: 8) {
            MMIcon("flame", size: 20, filled: n > 0, color: n > 0 ? MMColor.flame500 : MMColor.ink300)
            Text(n > 0 ? "\(n)-week streak together" : "No streak yet")
                .mmFont(.body, 15, .bold).foregroundStyle(MMColor.textPrimary)
            Text("·").mmFont(.body, 15).foregroundStyle(MMColor.textTertiary)
            Text(f.together == 1 ? "1 session together" : "\(f.together) sessions together")
                .mmFont(.body, 15).foregroundStyle(MMColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    /// "12 training partners", like your own profile. Opens the full list.
    @ViewBuilder
    private var partnersRow: some View {
        if let list = mm.partnerLists[id] {
            Button { mm.go(.partners(of: id)) } label: {
                HStack(spacing: 10) {
                    if !list.isEmpty {
                        MMAvatarStack(people: list.map { mm.person($0).avatar }, size: 30, max: 3, ring: MMColor.bgApp)
                    }
                    Text(list.count == 1 ? "1 training partner" : "\(list.count) training partners")
                        .mmFont(.body, 15, .semibold).foregroundStyle(MMColor.textPrimary)
                    Spacer(minLength: 4)
                    if !list.isEmpty { MMIcon("chevron-right", size: 18, color: MMColor.ink500) }
                }
                .frame(minHeight: MMLayout.tapTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(MMPressStyle())
            .disabled(list.isEmpty)
        }
    }

    @ViewBuilder
    private func followButton(_ p: Person) -> some View {
        if mm.isFollowing(id) {
            MMButton("Following", variant: .secondary, iconLeft: "user-check", fullWidth: true) { confirmUnfollow = true }
                .accessibilityHint("Opens unfollow options")
        } else {
            MMButton("Follow \(p.firstName)", iconLeft: "user-plus", fullWidth: true) { mm.setFollowing(id, true) }
        }
    }
}
