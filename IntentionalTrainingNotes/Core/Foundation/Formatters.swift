import Foundation

// MARK: - Shared Formatters

extension DateFormatter {
    static let trainingDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let timelineShortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yy"
        return formatter
    }()

    static let monthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    /// Display formatters (current locale, matching the previous inline usages).
    static let weekdayShortDate = make("EEE, MMM d")          // Mon, Jun 30
    static let weekdayLongDate = make("EEEE, MMM d")          // Monday, Jun 30
    static let weekdayShortDateYear = make("EEE, MMM d, yyyy") // Mon, Jun 30, 2026
    static let monthYear = make("MMMM yyyy")                  // June 2026
    static let weekdayAbbrev = make("EEE")                    // Mon
    static let clockTime = make("h:mm a")                     // 8:00 PM
    static let monthDayTime = make("MMM d · h:mm a")          // Jun 30 · 8:00 PM
    static let fullDateTimeAt = make("MMMM d, yyyy 'at' h:mm a") // June 30, 2026 at 8:00 PM

    private static func make(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter
    }
}

extension Calendar {
    func normalizedTrainingDay(_ date: Date) -> Date {
        startOfDay(for: date)
    }

    func mondayStartOfWeek(containing date: Date) -> Date {
        let start = startOfDay(for: date)
        let weekday = component(.weekday, from: start)
        let daysFromMonday = weekday == 1 ? -6 : 2 - weekday
        return self.date(byAdding: .day, value: daysFromMonday, to: start) ?? start
    }

    func sameTrainingDay(_ lhs: Date, _ rhs: Date) -> Bool {
        isDate(lhs, inSameDayAs: rhs)
    }
}

extension Date {
    var trainingDayString: String {
        DateFormatter.trainingDay.string(from: self)
    }
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Uppercases only the first letter, leaving the rest untouched.
    var capitalizedFirst: String {
        guard let first = first else { return self }
        return first.uppercased() + dropFirst()
    }

    /// Filesystem-safe form of an account id (used for on-disk storage paths).
    var sanitizedAccountId: String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        return unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }.map(String.init).joined()
    }
}
