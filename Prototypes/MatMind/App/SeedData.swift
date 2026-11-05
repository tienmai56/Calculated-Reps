#if DEBUG || MAT_MIND_PROTOTYPE
import Foundation

/// Sample data from `ui_kits/app/data.js`. Photos: Unsplash (assets/photos).
enum SeedData {
    static let me = Person(id: "me", name: "Dani Alves", belt: .purple, stripes: 2, gym: "Tidewater BJJ",
                           hue: .coral, photo: "portrait-gi", email: "dani.alves@gmail.com", username: "dani")

    static let people: [String: Person] = [
        "sarah": Person(id: "sarah", name: "Sarah Lee", belt: .blue, stripes: 3, gym: "Tidewater BJJ", hue: .sky, username: "sarah",
                        monkey: MMMonkeyLook(mood: .grin, fur: .ginger, haircut: .topknot)),
        "alex": Person(id: "alex", name: "Alex Moreno", belt: .white, stripes: 3, gym: "Tidewater BJJ", hue: .mint, username: "alex",
                        monkey: MMMonkeyLook(mood: .side, fur: .midnight, haircut: .fringe)),
        "priya": Person(id: "priya", name: "Priya Nair", belt: .blue, stripes: 1, gym: "Tidewater BJJ", hue: .sun, username: "priya",
                        monkey: MMMonkeyLook(mood: .happy, fur: .smoke, haircut: .curls)),
        "kenji": Person(id: "kenji", name: "Kenji Ito", belt: .purple, stripes: 0, gym: "Tidewater BJJ", hue: .plum, username: "kenji",
                        monkey: MMMonkeyLook(mood: .focused, fur: .charcoal, haircut: .mohawk)),
        "jamie": Person(id: "jamie", name: "Jamie Cole", belt: .brown, stripes: 1, gym: "North Shore Grappling", hue: .plum, username: "jamie",
                        monkey: MMMonkeyLook(mood: .tired, fur: .midnight, haircut: .tuft)),
        "marco": Person(id: "marco", name: "Marco Silva", belt: .black, stripes: 2, gym: "Harbor Jiu-Jitsu", hue: .coral, username: "marco",
                        monkey: MMMonkeyLook(mood: .happy, fur: .charcoal, haircut: .clean)),
        "lena": Person(id: "lena", name: "Lena Park", belt: .white, stripes: 1, gym: "Tidewater BJJ", hue: .mint, username: "lena"),
        // People your partners train with (not your partners yet).
        "rafa": Person(id: "rafa", name: "Rafa Mendes", belt: .blue, stripes: 2, gym: "Tidewater BJJ", hue: .sun, username: "rafamendes"),
        "nina": Person(id: "nina", name: "Nina Okafor", belt: .purple, stripes: 1, gym: "Harbor Jiu-Jitsu", hue: .sky, username: "nina"),
        "tom": Person(id: "tom", name: "Tom Becker", belt: .white, stripes: 4, gym: "North Shore Grappling", hue: .mint, username: "tombecker"),
        "maya": Person(id: "maya", name: "Maya Chen", belt: .blue, stripes: 0, gym: "Tidewater BJJ", hue: .plum, username: "maya"),
        "mariana": Person(id: "mariana", name: "Mariana Costa", belt: .purple, stripes: 3, gym: "Harbor Jiu-Jitsu", hue: .sun, username: "mariana"),
        "chris": Person(id: "chris", name: "Chris Duarte", belt: .brown, stripes: 0, gym: "Harbor Jiu-Jitsu", hue: .coral, username: "chrisd"),
        // Only reachable through someone's partner list.
        "lucas": Person(id: "lucas", name: "Lucas Ferreira", belt: .brown, stripes: 2, gym: "Tidewater BJJ", hue: .coral, username: "lucasf"),
        "hana": Person(id: "hana", name: "Hana Sato", belt: .white, stripes: 2, gym: "Tidewater BJJ", hue: .sky, username: "hana"),
        "dev": Person(id: "dev", name: "Dev Patel", belt: .purple, stripes: 1, gym: "North Shore Grappling", hue: .mint, username: "devp"),
        "owen": Person(id: "owen", name: "Owen Brooks", belt: .black, stripes: 1, gym: "Tidewater BJJ", hue: .sun, username: "owen"),
    ]

