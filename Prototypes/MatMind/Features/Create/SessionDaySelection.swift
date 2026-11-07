import Foundation

/// Local calendar dates for the planning form. Upcoming plans are picked on a
/// month calendar that reaches a year ahead; past sessions pick one recent day.
/// Refreshing keeps selections on the same civil dates.
struct SessionDaySelection {
    struct Day: Hashable {
        var label: String
        var weekday: String
        var date: Int
        var month: String
        var value: Date
    }

    /// How far ahead the calendar lets you plan.
    static let planningHorizonMonths = 12
    private static let pastDayCount = 5

    private(set) var calendar: Calendar
    private(set) var today: Date
    var pastDayIndex = 0
    /// Upcoming days picked on the calendar, each the start of a local day.
    private(set) var selectedDates: Set<Date> = []
    /// First day of the month the calendar shows.
    private(set) var visibleMonth: Date

    init(now: Date = Date(), calendar: Calendar = .current) {
        self.calendar = calendar
        today = calendar.startOfDay(for: now)
        visibleMonth = Self.monthStart(of: today, in: calendar)
    }

    // MARK: Past days

    func pastDays() -> [Day] {
        let formatter = Self.formatter(for: calendar)
        return (0..<Self.pastDayCount).map { index in
            let value = calendar.date(byAdding: .day, value: -index - 1, to: today)!
            formatter.dateFormat = "EEE"; let weekday = formatter.string(from: value)
            formatter.dateFormat = "MMM"; let month = formatter.string(from: value)
            return Day(label: index == 0 ? "Yesterday" : weekday,
                       weekday: weekday, date: calendar.component(.day, from: value), month: month, value: value)
        }
    }

    // MARK: Upcoming calendar

    /// The last day that can be planned.
    var lastPlannableDay: Date {
        calendar.date(byAdding: .month, value: Self.planningHorizonMonths, to: today)!
    }

    var firstMonth: Date { Self.monthStart(of: today, in: calendar) }
    var lastMonth: Date { Self.monthStart(of: lastPlannableDay, in: calendar) }
    var canShowPreviousMonth: Bool { visibleMonth > firstMonth }
    var canShowNextMonth: Bool { visibleMonth < lastMonth }

    var sortedSelectedDates: [Date] { selectedDates.sorted() }

    func isPlannable(_ day: Date) -> Bool {
        let day = calendar.startOfDay(for: day)
        return day >= today && day <= lastPlannableDay
    }

    func isSelected(_ day: Date) -> Bool { selectedDates.contains(calendar.startOfDay(for: day)) }

    mutating func toggle(_ day: Date) {
        let day = calendar.startOfDay(for: day)
        guard isPlannable(day) else { return }
        if selectedDates.contains(day) { selectedDates.remove(day) } else { selectedDates.insert(day) }
    }

    mutating func clearSelection() { selectedDates = [] }

    /// Moves the calendar by whole months, staying within the planning horizon.
    mutating func showMonth(offset: Int) {
        guard let month = calendar.date(byAdding: .month, value: offset, to: visibleMonth) else { return }
        visibleMonth = min(max(Self.monthStart(of: month, in: calendar), firstMonth), lastMonth)
    }

    /// Weeks run Monday to Sunday, matching streak weeks. `nil` pads the first
    /// week up to the month's first day; the last week is padded to seven.
    func monthGrid() -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: visibleMonth) else { return [] }
        // Gregorian weekday: 1 = Sunday … 7 = Saturday. Monday-first offset.
        let leading = (calendar.component(.weekday, from: visibleMonth) + 5) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<range.count {
            cells.append(calendar.date(byAdding: .day, value: offset, to: visibleMonth))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    /// Monday-first single-letter weekday headings.
    var weekdaySymbols: [String] {
        let symbols = Self.formatter(for: calendar).veryShortStandaloneWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
        return Array(symbols[1...] + symbols[..<1])
    }

    func monthTitle(_ month: Date? = nil) -> String {
        let month = month ?? visibleMonth
        let formatter = Self.formatter(for: calendar)
        formatter.dateFormat = calendar.isDate(month, equalTo: today, toGranularity: .year) ? "MMMM" : "MMMM yyyy"
        return formatter.string(from: month)
    }

    /// Selected days outside the visible month, e.g. "Also 2 in Dec, 1 in Jan".
    var selectionElsewhereSummary: String? {
        let formatter = Self.formatter(for: calendar)
        formatter.dateFormat = "MMM"
        var counts: [(month: Date, count: Int)] = []
        for day in sortedSelectedDates where !calendar.isDate(day, equalTo: visibleMonth, toGranularity: .month) {
            let month = Self.monthStart(of: day, in: calendar)
            if counts.last?.month == month { counts[counts.count - 1].count += 1 } else { counts.append((month, 1)) }
        }
        guard !counts.isEmpty else { return nil }
        return "Also " + counts.map { "\($0.count) in \(formatter.string(from: $0.month))" }.joined(separator: ", ")
    }

    func accessibilityLabel(for day: Date) -> String {
        let formatter = Self.formatter(for: calendar)
        formatter.dateFormat = "EEEE, MMMM d"
        let text = formatter.string(from: day)
        return calendar.isDate(day, inSameDayAs: today) ? "Today, \(text)" : text
    }

    // MARK: Refresh

    /// Returns true when the calendar changed. Dates that left the plannable
    /// range are deselected; the past picker falls back to yesterday.
    @discardableResult
    mutating func refresh(now: Date = Date(), calendar newCalendar: Calendar = .current) -> Bool {
        let newToday = newCalendar.startOfDay(for: now)
        guard newToday != today || newCalendar != calendar else { return false }
        func civilDate(_ date: Date, in calendar: Calendar) -> DateComponents {
            calendar.dateComponents([.era, .year, .month, .day], from: date)
        }
        let selected = selectedDates.map { civilDate($0, in: calendar) }
        let month = civilDate(visibleMonth, in: calendar)
        let oldPast = pastDays()
        let past = civilDate(oldPast[min(pastDayIndex, oldPast.count - 1)].value, in: calendar)
        calendar = newCalendar
        today = newToday
        let lastDay = lastPlannableDay
        let kept = selected.compactMap { newCalendar.date(from: $0) }
            .map { newCalendar.startOfDay(for: $0) }
            .filter { $0 >= newToday && $0 <= lastDay }
        selectedDates = Set(kept)
        let restoredMonth = newCalendar.date(from: month).map { Self.monthStart(of: $0, in: newCalendar) } ?? firstMonth
        visibleMonth = min(max(restoredMonth, firstMonth), lastMonth)
        pastDayIndex = pastDays().firstIndex { civilDate($0.value, in: newCalendar) == past } ?? 0
        return true
    }

    // MARK: Helpers

    private static func monthStart(of date: Date, in calendar: Calendar) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    private static func formatter(for calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        return formatter
    }
}
