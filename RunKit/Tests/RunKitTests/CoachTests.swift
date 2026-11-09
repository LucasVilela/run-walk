import Foundation
import Testing

@testable import RunKit

/// Fixed calendar for every coach test: Sydney time. 9 Nov 2026 is a Monday.
enum Cal {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Australia/Sydney")!
        return c
    }()

    static func date(_ month: Int, _ day: Int, _ hour: Int = 9, _ minute: Int = 0, year: Int = 2026) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    static func day(_ month: Int, _ day: Int, year: Int = 2026) -> Date {
        calendar.startOfDay(for: date(month, day, year: year))
    }

    static let settings = UserSettings(startDate: date(11, 9))

    static func ids(through id: String) -> Set<String> {
        let end = Program.index(of: id)!
        return Set(Program.workouts[...end].map(\.id))
    }

    static func run(
        _ id: String, _ workoutId: String, ended: Date, feeling: Feeling? = nil, pain: Bool = false
    ) -> RunRecord {
        RunRecord(
            id: id, workoutId: workoutId, startedAt: ended.addingTimeInterval(-1800), endedAt: ended,
            movingSec: 1800, runningSec: 600, feeling: feeling, pain: pain)
    }
}

@Suite struct SchedulerTests {
    func today(_ completed: Set<String>, now: Date, last: Date? = nil, settings: UserSettings = Cal.settings)
        -> TodayState
    {
        Scheduler.today(
            completed: completed, settings: settings, now: now, lastCompletedAt: last, calendar: Cal.calendar)
    }

    @Test func nextIsFirstNotDone() {
        #expect(Scheduler.nextWorkout(completed: [])?.id == "w1r1")
        #expect(Scheduler.nextWorkout(completed: ["w1r1", "w1r2"])?.id == "w1r3")
        #expect(Scheduler.nextWorkout(completed: ["w1r1", "w1r3"])?.id == "w1r2")
        #expect(Scheduler.nextWorkout(completed: Cal.ids(through: "w9r3")) == nil)
    }

    @Test func freshInstallOnARunDayShowsWeek1Run1() {
        #expect(today([], now: Cal.date(11, 9)) == .run(Program.workouts[0]))
    }

    @Test func offDayShowsRestWithNextDate() {
        #expect(
            today([], now: Cal.date(11, 10)) == .rest(next: Program.workouts[0], nextDate: Cal.day(11, 11)))
    }

    @Test func forecastAndFinishDate() {
        let dates = Scheduler.forecast(
            completed: [], settings: Cal.settings, now: Cal.date(11, 9), lastCompletedAt: nil,
            calendar: Cal.calendar)
        #expect(dates.count == 27)
        #expect(
            dates.prefix(4).map(\.date) == [
                Cal.day(11, 9), Cal.day(11, 11), Cal.day(11, 14), Cal.day(11, 16),
            ])
        let finish = Scheduler.finishDate(
            completed: [], settings: Cal.settings, now: Cal.date(11, 9), lastCompletedAt: nil,
            calendar: Cal.calendar)
        #expect(finish == Cal.day(1, 9, year: 2027))
    }

    @Test func restForTwentyHoursAfterARun() {
        // Ran Monday 7am; Monday evening is a rest day, next run Wednesday.
        let state = today(["w1r1"], now: Cal.date(11, 9, 18), last: Cal.date(11, 9, 7))
        #expect(state == .rest(next: Program.workouts[1], nextDate: Cal.day(11, 11)))
        // "Run anyway" on Sunday night: Monday morning is only 13 hours later.
        let monday = today(["w1r1"], now: Cal.date(11, 9, 9), last: Cal.date(11, 8, 20))
        #expect(monday == .rest(next: Program.workouts[1], nextDate: Cal.day(11, 11)))
        #expect(Scheduler.isResting(now: Cal.date(11, 9, 16), lastCompletedAt: Cal.date(11, 8, 20)) == false)
    }

    @Test func missedRunsSlideForward() {
        // Did w1r1 on Monday, skipped Wednesday. On Friday the next run is Saturday, no "missed" state.
        let state = today(["w1r1"], now: Cal.date(11, 13), last: Cal.date(11, 9, 7))
        #expect(state == .rest(next: Program.workouts[1], nextDate: Cal.day(11, 14)))
    }

    @Test func futureStartDate() {
        var settings = Cal.settings
        settings.startDate = Cal.date(11, 16)
        #expect(
            today([], now: Cal.date(11, 9), settings: settings)
                == .rest(next: Program.workouts[0], nextDate: Cal.day(11, 16)))
    }

    @Test func finishedPlan() {
        #expect(today(Cal.ids(through: "w9r3"), now: Cal.date(11, 9)) == .finished)
    }

    @Test func planChanges() {
        let done = Cal.ids(through: "w3r2")
        let restarted = Scheduler.restart(fromWeek: 3, completed: done)
        #expect(Scheduler.nextWorkout(completed: restarted)?.id == "w3r1")
        #expect(restarted.count == 6)
        #expect(Scheduler.lastCompleted(completed: done)?.id == "w3r2")
        #expect(Scheduler.lastCompleted(completed: ["w1r1", "w1r3"])?.id == "w1r1")
        #expect(Scheduler.nextWorkout(completed: Scheduler.redo("w3r2", completed: done))?.id == "w3r2")
    }
}