    /// Each circle member's training partners.
    static let partnerLists: [String: [String]] = [
        "rafa": ["sarah", "alex", "kenji", "priya", "maya", "lucas", "hana", "dev", "owen"],
        "nina": ["marco", "jamie", "sarah", "chris", "mariana"],
        "tom": ["jamie", "priya", "dev"],
        "maya": ["sarah", "priya", "rafa", "hana"],
        "mariana": ["marco", "chris", "nina"],
        "chris": ["marco", "nina", "mariana"],
    ]

    static let circle: [CirclePerson] = [
        CirclePerson(id: "rafa", mutual: ["sarah", "alex", "kenji", "priya"]),
        CirclePerson(id: "nina", mutual: ["marco", "jamie", "sarah"]),
        CirclePerson(id: "tom", mutual: ["jamie", "priya"]),
        CirclePerson(id: "maya", mutual: ["sarah", "priya"]),
        CirclePerson(id: "mariana", mutual: ["marco"]),
        CirclePerson(id: "chris", mutual: ["marco"]),
    ]

    static let following: Set<String> = ["nina"]

    private static let T = true, F = false

    static let friends: [Friendship] = [
        Friendship(id: "sarah", weeks: [F, T, T, T, T, T, T, T, T], thisWeek: .pending, best: 8, together: 31),
        Friendship(id: "kenji", weeks: [F, F, T, F, F, F, F, T, T], thisWeek: .pending, best: 3, together: 9),
        Friendship(id: "alex", weeks: [T, F, F, F, F, F, T, T, T], thisWeek: .done, best: 5, together: 22),
        Friendship(id: "priya", weeks: [F, F, F, F, F, F, F, F, F], thisWeek: .done, best: 1, together: 2),
        Friendship(id: "jamie", weeks: [T, T, T, T, T, T, F, F, F], thisWeek: .pending, best: 12, together: 40, brokeAgo: "3 weeks ago"),
        Friendship(id: "marco", weeks: [T, T, T, F, F, F, F, F, F], thisWeek: .pending, best: 4, together: 7, brokeAgo: "6 weeks ago"),
    ]

