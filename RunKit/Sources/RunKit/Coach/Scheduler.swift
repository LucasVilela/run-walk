import Foundation

/// What Today shows.
public enum TodayState: Equatable, Sendable {
    case run(Workout)
    case rest(next: Workout, nextDate: Date)
    case finished
}

/// The plan is sequential: the next workout is the first one not done. Dates are forecasts only,
/// recomputed from today and the chosen run days on every app open, so missed runs slide forward.
public enum Scheduler {
    /// After a completed run, Today shows a rest day for this long.
    public static let restInterval: TimeInterval = 20 * 3600

    public static func nextWorkout(completed: Set<String>) -> Workout? {
        Program.workouts.first { !completed.contains($0.id) }
    }

    public static func remaining(completed: Set<String>) -> [Workout] {
        guard let next = nextWorkout(completed: completed), let start = Program.index(of: next.id) else {
            return []
        }
        return Array(Program.workouts[start...])
    }

    /// The last completed workout before the next one (what "redo your last run" means).
    public static func lastCompleted(completed: Set<String>) -> Workout? {
        let limit =
            nextWorkout(completed: completed).flatMap { Program.index(of: $0.id) } ?? Program.workouts.count
        return Program.workouts[..<limit].last { completed.contains($0.id) }
    }

    public static func isResting(now: Date, lastCompletedAt: Date?) -> Bool {
        guard let lastCompletedAt else { return false }
        return now.timeIntervalSince(lastCompletedAt) < restInterval
    }

    /// Forecast date (start of day) for each remaining workout, in order.
    public static func forecast(
        completed: Set<String>, settings: UserSettings, now: Date, lastCompletedAt: Date?, calendar: Calendar
    ) -> [(workout: Workout, date: Date)] {
        let runDays = settings.sanitized().runDays
        var day = calendar.startOfDay(for: now)
        let ranToday = lastCompletedAt.map { calendar.isDate($0, inSameDayAs: now) } ?? false
        if ranToday || isResting(now: now, lastCompletedAt: lastCompletedAt) {
            day = DateHelpers.addDays(1, to: day, calendar)
        }
        day = max(day, calendar.startOfDay(for: settings.startDate))

        var result: [(Workout, Date)] = []
        for workout in remaining(completed: completed) {
            while !runDays.contains(DateHelpers.weekday(day, calendar)) {
                day = DateHelpers.addDays(1, to: day, calendar)
            }
            result.append((workout, day))
            day = DateHelpers.addDays(1, to: day, calendar)
        }
        return result
    }

    public static func finishDate(
        completed: Set<String>, settings: UserSettings, now: Date, lastCompletedAt: Date?, calendar: Calendar
    ) -> Date? {
        forecast(
            completed: completed, settings: settings, now: now, lastCompletedAt: lastCompletedAt,
            calendar: calendar
        ).last?.date
    }

    /// Run day when the next workout's forecast is today; otherwise a rest day (the user can
    /// still "Run anyway").
    public static func today(
        completed: Set<String>, settings: UserSettings, now: Date, lastCompletedAt: Date?, calendar: Calendar
    ) -> TodayState {
        let dates = forecast(
            completed: completed, settings: settings, now: now, lastCompletedAt: lastCompletedAt,
            calendar: calendar)
        guard let first = dates.first else { return .finished }
        if calendar.isDate(first.date, inSameDayAs: now) { return .run(first.workout) }
        return .rest(next: first.workout, nextDate: first.date)
    }

    // MARK: - Plan changes (only ever on a user tap)

    /// Marks every workout from `week` onwards as not done, so the plan restarts at that week.
    public static func restart(fromWeek week: Int, completed: Set<String>) -> Set<String> {
        completed.filter { id in (Program.workout(id: id)?.week ?? 0) < week }
    }

    /// Marks one workout as not done, so it comes up next (redo the last run).
    public static func redo(_ workoutId: String, completed: Set<String>) -> Set<String> {
        completed.subtracting([workoutId])
    }
}