@Suite struct CoachRuleTests {
    func context(_ runs: [RunRecord], completed: Set<String>, now: Date, nextDate: Date? = nil)
        -> CoachContext
    {
        CoachContext(now: now, calendar: Cal.calendar, runs: runs, completed: completed, nextDate: nextDate)
    }

    @Test func tenDayGapSuggestsRedoingTheLastWorkout() throws {
        let runs = [Cal.run("a", "w2r1", ended: Cal.date(11, 1))]
        let s = try #require(
            Coach.suggestion(context(runs, completed: Cal.ids(through: "w2r1"), now: Cal.date(11, 11))))
        #expect(s.rule == .gapRedo)
        #expect(s.action == .redoWorkout("w2r1"))
        #expect(s.body.contains("Week 2 · Run 1"))
    }

    @Test func gapBoundaries() {
        let runs = [Cal.run("a", "w3r1", ended: Cal.date(11, 1))]
        let done = Cal.ids(through: "w3r1")
        #expect(Coach.suggestion(context(runs, completed: done, now: Cal.date(11, 7))) == nil, "6 days")
        #expect(
            Coach.suggestion(context(runs, completed: done, now: Cal.date(11, 8)))?.rule == .gapRedo, "7 days"
        )
        #expect(
            Coach.suggestion(context(runs, completed: done, now: Cal.date(11, 14)))?.rule == .gapRedo,
            "13 days")
        let back = Coach.suggestion(context(runs, completed: done, now: Cal.date(11, 15)))
        #expect(back?.rule == .gapBack, "14 days")
        #expect(back?.action == .goBackToWeek(2))
    }

    @Test func twoHardOfLastThreeSuggestsRepeatingTheWeek() throws {
        let runs = [
            Cal.run("a", "w3r1", ended: Cal.date(11, 2), feeling: .hard),
            Cal.run("b", "w3r2", ended: Cal.date(11, 4), feeling: .right),
            Cal.run("c", "w3r3", ended: Cal.date(11, 7), feeling: .hard),
        ]
        let s = try #require(
            Coach.suggestion(context(runs, completed: Cal.ids(through: "w3r3"), now: Cal.date(11, 8))))
        #expect(s.rule == .hardRepeat)
        #expect(s.action == .repeatWeek(3))
        #expect(s.acceptLabel == "Repeat week")
        #expect(s.dismissLabel == "Keep going")
    }

    @Test func oneHardIsNotEnough() {
        let runs = [
            Cal.run("a", "w3r1", ended: Cal.date(11, 2), feeling: .hard),
            Cal.run("b", "w3r2", ended: Cal.date(11, 4), feeling: .easy),
            Cal.run("c", "w3r3", ended: Cal.date(11, 7), feeling: nil),
        ]
        #expect(
            Coach.suggestion(context(runs, completed: Cal.ids(through: "w3r3"), now: Cal.date(11, 8))) == nil)
    }

    @Test func painComesFirstAndSilencesNudgesThatDay() {
        let runs = [
            Cal.run("a", "w3r1", ended: Cal.date(11, 2), feeling: .hard),
            Cal.run("b", "w3r2", ended: Cal.date(11, 4, 8), feeling: .hard, pain: true),
        ]
        let done = Cal.ids(through: "w3r2")
        let sameDay = Coach.candidates(context(runs, completed: done, now: Cal.date(11, 4, 18)))
        #expect(sameDay.map(\.rule) == [.pain])
        #expect(sameDay.first?.action == nil)

        let nextDay = Coach.candidates(context(runs, completed: done, now: Cal.date(11, 5)))
        #expect(nextDay.map(\.rule) == [.pain, .hardRepeat])

        let twoDaysLater = Coach.suggestion(context(runs, completed: done, now: Cal.date(11, 6)))
        #expect(twoDaysLater?.rule == .hardRepeat)
    }

    @Test func bigJumpPreviewDayBeforeAndDayOf() throws {
        let done = Cal.ids(through: "w5r2")
        let runs = [Cal.run("a", "w5r2", ended: Cal.date(11, 4))]
        let before = try #require(
            Coach.suggestion(context(runs, completed: done, now: Cal.date(11, 6), nextDate: Cal.day(11, 7))))
        #expect(before.rule == .bigJump)
        #expect(
            before.body
                == "Tomorrow's your first 20-minute run. Go slower than you think — slow enough to talk.")
        let dayOf = Coach.suggestion(
            context(runs, completed: done, now: Cal.date(11, 7), nextDate: Cal.day(11, 7)))
        #expect(dayOf?.body.hasPrefix("Today's your first 20-minute run") == true)
        #expect(
            Coach.suggestion(context(runs, completed: done, now: Cal.date(11, 5), nextDate: Cal.day(11, 7)))
                == nil)

        let w6 = Coach.suggestion(
            context(runs, completed: Cal.ids(through: "w6r2"), now: Cal.date(11, 6), nextDate: Cal.day(11, 7))
        )
        #expect(w6?.body.contains("first 25-minute run") == true)
    }

    @Test func threeEasyIsEncouragementOnly() throws {
        let runs = (1...3).map { Cal.run("r\($0)", "w2r\($0)", ended: Cal.date(11, $0 * 2), feeling: .easy) }
        let s = try #require(
            Coach.suggestion(context(runs, completed: Cal.ids(through: "w2r3"), now: Cal.date(11, 7))))
        #expect(s.rule == .easyStreak)
        #expect(s.action == nil, "never skips weeks")
    }

    @Test func dismissedSuggestionGivesWayToTheNextOne() {
        let runs = [
            Cal.run("a", "w3r1", ended: Cal.date(11, 2), feeling: .hard),
            Cal.run("b", "w3r2", ended: Cal.date(11, 4, 8), feeling: .hard, pain: true),
        ]
        var ctx = context(runs, completed: Cal.ids(through: "w3r2"), now: Cal.date(11, 5))
        ctx.dismissed = [CoachDismissal(rule: .pain, contextKey: "b")]
        #expect(Coach.suggestion(ctx)?.rule == .hardRepeat)
        ctx.dismissed.insert(CoachDismissal(rule: .hardRepeat, contextKey: "b"))
        #expect(Coach.suggestion(ctx) == nil)
    }
}