    static let posts: [Post] = [
        Post(id: "p1", organizer: "sarah", title: "Sunday No-Gi open mat", gym: "Tidewater BJJ", date: "Sun, Nov 1", ago: "18h",
             photo: "roll-gi", participants: ["sarah", "me", "alex", "kenji"],
             caption: "Six rounds, zero ego. Alex finally hit that knee cut on me and will not stop talking about it.",
             likes: ["alex", "kenji", "priya", "jamie", "lena"], extraLikes: 19,
             comments: [Comment(who: "alex", text: "Took me four months. Worth it.", createdAt: ISO8601DateFormatter().date(from: "2026-11-01T18:20:00Z")), Comment(who: "kenji", text: "Rematch Thursday?", createdAt: ISO8601DateFormatter().date(from: "2026-11-01T19:05:00Z"))], time: "10:00 AM"),
        Post(id: "p2", organizer: "jamie", title: "Leg drag drilling", gym: "North Shore Grappling", date: "Sat, Oct 31", ago: "2d",
             photo: "coach-help", participants: ["jamie", "priya", "marco"],
             caption: "Slow reps, then positional rounds from the leg drag. Priya was a menace.",
             likes: ["priya", "marco"], extraLikes: 11,
             comments: [Comment(who: "priya", text: "Hips sore in the best way", createdAt: ISO8601DateFormatter().date(from: "2026-10-31T20:30:00Z"))], time: "12:15 PM"),
        Post(id: "p3", organizer: "me", title: "Friday fundamentals + rolls", gym: "Tidewater BJJ", date: "Fri, Oct 30", ago: "3d",
             photo: "group-class", participants: ["me", "sarah", "priya", "lena"],
             caption: "Brought Lena to her first open roll. She tapped me with a collar choke. Proud and slightly embarrassed.",
             likes: ["sarah", "lena", "alex"], extraLikes: 27,
             comments: [Comment(who: "lena", text: "I will be telling everyone about this", createdAt: ISO8601DateFormatter().date(from: "2026-10-31T02:15:00Z"))], time: "6:00 PM"),
        Post(id: "p4", organizer: "alex", title: "Early bird gi class", gym: "Tidewater BJJ", date: "Wed, Oct 28", ago: "5d",
             photo: "gym-throw", participants: ["alex", "me", "sarah"],
             caption: "6am crew. Takedown day.", likes: ["sarah"], extraLikes: 8, comments: [], time: "6:00 AM"),
        // Sessions Rafa trained in with your partners, so they're visible on Rafa's profile.
        Post(id: "p5", organizer: "kenji", title: "Morning drilling", gym: "Tidewater BJJ", date: "Tue, Oct 27", ago: "1w",
             photo: "floor-drill", participants: ["kenji", "rafa"],
             caption: "Fifty knee cuts each side. Kenji counted out loud the whole time.", likes: ["sarah"], extraLikes: 4, comments: [], time: "7:00 AM"),
        Post(id: "p6", organizer: "sarah", title: "Lunch rolls", gym: "Tidewater BJJ", date: "Mon, Oct 26", ago: "1w",
             photo: "roll-gi-2", participants: ["sarah", "rafa", "priya", "maya"],
             caption: "Five-minute rounds, short breaks. Priya's guard is getting sticky.", likes: ["priya", "alex"], extraLikes: 6, comments: [], time: "12:15 PM"),
        Post(id: "p7", organizer: "alex", title: "Closed guard fundamentals", gym: "Tidewater BJJ", date: "Thu, Oct 22", ago: "2w",
             photo: nil, participants: ["alex", "rafa"],
             caption: "Rafa walked me through hip bumps and the kimura trap. Hit both live.", likes: ["kenji"], extraLikes: 2, comments: [], time: "6:00 PM"),
    ]

    static let upcoming: [Session] = [
        Session(id: "s2", title: "Leg-lock study group", day: "Tue", date: 3, month: "Nov", time: "7:30 PM", gym: "North Shore Grappling",
                organizer: "jamie", privacy: .friends,
                people: [Attendee(id: "jamie", status: .going), Attendee(id: "marco", status: .going),
                         Attendee(id: "priya", status: .going), Attendee(id: "me", status: .invited)],
                note: "Heel hook entries from SLX. Bring a rash guard."),
        Session(id: "s3", title: "Lunch rolls", day: "Thu", date: 5, month: "Nov", time: "12:15 PM", gym: "Tidewater BJJ",
                organizer: "sarah", privacy: .friends,
                people: [Attendee(id: "sarah", status: .going), Attendee(id: "me", status: .going),
                         Attendee(id: "priya", status: .going), Attendee(id: "kenji", status: .invited)],
                note: "45 min, rounds only."),
        Session(id: "s1", title: "Saturday open mat", day: "Sat", date: 7, month: "Nov", time: "10:00 AM", gym: "Tidewater BJJ",
                organizer: "me", privacy: .link,
                people: [Attendee(id: "me", status: .going), Attendee(id: "sarah", status: .going), Attendee(id: "alex", status: .going),
                         Attendee(id: "kenji", status: .invited), Attendee(id: "lena", status: .declined)],
                note: "All levels. Bring water, the mats get warm."),
    ]

