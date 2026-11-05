import Foundation

/// Daily reps, Monday–Sunday, for one technique's two-week comparison.
/// Names are matched across removal/re-addition; saved log snapshots stay intact.
struct TechniqueTrend: Identifiable, Equatable {
    let id: String
    let name: String
    var thisWeek = Array(repeating: 0, count: 7)
    var lastWeek = Array(repeating: 0, count: 7)

    var thisWeekTotal: Int { thisWeek.reduce(0, +) }
    var lastWeekTotal: Int { lastWeek.reduce(0, +) }
}

struct TechniqueTrendHistory {
    let trends: [TechniqueTrend]
    /// Today's position in a Monday-first week. Future days aren't chart points.
    let currentDayIndex: Int

    init(logs: [QuickLog], hitsByID: [String: [QuickLogHit]], now: Date = Date(), calendar: Calendar = TrainingCalendar.calendar) {
        var calendar = calendar
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        let today = calendar.startOfDay(for: now)
        currentDayIndex = (calendar.component(.weekday, from: today) + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -currentDayIndex, to: today)!
        let previousMonday = calendar.date(byAdding: .day, value: -7, to: monday)!
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false

        var result: [String: TechniqueTrend] = [:]
        var seenLogIDs: Set<String> = []
        // Use the newest saved spelling, independent of snapshot ordering.
        for log in logs.sorted(by: { $0.loggedAt == $1.loggedAt ? $0.id < $1.id : $0.loggedAt > $1.loggedAt }) {
            guard seenLogIDs.insert(log.id).inserted,
                  let day = formatter.date(from: log.loggedOn), formatter.string(from: day) == log.loggedOn,
                  day <= today else { continue }
            let offset = calendar.dateComponents([.day], from: previousMonday, to: day).day!
            for hit in hitsByID[log.id] ?? [] {
                let name = hit.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard hit.count > 0, !name.isEmpty else { continue }
                let key = name.lowercased(with: Locale(identifier: "en_US_POSIX"))
                var trend = result[key] ?? TechniqueTrend(id: key, name: name)
                if (0..<7).contains(offset) {
                    trend.lastWeek[offset] += hit.count
                } else if (7..<14).contains(offset) {
                    trend.thisWeek[offset - 7] += hit.count
                }
                result[key] = trend
            }
        }
        trends = result.values.sorted { $0.id < $1.id }
    }
}
