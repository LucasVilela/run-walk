import Foundation

/// One calendar day in the day-by-day view.
public struct DayEntry: Equatable, Sendable, Identifiable {
    public enum Kind: Equatable, Sendable {
        /// Runs done that day (newest last).
        case ran([RunRecord])
        /// Today or later: the forecast workout for that day.
        case planned(Workout)
        /// A day off. Past run days you didn't run are rest days too: nothing is ever "missed".
        case rest
    }

    public let date: Date
    public let kind: Kind
    public let isToday: Bool

    public var id: Date { date }
}

/// Every day from the plan's start (or your first run, if earlier) to the forecast finish:
/// what you did on past days and what's planned for the rest.
public enum DayByDay {
    public static func days(
        settings: UserSettings, runs: [RunRecord], completed: Set<String>, now: Date, lastCompletedAt: Date?,
        calendar: Calendar
    ) -> [DayEntry] {
        let today = calendar.startOfDay(for: now)
        let forecast = Scheduler.forecast(
            completed: completed, settings: settings, now: now, lastCompletedAt: lastCompletedAt,
            calendar: calendar)
        var planned: [Date: Workout] = [:]
        for item in forecast { planned[item.date] = item.workout }
        var ran: [Date: [RunRecord]] = [:]
        for run in runs.sorted(by: { $0.startedAt < $1.startedAt }) {
            ran[calendar.startOfDay(for: run.startedAt), default: []].append(run)
        }

        let starts = [calendar.startOfDay(for: settings.startDate)] + ran.keys
        let first = min(starts.min() ?? today, today)
        let last = max(forecast.last?.date ?? today, today)

        var days: [DayEntry] = []
        var day = first
        while day <= last {
            let kind: DayEntry.Kind
            if let runs = ran[day] {
                kind = .ran(runs)
            } else if day >= today, let workout = planned[day] {
                kind = .planned(workout)
            } else {
                kind = .rest
            }
            days.append(DayEntry(date: day, kind: kind, isToday: day == today))
            day = DateHelpers.addDays(1, to: day, calendar)
        }
        return days
    }
}