    static let toComplete = Session(id: "c1", title: "Halloween no-gi open mat", day: "Sat", date: 31, month: "Oct", time: "10:00 AM",
                                    gym: "Tidewater BJJ", organizer: "me",
                                    people: ["me", "sarah", "alex", "priya", "kenji"].map { Attendee(id: $0, status: .going) })

    static let notifications: [AppNotification] = [
        AppNotification(id: "n0", kind: .goalShare, who: "kenji", session: "sg-berimbolo", text: "shared Berimbolo entries with you", time: "20m", unread: true),
        AppNotification(id: "n-goal-update", kind: .goalUpdate, who: "sarah", session: "sg-single-leg", text: "updated Single leg finish", time: "35m", unread: true),
        AppNotification(id: "n1", kind: .invite, who: "jamie", session: "s2", time: "20m", unread: true),
        AppNotification(id: "n2", kind: .joined, who: "alex", session: "s1", text: "joined Saturday open mat", time: "2h", unread: true),
        AppNotification(id: "n3", kind: .comment, who: "kenji", session: "p1", text: "commented on Sunday No-Gi open mat", quote: "Rematch Thursday?",
                        photo: "roll-gi", time: "16h", unread: true),
        AppNotification(id: "n4", kind: .published, who: "sarah", session: "p1", text: "shared Sunday No-Gi open mat. You're in it.", photo: "roll-gi", time: "18h"),
        AppNotification(id: "n5", kind: .joined, who: "sarah", session: "s1", text: "joined Saturday open mat", time: "1d"),
        AppNotification(id: "n6", kind: .like, who: "priya", session: "p3", text: "liked your memory", photo: "group-class", time: "1d"),
        AppNotification(id: "n7", kind: .friend, who: "lena", text: "started following you", time: "2d"),
    ]

    static let goals: [MatGoal] = [
        MatGoal(id: "g1", title: "Single leg from standing", position: "Standup",
                parts: [
                    GoalPart(id: "g1-grip", title: "Grip on the near leg",
                             notes: "- Cup behind the knee, not the ankle\n- Pull the leg tight to my chest",
                             link: "https://www.youtube.com/watch?v=single-leg-finishes&t=102",
                             photos: ["coach-help", "floor-drill"]),
                    GoalPart(id: "g1-head", title: "Head position", notes: "Head inside, ear on the hip"),
                    GoalPart(id: "g1-sprawl", title: "Defending the sprawl", notes: "Run the pipe if they sprawl"),
                ]),
        MatGoal(id: "g2", title: "RNC from back mount", position: "Back",
                notes: "Win the hand fight first. Hide the choking hand behind their head.",
                links: ["https://www.youtube.com/watch?v=rnc-details"]),
        MatGoal(id: "g3", title: "Knee cut vs. half guard", position: "Passing",
                notes: "Crossface before the cut. Keep the knee heavy on their thigh.",
                photos: ["bw-sweep", "floor-drill"]),
        MatGoal(id: "g4", title: "Shrimp to recover guard", position: "Escapes"),
    ]

