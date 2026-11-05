import Foundation

/// Local calendar dates for the planning form. Refreshing keeps selections on the
/// same civil dates rather than moving them with their positions in the carousel.
struct SessionDaySelection {
    struct Day: Hashable {
        var label: String
        var weekday: String
        var date: Int
        var month: String
        var value: Date
    }

    private(set) var calendar: Calendar
    private(set) var today: Date
    var pastDayIndex = 0
    var selectedDays: Set<Int> = []

    init(now: Date = Date(), calendar: Calendar = .current) {
        self.calendar = calendar
        today = calendar.startOfDay(for: now)
    }

    func days(past: Bool) -> [Day] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        return (0..<(past ? 5 : 7)).map { index in
            let value = calendar.date(byAdding: .day, value: past ? -index - 1 : index, to: today)!
            formatter.dateFormat = "EEE"; let weekday = formatter.string(from: value)
            formatter.dateFormat = "MMM"; let month = formatter.string(from: value)
            return Day(label: index == 0 ? (past ? "Yesterday" : "Today") : weekday,
                       weekday: weekday, date: calendar.component(.day, from: value), month: month, value: value)
        }
    }

    /// Returns true when the displayed calendar changed. Dates that left the
    /// available range are deselected; the past picker falls back to yesterday.
    @discardableResult
    mutating func refresh(now: Date = Date(), calendar newCalendar: Calendar = .current) -> Bool {
        let newToday = newCalendar.startOfDay(for: now)
        guard newToday != today || newCalendar != calendar else { return false }
        func civilDate(_ date: Date, in calendar: Calendar) -> DateComponents {
            calendar.dateComponents([.era, .year, .month, .day], from: date)
        }
        let oldUpcoming = days(past: false)
        let selected = Set(oldUpcoming.enumerated().compactMap { index, day in
            selectedDays.contains(index) ? civilDate(day.value, in: calendar) : nil
        })
        let oldPast = days(past: true)
        let past = civilDate(oldPast[min(pastDayIndex, oldPast.count - 1)].value, in: calendar)
        calendar = newCalendar
        today = newToday
        selectedDays = Set(days(past: false).enumerated().compactMap { index, day in
            selected.contains(civilDate(day.value, in: calendar)) ? index : nil
        })
        pastDayIndex = days(past: true).firstIndex { civilDate($0.value, in: calendar) == past } ?? 0
        return true
    }
}
