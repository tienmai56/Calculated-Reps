import SwiftUI

/// Plan a training (invite friends) or log one that already happened.
struct CreateScreen: View {
    @Environment(AppModel.self) private var mm
    @Environment(\.scenePhase) private var scenePhase

    private static let times = ["6:30 AM", "12:15 PM", "6:00 PM", "7:30 PM"]
    /// Friends shown in the invite rail before Search / See all take over.
    private static let railLimit = 8

    @State private var mode: String
    @State private var name = SessionDraft.defaultTitle
    @FocusState private var nameFocused: Bool
    @State private var dateSelection = SessionDaySelection()
    @State private var requests: [SessionCreationRequest] = []
    @State private var submitting = false
    @State private var time: String
    @State private var gym = ""
    @State private var customTime = false
    @State private var chosenTime = Date()
    @State private var note = ""
    @State private var invited: [String]
    @State private var privacy = Privacy.friends.rawValue
    @State private var link: String? = nil
    @State private var focusItems: [TrainingFocus]
    @State private var invitePicker: InvitePickerMode?

    init(startPast: Bool = false, friend: String? = nil, initialFocus: [TrainingFocus] = []) {
        _mode = State(initialValue: startPast ? "past" : "plan")
        _time = State(initialValue: startPast ? "6:00 PM" : "10:00 AM")
        _invited = State(initialValue: friend.map { [$0] } ?? [])
        _focusItems = State(initialValue: initialFocus.isEmpty ? [TrainingFocus()] : initialFocus)
    }

