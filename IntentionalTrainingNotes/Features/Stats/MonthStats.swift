import Foundation
import SwiftUI

// MARK: - Month key

/// A year+month identifier used to scope the Stat tab.
struct MonthKey: Hashable, Comparable, Identifiable {
    let year: Int
    let month: Int // 1...12

    var id: String { "\(year)-\(month)" }

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    init(date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month], from: date)
        self.year = c.year ?? 2000
        self.month = c.month ?? 1
    }

    static func < (lhs: MonthKey, rhs: MonthKey) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }

    static var current: MonthKey { MonthKey(date: Date()) }

    func startDate(_ calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
    }

    func contains(_ date: Date, _ calendar: Calendar = .current) -> Bool {
        let c = calendar.dateComponents([.year, .month], from: date)
        return c.year == year && c.month == month
    }

    func daysInMonth(_ calendar: Calendar = .current) -> Int {
        calendar.range(of: .day, in: .month, for: startDate(calendar))?.count ?? 30
    }

    func adding(months: Int, _ calendar: Calendar = .current) -> MonthKey {
        let d = calendar.date(byAdding: .month, value: months, to: startDate(calendar)) ?? startDate(calendar)
        return MonthKey(date: d, calendar: calendar)
    }

    /// "Jul 2026"
    var label: String { MonthStatsFormat.monthYear.string(from: startDate()) }
    /// "Jul '26"
    var shortLabel: String {
        let f = MonthStatsFormat.monthAbbrev.string(from: startDate())
        return "\(f) '\(String(format: "%02d", year % 100))"
    }
}

enum MonthStatsFormat {
    static let monthYear: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MMM yyyy"; return f }()
    static let monthAbbrev: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MMM"; return f }()
}

// MARK: - Section value types

struct GoalWorkedStat: Identifiable {
    let id: String
    let name: String
    let color: Color
    let sessionCount: Int
    let taskCount: Int
    let latestDate: Date?
}

struct CollectedTrophyStat: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let collectedDate: Date
    let days: Int
    let hitRatio: String
}

struct ActiveHuntStat: Identifiable {
    let id: String
    let title: String
    let startedDate: Date
    let hits: Int
    let required: Int
}

/// A single verbatim line pulled from a reflection's "what worked" / "where I got
/// stuck" text, shown as a bulleted quote in the Stat feedback lists.
struct ReflectionQuote: Identifiable {
    let id: String
    let text: String
    let goalName: String?
    let goalColor: Color?
    let date: Date
    let reflectionId: String
}

// MARK: - Aggregated month stats

struct MonthStats {
    let month: MonthKey
    let sessionCount: Int
    let previousSessionCount: Int
    let dayBars: [Int]
    let todayDayIndex: Int?
    let reflectionCount: Int
    let streakWeeks: Int
    let avgPacePerWeek: Double
    let goalsWorked: [GoalWorkedStat]
    let collectedTrophies: [CollectedTrophyStat]
    let activeHunts: [ActiveHuntStat]
    let workingQuotes: [ReflectionQuote]
    let stuckQuotes: [ReflectionQuote]

    var delta: Int { sessionCount - previousSessionCount }
    var collectedCount: Int { collectedTrophies.count }
    var activeCount: Int { activeHunts.count }
    var activeGoalCount: Int { goalsWorked.count }

    var hasAnyData: Bool {
        sessionCount > 0 || reflectionCount > 0 || !collectedTrophies.isEmpty
            || !activeHunts.isEmpty || !goalsWorked.isEmpty
    }
}

// MARK: - Computation

extension NotebookStore {

    /// Distinct months that contain any training content, plus the current month,
    /// sorted newest-first. Powers the month picker and recent-months rail.
    func availableStatMonths(_ calendar: Calendar = .current) -> [MonthKey] {
        var set = Set<MonthKey>()
        for s in notebook.sessions where s.status == .done { set.insert(MonthKey(date: s.date, calendar: calendar)) }
        for r in notebook.reflections { set.insert(MonthKey(date: r.date, calendar: calendar)) }
        for b in notebook.bounties {
            set.insert(MonthKey(date: b.createdAt, calendar: calendar))
            if let c = b.collectedAt { set.insert(MonthKey(date: c, calendar: calendar)) }
        }
        set.insert(.current)
        return set.sorted(by: >)
    }

    func monthStats(for month: MonthKey, calendar: Calendar = .current) -> MonthStats {
        let doneSessions = notebook.sessions.filter { $0.status == .done }

        let monthSessions = doneSessions.filter { month.contains($0.date, calendar) }
        let prevMonth = month.adding(months: -1, calendar)
        let prevCount = doneSessions.filter { prevMonth.contains($0.date, calendar) }.count

        // Day-of-month bars
        let days = month.daysInMonth(calendar)
        var bars = Array(repeating: 0, count: days)
        for s in monthSessions {
            let day = calendar.component(.day, from: s.date)
            if day >= 1 && day <= days { bars[day - 1] += 1 }
        }
        let today = Date()
        let todayIndex: Int? = month.contains(today, calendar) ? calendar.component(.day, from: today) : nil

        let monthReflections = notebook.reflections.filter { month.contains($0.date, calendar) }

        let streak = streakWeeks(endingIn: month, calendar: calendar, doneSessions: doneSessions)
        let weeksInMonth = max(1, Int((Double(days) / 7.0).rounded()))
        let pace = Double(monthSessions.count) / Double(weeksInMonth)

        let goalsWorked = computeGoalsWorked(monthSessions: monthSessions)
        let (trophies, hunts) = computeBounties(month: month, calendar: calendar)
        let working = computeQuotes(monthReflections, keyPath: \.workedText)
        let stuck = computeQuotes(monthReflections, keyPath: \.stuckText)

        return MonthStats(
            month: month,
            sessionCount: monthSessions.count,
            previousSessionCount: prevCount,
            dayBars: bars,
            todayDayIndex: todayIndex,
            reflectionCount: monthReflections.count,
            streakWeeks: streak,
            avgPacePerWeek: pace,
            goalsWorked: goalsWorked,
            collectedTrophies: trophies,
            activeHunts: hunts,
            workingQuotes: working,
            stuckQuotes: stuck
        )
    }

