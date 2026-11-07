import Foundation
import WidgetKit

/// App side of the home-screen widgets: builds the snapshot they read and routes their taps.
/// Widgets never write data; the app saves, then republishes this snapshot.
extension AppModel {
    /// What Your rhythm and Next session show. Uses the same definitions as the app:
    /// day entries match Stats › Your rhythm, sessions match Activity's Coming up.
    func widgetSnapshot(now: Date = Date(), updatedAt: Date? = nil) -> WidgetSnapshot {
        guard isSignedIn else { return .signedOut }
        let calendar = TrainingCalendar.calendar
        var entries: [String: Int] = [:]
        if quickTrainingLogEnabled {
            for day in WidgetCalendar.weeks(13, endingAt: now, calendar: calendar).joined()
            where calendar.startOfDay(for: day) <= calendar.startOfDay(for: now) {
                let count = entryCount(day)
                if count > 0 { entries[WidgetCalendar.key(day, calendar: calendar)] = count }
            }
        } else {
            // Older backends: the read-only rhythm, one entry per past session you hosted or joined.
            for date in rhythmSessionDates ?? [] where date <= now {
                entries[WidgetCalendar.key(date, calendar: calendar), default: 0] += 1
            }
        }

        let sessions: [WidgetSnapshot.Session] = upcoming
            .filter { s in
                (s.organizer == "me" || s.status(of: "me") == .going)
                    && !isCompleted(s)
                    && !s.people.contains { $0.id == "me" && $0.attended }
            }
            .map { s in
                let start = startDate(of: s)
                var seen = Set<String>()
                let partnerIDs = ([s.organizer] + s.going).filter { $0 != "me" && seen.insert($0).inserted }
                let host = person(s.organizer)
                return WidgetSnapshot.Session(
                    id: s.id, title: s.title, venue: s.gym, start: start,
                    end: start.addingTimeInterval(Self.widgetSessionLength),
                    hostedByMe: s.organizer == "me",
                    hostName: s.organizer == "me" ? "You" : host.firstName,
                    hostHue: s.organizer == "me" ? FriendHue.coral.rawValue : host.hue.rawValue,
                    partners: partnerIDs.map { id in
                        let p = person(id)
                        return WidgetSnapshot.Partner(firstName: p.firstName, initials: Self.initials(p.name), hue: p.hue.rawValue)
                    })
            }
            .filter { $0.end > now }
            .sorted { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }

        return WidgetSnapshot(
            signedIn: true,
            updatedAt: updatedAt ?? now,
            rhythm: WidgetSnapshot.Rhythm(quickLogAvailable: quickTrainingLogEnabled, entries: entries),
            sessions: Array(sessions.prefix(4)),
            invitationHost: trainingInvitations.first.map { person($0.organizer).firstName })
    }

    /// Writes the snapshot for the installed app only (never preview or sample data)
    /// and reloads widgets when something they show changed.
    func publishWidgetSnapshot(now: Date = Date(), updatedAt: Date? = nil) {
        guard isLive else { return }
        if WidgetStore.write(widgetSnapshot(now: now, updatedAt: updatedAt)) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// A widget tap. Each lands on an existing screen; logging stays the app's own flow.
    func openWidget(_ destination: WidgetDestination) {
        guard isSignedIn else { return }
        switch destination {
        case .quickLog:
            if quickTrainingLogEnabled {
                setTab(.activity)
                widgetQuickLogRequest = UUID()
            } else {
                openWidget(.rhythm)
            }
        case .rhythm:
            setTab(.profile)
            widgetProfileSectionRequest = UUID()
        case .session(let id):
            setTab(.training)
            if findSession(id) != nil { go(.session(id: id)) }
        case .plan:
            setTab(.training)
            go(.create())
        case .home:
            break
        }
    }

    /// Sessions have no end time yet; the widget treats them as two hours long.
    static let widgetSessionLength: TimeInterval = 2 * 3600

    static func initials(_ name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map { String($0).uppercased() }.joined()
        return letters.isEmpty ? "?" : letters
    }
}
