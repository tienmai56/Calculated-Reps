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
