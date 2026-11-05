import SwiftUI

/// Plan a training (invite friends) or log one that already happened.
struct CreateScreen: View {
    @Environment(AppModel.self) private var mm
    @Environment(\.scenePhase) private var scenePhase

    private static let times = ["6:30 AM", "12:15 PM", "6:00 PM", "7:30 PM"]

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
    @State private var showNote = false
    @State private var invited: [String]
    @State private var privacy = Privacy.friends.rawValue
    @State private var link: String? = nil
    @State private var focusItems: [TrainingFocus]

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
    private var days: [SessionDaySelection.Day] { dateSelection.days(past: isPast) }
    private var day: SessionDaySelection.Day { days[min(dateSelection.pastDayIndex, days.count - 1)] }
    private var completedCount: Int { mm.createdCount(for: requests) }
    private var selectionCount: Int { isPast ? 1 : dateSelection.selectedDays.count }
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
                    Text("Keep this title, or make it your own.").mmFont(.body, 13).foregroundStyle(MMColor.textTertiary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)

                field("When", hint: isPast ? nil : "\(dateSelection.selectedDays.count) selected") {
                    if !isPast {
                        Text("Pick one or more days. Same time and details for each.")
                            .mmFont(.body, 13).foregroundStyle(MMColor.textTertiary)
                            .padding(.bottom, 12)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(days.enumerated()), id: \.offset) { i, d in
                                dayChip(d, on: isPast ? i == dateSelection.pastDayIndex : dateSelection.selectedDays.contains(i)) {
                                    if isPast { dateSelection.pastDayIndex = i }
                                    else if dateSelection.selectedDays.contains(i) { dateSelection.selectedDays.remove(i) }
                                    else { dateSelection.selectedDays.insert(i) }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 2)
                    }
                    .padding(.horizontal, -16)
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
                    MMFlowLayout(spacing: MMSpace.s4, lineSpacing: MMSpace.s4) {
                        if !showNote {
                            MMButton("Add a note (optional)", variant: .ghost, size: .sm, iconLeft: "plus") {
                                withAnimation(MMMotion.easeOut()) { showNote = true }
                            }
                        }
                    }
                    .padding(.top, MMSpace.s4)
                    .padding(.leading, -MMSpace.s4)
                    if showNote {
                        MMTextField(placeholder: "Gi or no-gi? Bring anything?", text: $note, multiline: true, rows: 2)
                            .padding(.top, 12)
                    }
                }

                field("What are we working on?", hint: "Optional") {
                    if !pickableGoals.isEmpty {
                        Text("Pick from your goals, or add your own.")
                            .mmFont(.body, 13)
                            .foregroundStyle(MMColor.textTertiary)
                            .padding(.bottom, MMSpace.s5)
                    }
                    TrainingFocusEditor(items: $focusItems, allowsEmptyRoots: true, focusOnAppear: false, goals: pickableGoals)
                }

                field(isPast ? "Who was there" : "Invite friends", hint: "\(invited.count) picked") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                        ForEach(mm.invitees) { p in friendPick(p) }
                    }
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
        .mmSheet(isPresented: $customTime, title: "Choose a time") {
            DatePicker("Time", selection: $chosenTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
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
            let dates = isPast ? [day.value] : dateSelection.selectedDays.sorted().map { days[$0].value }
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

    private func friendPick(_ p: Person) -> some View {
        let on = invited.contains(p.id)
        let streak = mm.friendship(p.id)?.streak ?? 0
        return Button {
            withAnimation(MMMotion.bounce()) {
                if on { invited.removeAll { $0 == p.id } } else { invited.append(p.id) }
            }
        } label: {
            VStack(spacing: 6) {
                MMAvatar(name: p.name, size: 60)
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
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(p.name)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