    /// Goals training partners shared with you: one waiting for an answer, two accepted.
    static let sharedGoals: [SharedGoal] = [
        SharedGoal(id: "sg-berimbolo", owner: "kenji", title: "Berimbolo entries",
                   notes: "Off the De La Riva hook only. Don't force it from closed guard.",
                   links: ["https://www.youtube.com/watch?v=berimbolo-entries"],
                   parts: [
                       GoalPart(id: "sg-b1", title: "Hook and grips", notes: "- Cross collar grip first\n- Hook deep behind the knee"),
                       GoalPart(id: "sg-b2", title: "Invert", link: "https://www.youtube.com/watch?v=berimbolo-invert&t=95"),
                   ],
                   status: .pending, sharedAt: Date().addingTimeInterval(-20 * 60)),
        SharedGoal(id: "sg-single-leg", owner: "sarah", title: "Single leg finish",
                   notes: "Head on the hip, not the chest. Run the pipe before they sprawl.",
                   links: ["https://www.bjjfanatics.com/single-leg", "https://www.youtube.com/watch?v=single-leg-chain"],
                   photos: ["roll-gi", "floor-drill"],
                   parts: [
                       GoalPart(id: "sg-s1", title: "Entry from collar tie", notes: "- Snap the head down first\n- Level change, don't reach", photos: ["coach-help", "team-lineup"]),
                       GoalPart(id: "sg-s2", title: "Run the pipe", notes: "Corner, don't lift.", link: "https://www.youtube.com/watch?v=run-the-pipe&t=102"),
                       GoalPart(id: "sg-s3", title: "Knee tap backup", notes: "If they whizzer, switch to the knee tap."),
                   ],
                   status: .accepted, sharedAt: Date().addingTimeInterval(-2 * 3600)),
        SharedGoal(id: "sg-closed-guard", owner: "kenji", title: "Closed guard breaks",
                   notes: "Posture first. Two hands on the belt line, then stand.",
                   photos: ["bw-sweep"],
                   status: .accepted, sharedAt: Date().addingTimeInterval(-3 * 86400)),
    ]

    /// Session id → goal id, for the sessions you've attached a goal to.
    static let sessionGoals: [String: String] = ["s1": "g1"]

    static let gyms = ["Tidewater BJJ", "North Shore Grappling", "Harbor Jiu-Jitsu", "Eastside MMA"]
    static let cameraRoll = ["roll-gi-2", "team-lineup", "floor-drill", "grapple-match", "bw-sweep", "roll-gi"]
}

// Calendar fixtures are preview-only. Live AppModel starts with no records.
enum QuickLogMockScenario: String, CaseIterable, Identifiable {
    case quickLogs, hostPlan, guestPlan, startsLater
    var id: String { rawValue }
    var title: String {
        switch self {
        case .quickLogs: "Quick logs"
        case .hostPlan: "Host plan"
        case .guestPlan: "Guest plan"
        case .startsLater: "Starts later"
        }
    }
}

extension SeedData {
    static func quickLogMockPlans(_ scenario: QuickLogMockScenario, now: Date) -> [Session] {
        let c = TrainingCalendar.calendar, today = c.startOfDay(for: now)
        let tomorrow = c.date(byAdding: .day, value: 1, to: today)!
        let future = c.date(bySettingHour: 19, minute: 0, second: 0, of: c.date(byAdding: .day, value: 2, to: today)!)!
        var plans = [mockSession("mock-future", title: "Open mat", start: future, host: "me")]
        if scenario != .quickLogs {
            let start = scenario == .startsLater
                ? min(now.addingTimeInterval(3600), tomorrow.addingTimeInterval(-0.001))
                : max(today, now.addingTimeInterval(-3600))
            plans.insert(mockSession("mock-today", title: scenario == .guestPlan ? "Rolls with Kenji" : "No-gi training",
                                     start: start, host: scenario == .guestPlan ? "kenji" : "me"), at: 0)
        }
        return plans
    }

    static func quickLogMockLogs(_ scenario: QuickLogMockScenario, now: Date) -> [QuickLog] {
        let key = TrainingCalendar.key(now)
        var logs = calendarQuickLogs(now: now).filter { $0.loggedOn != key }
        if scenario == .quickLogs {
            logs += (0..<2).map { i in
                QuickLog(id: "mock-today-log-\(i)", loggedOn: key, loggedAt: now.addingTimeInterval(Double(i - 2) * 60),
                         timezone: TimeZone.current.identifier)
            }
        }
        return logs
    }

    static func quickLogMockCompleted(now: Date) -> [Session] {
        let c = TrainingCalendar.calendar
        let day = c.date(byAdding: .day, value: -2, to: now)!
        let start = c.date(bySettingHour: 7, minute: 0, second: 0, of: day)!
        var session = mockSession("mock-completed", title: "Morning rolls", start: start, host: "me")
        for i in session.people.indices { session.people[i].attended = true }
        return [session]
    }

