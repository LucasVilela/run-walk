import Foundation

/// Calendar helpers. Weekdays use `Calendar` numbering: 1 = Sunday … 7 = Saturday.
public enum DateHelpers {
    public static func weekday(_ date: Date, _ calendar: Calendar) -> Int {
        calendar.component(.weekday, from: date)
    }

    /// Whole calendar days from `from` to `to` (0 = same day).
    public static func daysBetween(_ from: Date, _ to: Date, _ calendar: Calendar) -> Int {
        let a = calendar.startOfDay(for: from)
        let b = calendar.startOfDay(for: to)
        return calendar.dateComponents([.day], from: a, to: b).day ?? 0
    }

    public static func addDays(_ days: Int, to date: Date, _ calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    /// `day` at `minutes` after midnight, in the calendar's time zone.
    public static func at(minutes: Int, on day: Date, _ calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: day)
        return calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: start) ?? start
    }

    /// True if two chosen days follow each other (Sat → Sun counts). Onboarding warns, never blocks.
    public static func hasConsecutiveDays(_ days: Set<Int>) -> Bool {
        days.contains { day in days.contains(day % 7 + 1) }
    }
}