@Suite struct BadgeTests {
    @Test func earnedBadges() {
        #expect(Badge.earned(completed: []).isEmpty)
        #expect(Badge.earned(completed: ["w1r1"]) == [.firstRun])
        #expect(Badge.earned(completed: Cal.ids(through: "w1r3")) == [.firstRun, .week1])
        let w5 = Badge.earned(completed: Cal.ids(through: "w5r3"))
        #expect(w5.contains(.first20) && w5.contains(.week5))
        #expect(Badge.earned(completed: Cal.ids(through: "w9r3")).count == Badge.allCases.count)
    }

    @Test func newlyEarnedInDisplayOrder() {
        let fresh = Badge.newlyEarned(
            completed: Cal.ids(through: "w5r3"), alreadyUnlocked: [.firstRun, .week1])
        #expect(fresh == [.week2, .week3, .week4, .week5, .first20])
        #expect(Badge.week7.title == "Week 7 complete")
    }
}

@Suite struct ReminderTests {
    func plan(
        _ completed: Set<String> = [], now: Date, last: Date? = nil, settings: UserSettings = Cal.settings
    ) -> [PlannedReminder] {
        Reminders.plan(
            settings: settings, completed: completed, now: now, lastCompletedAt: last, calendar: Cal.calendar)
    }

    @Test func runDaysPlusOneNudge() {
        let reminders = plan(now: Cal.date(11, 9, 6))
        #expect(
            reminders.first
                == PlannedReminder(
                    date: Cal.date(11, 9, 7), kind: .runDay,
                    body: "Week 1 · Run 1 today — 30 min. You've got this."))
        #expect(reminders.filter { $0.kind == .nudge }.map(\.date) == [Cal.date(11, 10, 7)])
        #expect(reminders.filter { $0.kind == .runDay }.count == 6)
    }

    @Test func neverMoreThanOneADayAndNoneOnPlainRestDays() {
        let reminders = plan(now: Cal.date(11, 9, 6))
        let days = reminders.map { Cal.calendar.startOfDay(for: $0.date) }
        #expect(Set(days).count == days.count)
        for reminder in reminders where reminder.kind == .runDay {
            #expect(Cal.settings.runDays.contains(Cal.calendar.component(.weekday, from: reminder.date)))
        }
    }

    @Test func afterRunningTodayNudgeMovesToTheNextRunDay() {
        let reminders = plan(["w1r1"], now: Cal.date(11, 9, 8), last: Cal.date(11, 9, 7, 30))
        #expect(reminders.first?.date == Cal.date(11, 11, 7))
        #expect(reminders.first?.body.hasPrefix("Week 1 · Run 2 today") == true)
        #expect(reminders.first { $0.kind == .nudge }?.date == Cal.date(11, 12, 7))
    }

    @Test func offOrFinishedMeansNothing() {
        var off = Cal.settings
        off.remindersOn = false
        #expect(plan(now: Cal.date(11, 9, 6), settings: off).isEmpty)
        #expect(plan(Cal.ids(through: "w9r3"), now: Cal.date(11, 9, 6)).isEmpty)
    }

    @Test func runDayInsideTheRestWindowIsSkipped() {
        // Ran anyway on Sunday night: Monday 7am is a rest day, so no reminder and no nudge for it.
        let reminders = plan(["w1r1"], now: Cal.date(11, 8, 21), last: Cal.date(11, 8, 20))
        #expect(reminders.first?.date == Cal.date(11, 11, 7))
        #expect(reminders.first { $0.kind == .nudge }?.date == Cal.date(11, 12, 7))
    }
}