    static func quickLogMockShared(now: Date) -> (session: Session, post: Post) {
        let c = TrainingCalendar.calendar
        let day = c.date(byAdding: .day, value: -1, to: now)!
        let start = c.date(bySettingHour: 19, minute: 0, second: 0, of: day)!
        var session = mockSession("mock-shared", title: "Evening rolls", start: start, host: "me")
        for i in session.people.indices { session.people[i].attended = true }
        let post = Post(id: "mock-shared-post", organizer: "me", title: session.title, gym: session.gym,
                        date: start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                        ago: "Yesterday", photo: "group-class", participants: session.going,
                        caption: "Good rounds with Kenji.", likes: [], extraLikes: 0, comments: [],
                        occurredAt: start, time: session.time)
        return (session, post)
    }

    private static func mockSession(_ id: String, title: String, start: Date, host: String) -> Session {
        let c = TrainingCalendar.calendar
        return Session(id: id, title: title, day: start.formatted(.dateTime.weekday(.abbreviated)),
                       date: c.component(.day, from: start), month: start.formatted(.dateTime.month(.abbreviated)),
                       time: start.formatted(.dateTime.hour().minute()), gym: "Tidewater BJJ", organizer: host, privacy: .link,
                       people: [Attendee(id: host, status: .going), Attendee(id: host == "me" ? "kenji" : "me", status: .going)],
                       startsAt: start)
    }

    static var quickLogs: [QuickLog] { calendarQuickLogs(now: Date()) }

    private static func calendarQuickLogs(now: Date) -> [QuickLog] {
        let c = TrainingCalendar.calendar, week = TrainingCalendar.week(now)
        var dates = [week[0]]
        for w in 1...16 {
            let monday = c.date(byAdding: .weekOfYear, value: -w, to: week[0])!
            dates += [monday, c.date(byAdding: .day, value: w % 5 + 1, to: monday)!]
        }
        return dates.enumerated().map { i, date in
            QuickLog(id: "sample-log-\(i)", loggedOn: TrainingCalendar.key(date),
                     loggedAt: c.date(bySettingHour: 7, minute: 10, second: 0, of: date)!, timezone: c.timeZone.identifier)
        }
    }
    static var calendarPlans: [Session] {
        let c = TrainingCalendar.calendar, today = c.startOfDay(for: Date())
        func plan(_ id: String, offset: Int, host: String) -> Session {
            let start = c.date(bySettingHour: 19, minute: 0, second: 0, of: c.date(byAdding: .day, value: offset, to: today)!)!
            return Session(id: id, title: "\(start.formatted(.dateTime.weekday(.wide))) no-gi", day: start.formatted(.dateTime.weekday(.abbreviated)),
                           date: c.component(.day, from: start), month: start.formatted(.dateTime.month(.abbreviated)), time: "19:00", gym: "Tidewater BJJ",
                           organizer: host, privacy: .link, people: [Attendee(id: "me", status: .going), Attendee(id: "kenji", status: .going)], startsAt: start)
        }
        return [plan("calendar-today", offset: 0, host: "me"), plan("calendar-future", offset: 2, host: "me"),
                plan("calendar-guest", offset: -1, host: "kenji"), plan("calendar-second-plan", offset: -1, host: "me")]
    }
    static var calendarCompleted: [Session] {
        var s = calendarPlans[0]
        s = Session(id: "calendar-unshared", title: "Morning rolls", day: s.day, date: s.date, month: s.month,
                    time: "07:00", gym: s.gym, organizer: "me", people: s.people,
                    startsAt: TrainingCalendar.calendar.date(byAdding: .day, value: -2, to: Date()))
        for i in s.people.indices { s.people[i].attended = true }
        return [s]
    }
}
#endif
