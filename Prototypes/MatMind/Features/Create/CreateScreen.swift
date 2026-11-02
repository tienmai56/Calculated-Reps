import SwiftUI

/// Plan a session (invite friends) or log one that already happened.
struct CreateScreen: View {
    @Environment(AppModel.self) private var mm

    private struct Day: Hashable {
        var label: String
        var weekday: String
        var date: Int
        var month: String
    }

    private static let future = [
        Day(label: "Today", weekday: "Mon", date: 2, month: "Nov"), Day(label: "Tue", weekday: "Tue", date: 3, month: "Nov"),
        Day(label: "Wed", weekday: "Wed", date: 4, month: "Nov"), Day(label: "Thu", weekday: "Thu", date: 5, month: "Nov"),
        Day(label: "Fri", weekday: "Fri", date: 6, month: "Nov"), Day(label: "Sat", weekday: "Sat", date: 7, month: "Nov"),
        Day(label: "Sun", weekday: "Sun", date: 8, month: "Nov"),
    ]
    private static let past = [
        Day(label: "Yesterday", weekday: "Sun", date: 1, month: "Nov"), Day(label: "Sat", weekday: "Sat", date: 31, month: "Oct"),
        Day(label: "Fri", weekday: "Fri", date: 30, month: "Oct"), Day(label: "Thu", weekday: "Thu", date: 29, month: "Oct"),
        Day(label: "Wed", weekday: "Wed", date: 28, month: "Oct"),
    ]
    private static let times = ["6:30 AM", "12:15 PM", "6:00 PM", "7:30 PM"]

    @State private var mode: String
    @State private var name = ""
    @State private var dayIndex: Int
    @State private var time: String
    @State private var gym = SeedData.me.gym
    @State private var note = ""
    @State private var showNote = false
    @State private var invited: [String]
    @State private var privacy = Privacy.friends.rawValue
    @State private var link: String? = nil

    init(startPast: Bool = false, friend: String? = nil) {
        _mode = State(initialValue: startPast ? "past" : "plan")
        _dayIndex = State(initialValue: startPast ? 0 : 5)
        _time = State(initialValue: startPast ? "6:00 PM" : "10:00 AM")
        _invited = State(initialValue: friend.map { [$0] } ?? [])
    }

    private var isPast: Bool { mode == "past" }
    private var days: [Day] { isPast ? Self.past : Self.future }
    private var day: Day { days[min(dayIndex, days.count - 1)] }

    private var autoName: String {
        if day.weekday == "Sat" { return "Saturday open mat" }
        if day.weekday == "Sun" { return "Sunday open mat" }
        if time.contains("AM") { return "Morning rolls" }
        if time.hasPrefix("12") { return "Lunch rolls" }
        return "Evening rolls"
    }

    var body: some View {
        MMScreen {
            MMHeader(title: isPast ? "Log a past session" : "Plan a session", leading: {
                MMIconButton("x", label: "Close") { mm.back() }
            })
        } content: {
            MMTabs(items: [MMTabItem("plan", "Upcoming"), MMTabItem("past", "Already happened")], selection: Binding(
                get: { mode },
                set: { newMode in
                    mode = newMode
                    dayIndex = newMode == "past" ? 0 : 5
                }
            ))
            .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 4) {
                TextField(autoName, text: $name)
                    .mmFont(.display, 30, tracking: -0.035, lineHeight: 1.1)
                    .foregroundStyle(MMColor.ink900)
                    .tint(MMColor.accent)
                Text("Name it, or keep our suggestion.").mmFont(.body, 13).foregroundStyle(MMColor.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)

            field("When") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(days.enumerated()), id: \.offset) { i, d in
                            dayChip(d, on: i == dayIndex) { dayIndex = i }
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
                    MMTag("Other", icon: "clock", size: .sm)
                }
                .padding(.top, 10)
            }

            field("Where") {
                MMFlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(mm.gyms, id: \.self) { g in
                        MMTag(g, icon: g == mm.me.gym ? "house" : "map-pin", selected: gym == g, size: .sm) { gym = g }
                    }
                }
                if showNote {
                    MMTextField(placeholder: "Gi or no-gi? Bring anything?", text: $note, multiline: true, rows: 2)
                        .padding(.top, 12)
                } else {
                    MMButton("Add a note (optional)", variant: .ghost, size: .sm, iconLeft: "plus") {
                        withAnimation(MMMotion.easeOut()) { showNote = true }
                    }
                    .padding(.top, 8)
                    .padding(.leading, -8)
                }
            }

            field(isPast ? "Who was there" : "Invite friends", hint: "\(invited.count) picked") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                    ForEach(mm.friends) { f in friendPick(f) }
                }
            }

            if !isPast {
                field("Who can join") {
                    MMTabs(items: [MMTabItem("friends", "Friends only"), MMTabItem("link", "Anyone with link")], selection: $privacy)
                    HStack(spacing: 12) {
                        if let link {
                            MMIcon("link", size: 18, color: MMColor.accent)
                            Text("matmind.app/s/\(link)").mmFont(.mono, 14, .semibold, lineHeight: 1).foregroundStyle(MMColor.ink900)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            MMButton("Copy", variant: .soft, size: .sm, iconLeft: "copy") { mm.showToast("Invite link copied", .success) }
                        } else {
                            Text(privacy == Privacy.link.rawValue
                                 ? "Anyone with a Mat Mind account can join from the link."
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
            Color.clear.frame(height: 24)
        } footer: {
            MMButton(isPast ? "Next: add a photo" : (invited.isEmpty ? "Create session" : "Send invites to \(invited.count)"),
                     size: .lg, iconLeft: isPast ? "camera" : "send", fullWidth: true) { submit() }
        }
    }

    private var timeOptions: [String] {
        var seen = Set<String>()
        return ([time] + Self.times).filter { seen.insert($0).inserted }
    }

    private func submit() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        mm.createSession(SessionDraft(
            title: trimmed.isEmpty ? autoName : trimmed, day: day.weekday, date: day.date, month: day.month,
            time: time, gym: gym, note: note, invited: invited,
            privacy: Privacy(rawValue: privacy) ?? .friends, past: isPast
        ))
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
