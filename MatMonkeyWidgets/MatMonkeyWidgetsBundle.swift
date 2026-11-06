import SwiftUI
import WidgetKit

/// Two independent widget kinds, each in small and medium. No settings: the gallery shows
/// both with a preview and one line each, and people can add either, both, or several.
@main
struct MatMonkeyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RhythmWidget()
        NextSessionWidget()
    }
}

/// Realistic sample content for the gallery (before the app has written a snapshot)
/// and for placeholders, which iOS draws redacted.
enum WidgetSamples {
    static func snapshot(now: Date) -> WidgetSnapshot {
        let calendar = WidgetCalendar.calendar()
        var entries: [String: Int] = [:]
        // A steady few days a week, one week off, a double on one day.
        let pattern: [Int: Int] = [1: 1, 3: 1, 4: 2, 5: 1, 6: 1, 8: 1, 10: 1, 13: 1, 15: 1, 17: 2, 20: 1, 23: 1, 27: 1, 29: 1,
                                   41: 1, 43: 1, 45: 1, 48: 1, 51: 1, 55: 1, 57: 1, 59: 1, 62: 1, 64: 1, 69: 1, 71: 1, 73: 1, 76: 1, 78: 1, 80: 1]
        for (back, count) in pattern {
            if let day = calendar.date(byAdding: .day, value: -back, to: now) {
                entries[WidgetCalendar.key(day, calendar: calendar), default: 0] += count
            }
        }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        let start = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        let session = WidgetSnapshot.Session(
            id: "sample", title: "Saturday open mat", venue: "Tidewater BJJ", start: start,
            end: start.addingTimeInterval(2 * 3600), hostedByMe: false, hostName: "Sarah", hostHue: "sky",
            partners: [WidgetSnapshot.Partner(firstName: "Sarah", initials: "SL", hue: "sky"),
                       WidgetSnapshot.Partner(firstName: "Alex", initials: "AM", hue: "mint"),
                       WidgetSnapshot.Partner(firstName: "Priya", initials: "PN", hue: "sun")])
        return WidgetSnapshot(signedIn: true, updatedAt: now,
                              rhythm: WidgetSnapshot.Rhythm(quickLogAvailable: true, entries: entries),
                              sessions: [session], invitationHost: nil)
    }
}