    // MARK: Helpers

    /// Consecutive weeks with at least one completed session, counting back from the
    /// selected month's final week (or the current week when it's the current month).
    private func streakWeeks(endingIn month: MonthKey, calendar: Calendar, doneSessions: [PlannedSession]) -> Int {
        let doneWeeks = Set(doneSessions.map { calendar.mondayStartOfWeek(containing: $0.date) })
        let anchorDate: Date
        if month.contains(Date(), calendar) {
            anchorDate = Date()
        } else {
            let start = month.startDate(calendar)
            let range = calendar.range(of: .day, in: .month, for: start)?.count ?? 28
            anchorDate = calendar.date(byAdding: .day, value: range - 1, to: start) ?? start
        }
        var weekStart = calendar.mondayStartOfWeek(containing: anchorDate)
        if !doneWeeks.contains(weekStart) {
            guard let prev = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) else { return 0 }
            weekStart = prev
        }
        var streak = 0
        while doneWeeks.contains(weekStart) {
            streak += 1
            guard let prev = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) else { break }
            weekStart = prev
        }
        return streak
    }

    private func computeGoalsWorked(monthSessions: [PlannedSession]) -> [GoalWorkedStat] {
        let grouped = Dictionary(grouping: monthSessions, by: { $0.goalId })
        return grouped.compactMap { goalId, sessions -> GoalWorkedStat? in
            guard let goal = notebook.goals.first(where: { $0.id == goalId }) else { return nil }
            let taskCount = notebook.tasks.filter { $0.goalId == goalId }.count
            let latest = sessions.map { $0.date }.max()
            return GoalWorkedStat(
                id: goalId,
                name: goal.name,
                color: goal.goalColor,
                sessionCount: sessions.count,
                taskCount: taskCount,
                latestDate: latest
            )
        }
        .sorted { $0.sessionCount != $1.sessionCount ? $0.sessionCount > $1.sessionCount : $0.name < $1.name }
    }

    private func computeBounties(month: MonthKey, calendar: Calendar) -> ([CollectedTrophyStat], [ActiveHuntStat]) {
        let monthEnd: Date = {
            let start = month.startDate(calendar)
            let days = month.daysInMonth(calendar)
            return calendar.date(byAdding: .day, value: days, to: start) ?? start
        }()

        let trophies: [CollectedTrophyStat] = notebook.bounties
            .filter { $0.status == .collected }
            .compactMap { b in
                guard let collected = b.collectedAt, month.contains(collected, calendar) else { return nil }
                let name = notebook.tasks.first(where: { $0.id == b.taskId })?.name ?? "Technique"
                let subtitle: String
                if let p = b.targetPartner?.nilIfBlank {
                    subtitle = "on \(p)"
                } else {
                    subtitle = "×\(b.requiredHits)"
                }
                let dayCount = max(1, (calendar.dateComponents([.day], from: b.createdAt, to: collected).day ?? 0))
                return CollectedTrophyStat(
                    id: b.id,
                    title: "\(name) \(subtitle)",
                    subtitle: subtitle,
                    collectedDate: collected,
                    days: dayCount,
                    hitRatio: "\(b.hitCount)/\(b.requiredHits)"
                )
            }
            .sorted { $0.collectedDate > $1.collectedDate }

        let hunts: [ActiveHuntStat] = notebook.bounties
            .filter { $0.status == .active && $0.createdAt < monthEnd }
            .map { b in
                let name = notebook.tasks.first(where: { $0.id == b.taskId })?.name ?? "Technique"
                let subtitle = b.targetPartner?.nilIfBlank.map { "on \($0)" } ?? "×\(b.requiredHits)"
                return ActiveHuntStat(
                    id: b.id,
                    title: "\(name) \(subtitle)",
                    startedDate: b.createdAt,
                    hits: b.hitCount,
                    required: b.requiredHits
                )
            }
            .sorted { $0.startedDate > $1.startedDate }

        return (trophies, hunts)
    }

    /// Splits each reflection's verbatim "what worked" / "where I got stuck" text
    /// into individual bulleted lines, newest first, with goal + date attribution.
    private func computeQuotes(_ reflections: [Reflection], keyPath: KeyPath<Reflection, String>) -> [ReflectionQuote] {
        let sorted = reflections.sorted { $0.date > $1.date }
        var quotes: [ReflectionQuote] = []
        for r in sorted {
            let goal = notebook.sessions.first(where: { $0.id == r.sessionId })
                .flatMap { session in notebook.goals.first(where: { $0.id == session.goalId }) }
            let lines = r[keyPath: keyPath]
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            for (idx, line) in lines.enumerated() {
                quotes.append(ReflectionQuote(
                    id: "\(r.id)-\(idx)",
                    text: line,
                    goalName: goal?.name,
                    goalColor: goal?.goalColor,
                    date: r.date,
                    reflectionId: r.id
                ))
            }
        }
        return quotes
    }
}
