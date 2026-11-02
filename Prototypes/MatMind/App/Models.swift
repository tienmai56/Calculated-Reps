import Foundation

struct Person: Identifiable, Hashable {
    let id: String
    var name: String
    var belt: BeltRank
    var stripes: Int
    var gym: String
    var hue: FriendHue
    var photo: String?
    var email: String?

    var firstName: String { name.split(separator: " ").first.map(String.init) ?? name }
    var avatar: MMAvatarPerson { MMAvatarPerson(name: name, photo: photo) }
}

/// A friendship's weekly streak. `weeks` holds the last completed calendar
/// weeks, oldest to newest; `thisWeek` is the current Mon–Sun week.
struct Friendship: Identifiable, Hashable {
    let id: String
    var weeks: [Bool]
    var thisWeek: MMWeekState
    var best: Int
    var together: Int
    var brokeAgo: String?

    /// Consecutive completed weeks ending now (this week counts once it's done).
    var streak: Int {
        var n = 0
        for done in weeks.reversed() {
            if done { n += 1 } else { break }
        }
        return n + (thisWeek == .done ? 1 : 0)
    }
}

struct Comment: Identifiable, Hashable {
    let id = UUID()
    var who: String
    var text: String
    var fresh = false
}

struct Post: Identifiable, Hashable {
    let id: String
    var organizer: String
    var title: String
    var gym: String
    var date: String
    var ago: String
    var photo: String?
    var participants: [String]
    var caption: String
    var likes: [String]
    var extraLikes: Int
    var comments: [Comment]
}

enum RSVP: String {
    case going, invited, declined

    var badge: (variant: MMBadgeVariant, label: String) {
        switch self {
        case .going: (.success, "Going")
        case .invited: (.warning, "Invited")
        case .declined: (.neutral, "Declined")
        }
    }
}

enum Privacy: String {
    case friends, link
}

struct Attendee: Hashable {
    var id: String
    var status: RSVP
}

struct Session: Identifiable, Hashable {
    let id: String
    var title: String
    var day: String
    var date: Int
    var month: String
    var time: String
    var gym: String
    var organizer: String
    var privacy: Privacy = .friends
    var people: [Attendee]
    var note: String?

    func status(of id: String) -> RSVP? { people.first { $0.id == id }?.status }

    mutating func set(_ id: String, _ status: RSVP) {
        if let i = people.firstIndex(where: { $0.id == id }) {
            people[i].status = status
        } else {
            people.append(Attendee(id: id, status: status))
        }
    }

    var going: [String] { people.filter { $0.status == .going }.map(\.id) }
}

struct AppNotification: Identifiable, Hashable {
    enum Kind { case invite, joined, comment, published }

    let id: String
    var kind: Kind
    var who: String
    var session: String?
    var text: String = ""
    var quote: String?
    var photo: String?
    var time: String
    var unread = false
}

enum AppTab: String, CaseIterable {
    case activity, training, friends, profile
}

/// Pushed screens. The tab bar only shows on the tab roots.
enum Route: Hashable {
    case post(id: String, menu: Bool = false, focus: Bool = false)
    case session(id: String)
    case create(past: Bool = false, friend: String? = nil)
    case complete(id: String)
    case friend(id: String)
    case qr(scan: Bool = false)
    case notifications
}

struct SessionDraft {
    var title: String
    var day: String
    var date: Int
    var month: String
    var time: String
    var gym: String
    var note: String
    var invited: [String]
    var privacy: Privacy
    var past: Bool
}

struct StreakTick: Identifiable {
    var id: String
    var from: Int
    var to: Int
    var friendship: Friendship
}

struct PublishResult {
    var post: Post
    var streaks: [StreakTick]
}
