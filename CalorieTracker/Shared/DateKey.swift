import Foundation

/// Local-calendar-date "YYYY-MM-DD" keys, used to index daily logs.
///
/// Deliberately uses `Calendar.current`/local components instead of `Date.ISO8601Format()` or
/// `toISOString()` (which is UTC). The RN app's `UserDataContext.dateKey()` uses `toISOString()`,
/// which can bucket a log into the wrong day near local midnight in non-UTC timezones — this is a
/// known gap in the RN app, not something to replicate here.
enum DateKey {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func string(for date: Date) -> String {
        formatter.string(from: date)
    }

    static func date(from key: String) -> Date? {
        formatter.date(from: key)
    }

    static func today() -> String { string(for: Date()) }

    static func offset(_ days: Int, from date: Date = Date()) -> String {
        let shifted = Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
        return string(for: shifted)
    }
}
