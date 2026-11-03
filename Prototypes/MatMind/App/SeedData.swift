#if DEBUG || MAT_MIND_PROTOTYPE
import Foundation

/// Sample data from `ui_kits/app/data.js`. Photos: Unsplash (assets/photos).
enum SeedData {
    static let me = Person(id: "me", name: "Dani Alves", belt: .purple, stripes: 2, gym: "Tidewater BJJ",
                           hue: .coral, photo: "portrait-gi", email: "dani.alves@gmail.com", username: "dani")

    static let people: [String: Person] = [
        "sarah": Person(id: "sarah", name: "Sarah Lee", belt: .blue, stripes: 3, gym: "Tidewater BJJ", hue: .sky, username: "sarah"),
        "alex": Person(id: "alex", name: "Alex Moreno", belt: .white, stripes: 3, gym: "Tidewater BJJ", hue: .mint, username: "alex"),
        "priya": Person(id: "priya", name: "Priya Nair", belt: .blue, stripes: 1, gym: "Tidewater BJJ", hue: .sun, username: "priya"),
        "kenji": Person(id: "kenji", name: "Kenji Ito", belt: .purple, stripes: 0, gym: "Tidewater BJJ", hue: .plum, username: "kenji"),
        "jamie": Person(id: "jamie", name: "Jamie Cole", belt: .brown, stripes: 1, gym: "North Shore Grappling", hue: .plum, username: "jamie"),
        "marco": Person(id: "marco", name: "Marco Silva", belt: .black, stripes: 2, gym: "Harbor Jiu-Jitsu", hue: .coral, username: "marco"),
        "lena": Person(id: "lena", name: "Lena Park", belt: .white, stripes: 1, gym: "Tidewater BJJ", hue: .mint, username: "lena"),
    ]

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
             comments: [Comment(who: "alex", text: "Took me four months. Worth it."), Comment(who: "kenji", text: "Rematch Thursday?")]),
        Post(id: "p2", organizer: "jamie", title: "Leg drag drilling", gym: "North Shore Grappling", date: "Sat, Oct 31", ago: "2d",
             photo: "coach-help", participants: ["jamie", "priya", "marco"],
             caption: "Slow reps, then positional rounds from the leg drag. Priya was a menace.",
             likes: ["priya", "marco"], extraLikes: 11,
             comments: [Comment(who: "priya", text: "Hips sore in the best way")]),
        Post(id: "p3", organizer: "me", title: "Friday fundamentals + rolls", gym: "Tidewater BJJ", date: "Fri, Oct 30", ago: "3d",
             photo: "group-class", participants: ["me", "sarah", "priya", "lena"],
             caption: "Brought Lena to her first open roll. She tapped me with a collar choke. Proud and slightly embarrassed.",
             likes: ["sarah", "lena", "alex"], extraLikes: 27,
             comments: [Comment(who: "lena", text: "I will be telling everyone about this")]),
        Post(id: "p4", organizer: "alex", title: "Early bird gi class", gym: "Tidewater BJJ", date: "Wed, Oct 28", ago: "5d",
             photo: "gym-throw", participants: ["alex", "me", "sarah"],
             caption: "6am crew. Takedown day.", likes: ["sarah"], extraLikes: 8, comments: []),
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
        AppNotification(id: "n1", kind: .invite, who: "jamie", session: "s2", time: "20m", unread: true),
        AppNotification(id: "n2", kind: .joined, who: "alex", text: "joined Saturday open mat", time: "2h", unread: true),
        AppNotification(id: "n3", kind: .comment, who: "kenji", text: "commented on Sunday No-Gi open mat", quote: "Rematch Thursday?",
                        photo: "roll-gi", time: "16h", unread: true),
        AppNotification(id: "n4", kind: .published, who: "sarah", text: "shared Sunday No-Gi open mat. You're in it.", photo: "roll-gi", time: "18h"),
        AppNotification(id: "n5", kind: .joined, who: "sarah", text: "joined Saturday open mat", time: "1d"),
        AppNotification(id: "n6", kind: .like, who: "priya", text: "liked your memory", photo: "group-class", time: "1d"),
        AppNotification(id: "n7", kind: .friend, who: "lena", text: "added you as a training partner", time: "2d"),
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

#endif