    private var isPast: Bool { mode == "past" }
    /// Named goals, offered as one-tap focuses.
    private var pickableGoals: [MatGoal] {
        mm.goals.filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    private var calendar: Calendar { dateSelection.calendar }
    private var days: [SessionDaySelection.Day] { dateSelection.pastDays() }
    private var day: SessionDaySelection.Day { days[min(dateSelection.pastDayIndex, days.count - 1)] }
    private var completedCount: Int { mm.createdCount(for: requests) }
    private var selectionCount: Int { isPast ? 1 : dateSelection.selectedDates.count }
    private var buttonTitle: String {
        if submitting { return "Creating \(completedCount) of \(requests.count)…" }
        if completedCount > 0 { return "Retry remaining \(requests.count - completedCount)" }
        if isPast { return "Next: add a photo" }
        if selectionCount > 1 { return "Create \(selectionCount) sessions" }
        return invited.isEmpty ? "Create session" : "Send invites to \(invited.count)"
    }

    var body: some View {
        MMScreen {
            MMHeader(title: isPast ? "Log a past session" : "Plan a training", leading: {
                MMIconButton("x", label: "Close") { mm.back() }
                    .disabled(mm.busy || submitting)
            })
        } content: {
            Group {
                MMTabs(items: [MMTabItem("plan", "Upcoming"), MMTabItem("past", "Already happened")], selection: Binding(
                    get: { mode },
                    set: { newMode in
                        refreshCalendar()
                        mode = newMode
                        dateSelection.pastDayIndex = 0
                        if newMode == "plan" {
                            for index in focusItems.indices { focusItems[index].isCompleted = false }
                        }
                    }
                ))
                .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        TextField("Session title", text: $name)
                            .mmFont(.display, 30, tracking: -0.035, lineHeight: 1.1)
                            .foregroundStyle(MMColor.ink900)
                            .tint(MMColor.accent)
                            .focused($nameFocused)
                            .accessibilityLabel("Session title")
                        if !name.isEmpty {
                            Button {
                                name = ""
                                nameFocused = true
                            } label: {
                                MMIcon("x", size: 16, color: MMColor.textTertiary)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Clear session title")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)

                field("When", hint: isPast ? nil : "\(dateSelection.selectedDates.count) selected") {
                    if isPast {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(days.enumerated()), id: \.offset) { i, d in
                                    dayChip(d, on: i == dateSelection.pastDayIndex) { dateSelection.pastDayIndex = i }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 2)
                        }
                        .padding(.horizontal, -16)
                    } else {
                        SessionMonthCalendar(selection: $dateSelection)
                    }
                    MMFlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(timeOptions, id: \.self) { t in
                            MMTag(t, selected: time == t, size: .sm) { time = t }
                        }
                        MMTag("Other", icon: "clock", size: .sm) { customTime = true }
                    }
                    .padding(.top, 10)
                }

                field("Location") {
                    MMPlaceSearchField(text: $gym)
                }

                field("Description", hint: "Optional") {
                    MMTextField(placeholder: "Gi or no-gi? Bring anything?", text: $note, multiline: true, rows: 3)
                        .accessibilityLabel("Session description")
                }

                field("What are we working on?", hint: submittedFocusItems.isEmpty ? "Optional" : "\(submittedFocusItems.filter(\.isCompleted).count)/\(submittedFocusItems.count)") {
                    TrainingFocusComposer(items: $focusItems, allowsCompletion: isPast, goals: pickableGoals)
                }

                field(isPast ? "Who was there" : "Invite friends", hint: "\(invited.count) picked") {
                    inviteRail
                }

                if !isPast {
                    field("Who can join") {
                        MMTabs(items: [MMTabItem("friends", "Invited people"), MMTabItem("link", "Anyone with link")], selection: $privacy)
                        if privacy == Privacy.link.rawValue {
                            Text("Invited people accept before seeing session details.")
                                .mmFont(.body, 14).foregroundStyle(MMColor.textSecondary).padding(.top, MMSpace.s4)
                        }
                        if mm.isLive {
                            Text("Create the session, then share its invitation link.")
                                .mmFont(.body, 14).foregroundStyle(MMColor.textSecondary).padding(.top, 12)
                        } else {
                        HStack(spacing: 12) {
                            if let link {
                                MMIcon("link", size: 18, color: MMColor.accent)
                                Text("matmonkeys.app/s/\(link)").mmFont(.mono, 14, .semibold, lineHeight: 1).foregroundStyle(MMColor.ink900)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                MMButton("Copy", variant: .soft, size: .sm, iconLeft: "copy") { mm.showToast("Invite link copied", .success) }
                            } else {
                                Text(privacy == Privacy.link.rawValue
                                     ? "Anyone with a Mat Monkey account can accept an invitation from the link."
                                     : "People you follow can receive an invitation.")
                                    .mmFont(.body, 14).foregroundStyle(MMColor.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                MMButton("Get link", variant: .secondary, size: .sm, iconLeft: "link") {
                                    withAnimation(MMMotion.easeOut()) { link = "k3x9q" }
                                }
                            }
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(MMColor.white))
                        .mmOutline(radius: 18)
                        .padding(.top, 12)
                        }
                    }
                }
                Color.clear.frame(height: 24)
            }
            .disabled(mm.busy || submitting || completedCount > 0)
        } footer: {
            VStack(spacing: 10) {
                if completedCount > 0 && !submitting {
                    Text("\(completedCount) of \(requests.count) sessions created. Retry to create the rest, or close to keep the sessions already created.")
                        .mmFont(.body, 13).foregroundStyle(MMColor.textSecondary)
                }
                MMButton(buttonTitle, size: .lg, iconLeft: isPast ? "camera" : "send", fullWidth: true) { submit() }
                    .disabled(!TrainingFocusTree.isValid(submittedFocusItems) || mm.busy || submitting || selectionCount == 0 || (mm.isLive && gym.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            }
        }
        .onAppear {
            refreshCalendar()
            if gym.isEmpty { gym = mm.me.gym }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshCalendar() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in refreshCalendar() }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in refreshCalendar() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in refreshCalendar() }
        .sheet(item: $invitePicker) { mode in
            InviteFriendsSheet(
                title: isPast ? "Who was there" : "Invite friends",
                people: mm.invitees,
                streaks: inviteeStreaks,
                focusSearch: mode == .search,
                invited: $invited
            )
        }
        .mmSheet(isPresented: $customTime, title: "Choose a time") {
            DatePicker("Time", selection: $chosenTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
        } actions: {
            MMButton("Use this time", fullWidth: true) {
                let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = calendar.timeZone; formatter.dateFormat = "h:mm a"
                time = formatter.string(from: chosenTime); customTime = false
            }
        }
    }

    private var timeOptions: [String] {
        var seen = Set<String>()
        return (Self.times + [time]).filter { seen.insert($0).inserted }
    }

    private var submittedFocusItems: [TrainingFocus] {
        TrainingFocusTree.optionalOutline(focusItems)
    }

    @discardableResult
    private func refreshCalendar() -> Bool {
        // Once a request has started, retries must keep its original dates.
        guard !submitting, completedCount == 0 else { return false }
        return dateSelection.refresh()
    }

    private func submit() {
        guard !submitting, !mm.busy else { return }
        if completedCount == 0 {
            guard !refreshCalendar() else {
                mm.showToast("The calendar changed. Check your dates and try again.")
                return
            }
            let dates = isPast ? [day.value] : dateSelection.sortedSelectedDates
            let draft = SessionDraft(
                title: name.trimmingCharacters(in: .whitespacesAndNewlines), day: "", date: 0, month: "",
                time: time, gym: gym, note: note, invited: invited,
                privacy: Privacy(rawValue: privacy) ?? .friends, past: isPast, focusItems: submittedFocusItems
            )
            let scheduled = draft.scheduled(on: dates, calendar: calendar)
            // Reuse request keys when retrying unchanged input, including a lost response.
            if requests.map(\.draft) != scheduled { requests = scheduled.map { SessionCreationRequest(draft: $0) } }
        }
        guard !requests.isEmpty else { return }
        submitting = true
        Task {
            await mm.createSessions(requests)
            submitting = false
        }
    }

    private func field<Content: View>(_ label: String, hint: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(label).mmFont(.display, 16).foregroundStyle(MMColor.ink900)
                Spacer()
                if let hint { MMMeta(hint) }
            }
            .padding(.bottom, 10)
            content()
        }
        .padding(.horizontal, 16)
        .padding(.top, 22)
    }

    private func dayChip(_ d: SessionDaySelection.Day, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(d.label).mmFont(.body, 12, .bold, lineHeight: 1).opacity(0.75)
                Text("\(d.date)").mmFont(.display, 24, tracking: -0.03, lineHeight: 1)
            }
            .foregroundStyle(on ? MMColor.paper : MMColor.ink900)
            .frame(width: 62, height: 74)
            .background {
                let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
                if on {
                    shape.fill(MMColor.ink900)
                } else {
                    shape.fill(MMColor.white).overlay(shape.strokeBorder(MMColor.borderDefault, lineWidth: 1.5))
                }
            }
            .animation(MMMotion.easeOut(MMMotion.fast), value: on)
        }
        .buttonStyle(MMPressStyle(scale: 0.95))
        .accessibilityLabel("\(d.weekday), \(d.month) \(d.date)")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var inviteeStreaks: [String: Int] {
        Dictionary(mm.invitees.map { ($0.id, mm.friendship($0.id)?.streak ?? 0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Streak friends first (longest streak first), then whoever you trained with most recently, then A–Z.
    private var rankedInvitees: [Person] {
        let streaks = inviteeStreaks
        let sessions = mm.completedSessions.enumerated().sorted { a, b in
            switch (a.element.startsAt, b.element.startsAt) {
            case let (x?, y?): return x > y
            case (.some, nil): return true
            case (nil, .some): return false
            case (nil, nil): return a.offset < b.offset
            }
        }
        var lastTrained: [String: Int] = [:]
        for (rank, entry) in sessions.enumerated() {
            for id in entry.element.going where lastTrained[id] == nil { lastTrained[id] = rank }
        }
        return mm.invitees.sorted { a, b in
            let sa = streaks[a.id] ?? 0, sb = streaks[b.id] ?? 0
            if sa != sb { return sa > sb }
            let ra = lastTrained[a.id] ?? .max, rb = lastTrained[b.id] ?? .max
            if ra != rb { return ra < rb }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    /// One sideways row, so the section keeps the same height however many friends you have.
    /// Friends picked from the sheet join the front of the row so they stay visible.
    @ViewBuilder private var inviteRail: some View {
        let ranked = rankedInvitees
        if ranked.isEmpty {
            Text("Follow friends to invite them here.")
                .mmFont(.body, 14).foregroundStyle(MMColor.textTertiary)
        } else {
            let base = Array(ranked.prefix(Self.railLimit))
            let baseIDs = Set(base.map(\.id))
            let extras = invited.filter { !baseIDs.contains($0) }.map { mm.person($0) }
            let shownIDs = baseIDs.union(extras.map(\.id))
            let hidden = ranked.filter { !shownIDs.contains($0.id) }.count
            let showsMore = ranked.count > Self.railLimit
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 8) {
                    if showsMore {
                        railTile("Search", accessibility: "Search friends") {
                            invitePicker = .search
                        } glyph: {
                            MMIcon("search", size: 20, color: MMColor.textSecondary)
                        }
                    }
                    ForEach(extras + base) { p in friendPick(p) }
                    if showsMore {
                        railTile("See all", accessibility: "See all \(ranked.count) friends") {
                            invitePicker = .all
                        } glyph: {
                            if hidden > 0 {
                                Text("+\(hidden)").mmFont(.display, 16, lineHeight: 1).foregroundStyle(MMColor.textSecondary)
                            } else {
                                MMIcon("users", size: 20, color: MMColor.textSecondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }
            .padding(.horizontal, -16)
        }
    }

    private func railTile<Glyph: View>(_ label: String, accessibility: String, action: @escaping () -> Void, @ViewBuilder glyph: () -> Glyph) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                glyph()
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(MMColor.surfaceSunken))
                Text(label).mmFont(.body, 13, .medium, lineHeight: 1).foregroundStyle(MMColor.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 64)
        }
        .buttonStyle(MMPressStyle(scale: 0.95))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibility)
        .accessibilityAddTraits(.isButton)
    }

    private func friendPick(_ p: Person) -> some View {
        let on = invited.contains(p.id)
        let streak = mm.friendship(p.id)?.streak ?? 0
        return Button {
            withAnimation(MMMotion.bounce()) {
                if on { invited.removeAll { $0 == p.id } } else { invited.append(p.id) }
            }
        } label: {
            VStack(spacing: 6) {
                MMAvatar(name: p.name, photo: p.photo, size: 52)
                    .background {
                        Circle().fill(MMColor.accent).padding(-5.5)
                            .overlay(Circle().fill(MMColor.bgApp).padding(-3))
                            .opacity(on ? 1 : 0)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if on {
                            MMIcon("check", size: 14, weight: .bold, color: .white)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(MMColor.accent))
                                .background(Circle().fill(MMColor.bgApp).padding(-3))
                                .offset(x: 3, y: 3)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if !on && streak > 0 {
                            HStack(spacing: 2) {
                                MMIcon("flame", size: 11, filled: true, color: MMColor.flame500)
                                Text("\(streak)").mmFont(.body, 11, .bold, lineHeight: 1).foregroundStyle(MMColor.flameInk)
                            }
                            .padding(.horizontal, 6)
                            .frame(height: 22)
                            .background(Capsule().fill(MMColor.flame100))
                            .background(Capsule().fill(MMColor.bgApp).padding(-2))
                            .offset(x: 6, y: -4)
                        }
                    }
                    .scaleEffect(on ? 1.04 : 1)
                Text(p.firstName).mmFont(.body, 13, on ? .bold : .medium, lineHeight: 1).foregroundStyle(MMColor.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(width: 64)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(p.name)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

private enum InvitePickerMode: String, Identifiable {
    case search, all
    var id: String { rawValue }
}

/// Every friend in one A–Z list, with search. Picks apply straight away to the planning form.
private struct InviteFriendsSheet: View {
    let title: String
    let people: [Person]
    let streaks: [String: Int]
    let focusSearch: Bool
    @Binding var invited: [String]

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var needle: String {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return q.hasPrefix("@") ? String(q.dropFirst()) : q
    }

    private var results: [Person] {
        let sorted = people.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let n = needle
        guard !n.isEmpty else { return sorted }
        return sorted.filter { p in
            p.name.lowercased().split(whereSeparator: \.isWhitespace).contains { $0.hasPrefix(n) }
                || p.username.lowercased().hasPrefix(n)
        }
    }

    private var picked: [Person] {
        invited.compactMap { id in people.first { $0.id == id } }
    }

    private var listLabel: String {
        let n = results.count
        if needle.isEmpty { return n == 1 ? "1 friend" : "\(n) friends" }
        return n == 1 ? "1 match" : "\(n) matches"
    }

    private var doneTitle: String {
        switch picked.count {
        case 0: return "Done"
        case 1: return "Add \(picked[0].firstName)"
        default: return "Add \(picked.count) friends"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(title).mmFont(.display, 18).foregroundStyle(MMColor.ink900)
                HStack {
                    MMIconButton("x", label: "Close") { dismiss() }
                    Spacer()
                }
            }
            .frame(minHeight: 54)
            .padding(.horizontal, 6)
            .padding(.top, 10)

            MMTextField(placeholder: "Search your friends", text: $query, iconLeft: "search", autoFocus: focusSearch)
                .padding(.horizontal, 16)

            if !picked.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(picked) { p in pickedChip(p) }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 12)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if results.isEmpty {
                        VStack(spacing: 6) {
                            Text(people.isEmpty ? "No friends yet" : "No friends by that name")
                                .mmFont(.display, 18).foregroundStyle(MMColor.ink900)
                            Text("Only people who follow you show up here. Have them scan your code first.")
                                .mmFont(.body, 15).foregroundStyle(MMColor.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        Text(listLabel)
                            .mmFont(.body, 13, .semibold, lineHeight: 1).foregroundStyle(MMColor.textTertiary)
                            .padding(.top, 16).padding(.bottom, 4)
                        ForEach(results) { p in row(p) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)

            MMButton(doneTitle, size: .lg, fullWidth: true) { dismiss() }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
        .background(MMColor.white)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(MMRadius.xl)
        .presentationBackground(MMColor.white)
    }

    private func toggle(_ id: String) {
        withAnimation(MMMotion.bounce()) {
            if invited.contains(id) { invited.removeAll { $0 == id } } else { invited.append(id) }
        }
    }

    private func pickedChip(_ p: Person) -> some View {
        Button { toggle(p.id) } label: {
            HStack(spacing: 6) {
                MMAvatar(name: p.name, photo: p.photo, size: 24)
                Text(p.firstName).mmFont(.body, 13, .semibold, lineHeight: 1).lineLimit(1)
                MMIcon("x", size: 14, weight: .bold, color: MMColor.paper)
            }
            .foregroundStyle(MMColor.paper)
            .padding(.leading, 4)
            .padding(.trailing, 10)
            .frame(height: 32)
            .background(Capsule().fill(MMColor.ink900))
        }
        .buttonStyle(MMPressStyle(scale: 0.95))
        .frame(minHeight: MMLayout.tapTarget)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Remove \(p.name)")
        .accessibilityAddTraits(.isButton)
    }

    private func row(_ p: Person) -> some View {
        let on = invited.contains(p.id)
        let streak = streaks[p.id] ?? 0
        return Button { toggle(p.id) } label: {
            HStack(spacing: 12) {
                MMAvatar(name: p.name, photo: p.photo, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(p.name).mmFont(.display, 16, lineHeight: 1.25).foregroundStyle(MMColor.ink900)
                        .lineLimit(1).truncationMode(.tail)
                    HStack(spacing: 4) {
                        if streak > 0 {
                            MMIcon("flame", size: 13, filled: true, color: MMColor.flame500)
                            Text("\(streak)-week streak together")
                        } else if !p.username.isEmpty {
                            Text("@\(p.username)")
                        } else if !p.gym.isEmpty {
                            Text(p.gym)
                        }
                    }
                    .mmFont(.body, 13, lineHeight: 1.3)
                    .foregroundStyle(MMColor.textTertiary)
                    .lineLimit(1)
                }
                Spacer(minLength: 8)
                ZStack {
                    Circle().strokeBorder(MMColor.controlBorder, lineWidth: 1.5).opacity(on ? 0 : 1)
                    Circle().fill(MMColor.accent).opacity(on ? 1 : 0)
                    MMIcon("check", size: 14, weight: .bold, color: .white)
                        .opacity(on ? 1 : 0)
                        .scaleEffect(on ? 1 : 0.5)
                }
                .frame(width: 24, height: 24)
                .animation(MMMotion.bounce(), value: on)
            }
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(streak > 0 ? "\(p.name), \(streak)-week streak" : p.name)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Month calendar

/// Pick any number of upcoming days, up to a year ahead. Weeks run Monday to
/// Sunday like streak weeks; today has a coral ring and picked days fill ink.
private struct SessionMonthCalendar: View {
    @Binding var selection: SessionDaySelection

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Text(selection.monthTitle())
                    .mmFont(.display, 18, tracking: -0.02, lineHeight: 1)
                    .foregroundStyle(MMColor.ink900)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                monthButton("chevron-left", label: "Previous month", offset: -1, enabled: selection.canShowPreviousMonth)
                monthButton("chevron-right", label: "Next month", offset: 1, enabled: selection.canShowNextMonth)
            }
            .padding(.leading, 8)

            HStack(spacing: 0) {
                ForEach(Array(selection.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .mmFont(.body, 12, .bold, lineHeight: 1)
                        .foregroundStyle(MMColor.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 8)
            .accessibilityHidden(true)

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(selection.monthGrid().enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 44).accessibilityHidden(true)
                    }
                }
            }

            if let elsewhere = selection.selectionElsewhereSummary {
                MMMeta(elsewhere)
                    .padding(.top, 10)
                    .padding(.leading, 8)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .mmCardSurface()
        .sensoryFeedback(.selection, trigger: selection.selectedDates)
    }

    private func monthButton(_ icon: String, label: String, offset: Int, enabled: Bool) -> some View {
        MMIconButton(icon, iconSize: 18, label: label) {
            withAnimation(MMMotion.easeOut(MMMotion.fast)) { selection.showMonth(offset: offset) }
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
    }

    private func dayCell(_ day: Date) -> some View {
        let enabled = selection.isPlannable(day)
        let on = selection.isSelected(day)
        let isToday = selection.calendar.isDate(day, inSameDayAs: selection.today)
        return Button {
            withAnimation(MMMotion.bounce(MMMotion.fast)) { selection.toggle(day) }
        } label: {
            Text("\(selection.calendar.component(.day, from: day))")
                .mmFont(.display, 16, tracking: -0.02, lineHeight: 1)
                .foregroundStyle(on ? MMColor.paper : enabled ? MMColor.ink900 : MMColor.textDisabled)
                .frame(width: 40, height: 40)
                .background {
                    if on {
                        Circle().fill(MMColor.ink900)
                    } else if isToday {
                        Circle().strokeBorder(MMColor.accent, lineWidth: 1.5)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(MMPressStyle(scale: 0.9, bounce: true))
        .disabled(!enabled)
        .accessibilityLabel(selection.accessibilityLabel(for: day))
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
