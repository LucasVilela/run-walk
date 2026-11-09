import Foundation

public struct PlannedReminder: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case runDay, nudge }

    public let date: Date
    public let kind: Kind
    public let body: String
}

/// Local reminders, rebuilt on every app open and after every run.
/// Run days only, at the chosen time; one nudge the day after a missed run; never more than one a day.
/// Bodies always name the *next* workout: if the user runs, the app reschedules, so it stays right.
public enum Reminders {
    public static let horizonDays = 14

    public static func plan(
        settings: UserSettings, completed: Set<String>, now: Date, lastCompletedAt: Date?, calendar: Calendar
    ) -> [PlannedReminder] {
        let settings = settings.sanitized()
        guard settings.remindersOn, let next = Scheduler.nextWorkout(completed: completed) else { return [] }

        let minutes = next.totalSeconds(warmupSec: settings.warmupSec, cooldownSec: settings.cooldownSec) / 60
        let runBody = "\(next.title) today — \(minutes) min. You've got this."
        let nudgeBody = "No rush. \(next.title) is ready whenever you are."
        let firstDay = max(calendar.startOfDay(for: now), calendar.startOfDay(for: settings.startDate))
        let ranToday = lastCompletedAt.map { calendar.isDate($0, inSameDayAs: now) } ?? false

        func isRunDay(_ day: Date) -> Bool {
            settings.runDays.contains(DateHelpers.weekday(day, calendar)) && day >= firstDay
        }

        var reminders: [PlannedReminder] = []
        var nudgeAfter: Date?
        for offset in 0..<horizonDays {
            let day = DateHelpers.addDays(offset, to: calendar.startOfDay(for: now), calendar)
            let fire = DateHelpers.at(minutes: settings.reminderMinutes, on: day, calendar)
            let today = offset == 0

            if isRunDay(day) {
                // A run day you already ran on, or that falls inside the rest window, is a rest day.
                let resting = Scheduler.isResting(now: fire, lastCompletedAt: lastCompletedAt)
                guard !resting && !(today && ranToday) else { continue }
                if nudgeAfter == nil { nudgeAfter = day }
                if fire > now {
                    reminders.append(PlannedReminder(date: fire, kind: .runDay, body: runBody))
                }
            } else if let missed = nudgeAfter, DateHelpers.daysBetween(missed, day, calendar) == 1, fire > now
            {
                // The first upcoming run day is only "missed" if no run happens; the app
                // reschedules after every run, which removes this nudge.
                reminders.append(PlannedReminder(date: fire, kind: .nudge, body: nudgeBody))
            }
        }
        return reminders
    }
}
