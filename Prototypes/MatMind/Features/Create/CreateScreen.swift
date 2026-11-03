import SwiftUI

/// Plan a session (invite friends) or log one that already happened.
struct CreateScreen: View {
    @Environment(AppModel.self) private var mm

    private struct Day: Hashable {
        var label: String
        var weekday: String
        var date: Int
        var month: String
        var value: Date
    }

    private static let times = ["6:30 AM", "12:15 PM", "6:00 PM", "7:30 PM"]

    @State private var mode: String
    @State private var name = ""
    @State private var dayIndex: Int
    @State private var selectedDays: Set<Int> = []
    @State private var calendar = Calendar.current
    @State private var baseDate = Date()
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
        _dayIndex = State(initialValue: 0)
        _time = State(initialValue: startPast ? "6:00 PM" : "10:00 AM")
        _invited = State(initialValue: friend.map { [$0] } ?? [])
        _focusItems = State(initialValue: initialFocus.isEmpty ? [TrainingFocus()] : initialFocus)
    }

    private var isPast: Bool { mode == "past" }
    private var days: [Day] {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar; formatter.timeZone = calendar.timeZone
        return (0..<(isPast ? 5 : 7)).map { index in
            let date = calendar.date(byAdding: .day, value: isPast ? -index - 1 : index, to: baseDate)!
            formatter.dateFormat = "EEE"; let weekday = formatter.string(from: date)
            formatter.dateFormat = "MMM"; let month = formatter.string(from: date)
            return Day(label: index == 0 ? (isPast ? "Yesterday" : "Today") : weekday,
                       weekday: weekday, date: calendar.component(.day, from: date), month: month, value: date)
        }
    }
    private var day: Day { days[min(isPast ? dayIndex : (selectedDays.min() ?? 0), days.count - 1)] }
    private var completedCount: Int { mm.createdCount(for: requests) }
    private var autoName: String { SessionDraft.suggestedTitle(weekday: day.weekday, time: time) }
    private var selectionCount: Int { isPast ? 1 : selectedDays.count }
    private var buttonTitle: String {
        if submitting { return "Creating \(completedCount) of \(requests.count)…" }
        if completedCount > 0 { return "Retry remaining \(requests.count - completedCount)" }
        if isPast { return "Next: add a photo" }
        if selectionCount > 1 { return "Create \(selectionCount) sessions" }
        return invited.isEmpty ? "Create session" : "Send invites to \(invited.count)"
    }

    var body: some View {
        MMScreen {
            MMHeader(title: isPast ? "Log a past session" : "Plan a session", leading: {
                MMIconButton("x", label: "Close") { mm.back() }
                    .disabled(mm.busy || submitting)
            })
        } content: {
            Group {
                MMTabs(items: [MMTabItem("plan", "Upcoming"), MMTabItem("past", "Already happened")], selection: Binding(
                    get: { mode },
                    set: { newMode in
                        mode = newMode
                        dayIndex = 0
                    }
                ))
                .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 4) {
                    TextField(autoName, text: $name)
                        .mmFont(.display, 30, tracking: -0.035, lineHeight: 1.1)
                        .foregroundStyle(MMColor.ink900)
                        .tint(MMColor.accent)
                    Text(selectionCount > 1 ? "Name each session, or keep our suggestions." : "Name it, or keep our suggestion.").mmFont(.body, 13).foregroundStyle(MMColor.textTertiary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)

                field("When", hint: isPast ? nil : "\(selectedDays.count) selected") {
                    if !isPast {
                        Text("Pick one or more days. Same time and details for each.")
                            .mmFont(.body, 13).foregroundStyle(MMColor.textTertiary)
                            .padding(.bottom, 12)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(days.enumerated()), id: \.offset) { i, d in
                                dayChip(d, on: isPast ? i == dayIndex : selectedDays.contains(i)) {
                                    if isPast { dayIndex = i }
                                    else if selectedDays.contains(i) { selectedDays.remove(i) }
                                    else { selectedDays.insert(i) }
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

                field("Where") {
                    if mm.isLive {
                        MMTextField(label: "Gym or venue", text: $gym)
                            .padding(.bottom, 12)
                    }
                    MMFlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(mm.gyms, id: \.self) { g in
                            MMTag(g, icon: g == mm.me.gym ? "house" : "map-pin", selected: gym == g, size: .sm) { gym = g }
                        }
                    }
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
                    Text("Big idea first. Details underneath.")
                        .mmFont(.body, 13)
                        .foregroundStyle(MMColor.textTertiary)
                        .padding(.bottom, MMSpace.s5)
                    TrainingFocusEditor(items: $focusItems, allowsEmptyRoots: true, focusOnAppear: false)
                }

                field(isPast ? "Who was there" : "Invite friends", hint: "\(invited.count) picked") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                        ForEach(mm.friends) { f in friendPick(f) }
                    }
                }

                if !isPast {
                    field("Who can join") {
                        MMTabs(items: [MMTabItem("friends", "Friends only"), MMTabItem("link", "Anyone with link")], selection: $privacy)
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
                                     ? "Anyone with a Mat Monkeys account can join from the link."
                                     : "Only your friends can join from the link.")
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
        .onAppear { if gym.isEmpty { gym = mm.me.gym } }
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
        return ([time] + Self.times).filter { seen.insert($0).inserted }
    }

    private var submittedFocusItems: [TrainingFocus] {
        TrainingFocusTree.optionalOutline(focusItems)
    }

    private func submit() {
        guard !submitting, !mm.busy else { return }
        if completedCount == 0 {
            let dates = isPast ? [day.value] : selectedDays.sorted().map { days[$0].value }
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

    private func dayChip(_ d: Day, on: Bool, action: @escaping () -> Void) -> some View {
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

    private func friendPick(_ f: Friendship) -> some View {
        let p = mm.person(f.id)
        let on = invited.contains(f.id)
        return Button {
            withAnimation(MMMotion.bounce()) {
                if on { invited.removeAll { $0 == f.id } } else { invited.append(f.id) }
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
                        if !on && f.streak > 0 {
                            HStack(spacing: 2) {
                                MMIcon("flame", size: 11, filled: true, color: MMColor.flame500)
                                Text("\(f.streak)").mmFont(.body, 11, .bold, lineHeight: 1).foregroundStyle(MMColor.flameInk)
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
