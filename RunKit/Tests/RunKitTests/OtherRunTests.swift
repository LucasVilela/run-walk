import Foundation
import Testing

@testable import RunKit

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
private func t(_ seconds: Double) -> Date { t0.addingTimeInterval(seconds) }

@Suite struct FreeRunTests {
    @Test func elapsedIsWallClockMinusPauses() {
        var run = FreeRun(startedAt: t0)
        #expect(run.elapsed(at: t(600)) == 600)
        run.pause(at: t(600))
        #expect(run.isPaused)
        #expect(run.elapsed(at: t(900)) == 600)
        run.pause(at: t(950))  // a second pause changes nothing
        run.resume(at: t(1000))
        #expect(!run.isPaused)
        #expect(run.elapsed(at: t(1300)) == 900)
        run.resume(at: t(1400))  // resume while running changes nothing
        #expect(run.elapsed(at: t(1400)) == 1000)
    }

    @Test func neverNegative() {
        #expect(FreeRun(startedAt: t0).elapsed(at: t(-50)) == 0)
    }

    @Test func markerEveryFiveMinutesOnlyTheLatest() {
        #expect(FreeRun.marker(from: 290, to: 299) == nil)
        #expect(FreeRun.marker(from: 299.8, to: 300.1) == 5)
        #expect(FreeRun.marker(from: 300.1, to: 300.4) == nil)
        #expect(FreeRun.marker(from: 899, to: 900) == 15)
        // Back from a locked phone 12 minutes later: one announcement, for the latest mark.
        #expect(FreeRun.marker(from: 100, to: 820) == 10)
        #expect(FreeRun.marker(from: 0, to: 0.3) == nil)
    }

    @Test func restoreKeepsRunningUnlessForgotten() {
        var run = FreeRun(startedAt: t0)
        run.restore(savedAt: t(600), now: t(2400))
        #expect(!run.isPaused)
        #expect(run.elapsed(at: t(2400)) == 2400)

        var forgotten = FreeRun(startedAt: t0)
        forgotten.restore(savedAt: t(600), now: t(600 + FreeRun.forgottenAfter + 1))
        #expect(forgotten.isPaused)
        #expect(forgotten.elapsed(at: t(99_999)) == 600)

        var paused = FreeRun(startedAt: t0)
        paused.pause(at: t(300))
        paused.restore(savedAt: t(310), now: t(99_999))
        #expect(paused.elapsed(at: t(99_999)) == 300)
    }

    @Test func timeChecksReadNaturally() {
        #expect(CueLines.freeRunTime(minutes: 5) == "five minutes")
        #expect(CueLines.freeRunTime(minutes: 60) == "one hour")
        #expect(CueLines.freeRunTime(minutes: 75) == "one hour 15 minutes")
        #expect(CueLines.freeRunTime(minutes: 120) == "two hours")
    }

    @Test func recordIsAnOtherRun() {
        var run = FreeRun(startedAt: t0)
        run.pause(at: t(100))
        run.resume(at: t(160))
        let record = run.record(id: "x", endedAt: t(1260.4))
        #expect(record.isOther)
        #expect(record.movingSec == 1200)
        #expect(record.runningSec == 1200)
        #expect(!record.counted)
        #expect(!record.canCountAnyway)
        #expect(record.title == "Other run")
    }
}

@Suite struct OtherRunRecordTests {
    @Test func loggedRunHasPace() {
        let run = RunRecord.other(startedAt: t0, durationSec: 1800, distanceM: 5000, feeling: .right)
        #expect(run.endedAt == t(1800))
        #expect(run.avgPaceSecPerKm == 360)
        #expect(run.workout == nil)
        #expect(run.feeling == .right)
    }

    @Test func planRunsKeepTheirTitle() {
        let run = RunRecord(
            id: "a", workoutId: Program.workouts[0].id, startedAt: t0, endedAt: t(60), movingSec: 60,
            runningSec: 0, completionPct: 50, counted: false)
        #expect(!run.isOther)
        #expect(run.title == Program.workouts[0].title)
        #expect(run.canCountAnyway)
    }

    @Test func statsIncludeOtherRunsInTotalsOnly() {
        let other = RunRecord.other(startedAt: t0, durationSec: 1200, distanceM: 3000)
        let stats = Stats.compute(runs: [other], completed: [])
        #expect(stats.runsDone == 0)
        #expect(stats.otherRuns == 1)
        #expect(stats.totalRunningSec == 1200)
        #expect(stats.totalDistanceM == 3000)
        #expect(stats.longestNonStopSec == 0)
        #expect(Stats.runningSecondsPerWeek(runs: [other]).allSatisfy { $0 == 0 })
    }

    @Test func coachIgnoresHowOtherRunsFelt() {
        let now = Cal.date(11, 20)
        let first = Program.workouts[0].id
        let runs = [
            Cal.run("p1", first, ended: Cal.date(11, 12), feeling: .hard),
            RunRecord.other(id: "o1", startedAt: Cal.date(11, 18), durationSec: 600, feeling: .hard),
            RunRecord.other(id: "o2", startedAt: Cal.date(11, 19), durationSec: 600, feeling: .hard),
        ]
        let context = CoachContext(
            now: now, calendar: Cal.calendar, runs: runs, completed: [first], nextDate: nil)
        #expect(!Coach.candidates(context).contains { $0.rule == .hardRepeat })
    }

    @Test func coachStillCaresAboutPainOnOtherRuns() {
        let now = Cal.date(11, 20)
        let runs = [RunRecord.other(id: "o1", startedAt: Cal.date(11, 19), durationSec: 600, pain: true)]
        let context = CoachContext(now: now, calendar: Cal.calendar, runs: runs, completed: [], nextDate: nil)
        #expect(Coach.suggestion(context)?.rule == .pain)
    }

    @Test func dayByDayShowsOtherRuns() {
        let run = RunRecord.other(id: "o1", startedAt: Cal.date(11, 10), durationSec: 900)
        let days = DayByDay.days(
            settings: Cal.settings, runs: [run], completed: [], now: Cal.date(11, 12), lastCompletedAt: nil,
            calendar: Cal.calendar)
        #expect(days.first { $0.date == Cal.day(11, 10) }?.kind == .ran([run]))
    }
}

@Suite struct OtherRunStoreTests {
    private func store() throws -> RunStore { try RunStore(db: .inMemory()) }

    @Test func savingNeverMovesThePlan() throws {
        let store = try store()
        try store.saveOther(.other(id: "o1", startedAt: t0, durationSec: 1800, distanceM: 4000))
        #expect(try store.runs().map(\.id) == ["o1"])
        #expect(try store.runs().first?.isOther == true)
        #expect(try store.completed().isEmpty)
        #expect(try store.badges().isEmpty)
        #expect(try store.lastCompletedAt() == nil)
    }

    @Test func checkInAndDeleteWork() throws {
        let store = try store()
        try store.saveOther(.other(id: "o1", startedAt: t0, durationSec: 1500))
        try store.updateCheckIn(runId: "o1", feeling: .easy, pain: false, notes: "Park loop", distanceM: 5000)
        let run = try #require(try store.run(id: "o1"))
        #expect(run.notes == "Park loop")
        #expect(run.avgPaceSecPerKm == 300)
        #expect(try store.countAnyway(runId: "o1").isEmpty)
        #expect(try store.run(id: "o1")?.counted == false)
        try store.deleteRun(id: "o1")
        #expect(try store.runs().isEmpty)
        #expect(try store.completed().isEmpty)
    }

    @Test func activeFreeRunRoundTrips() throws {
        let store = try store()
        var run = FreeRun(startedAt: t0)
        run.pause(at: t(120))
        try store.saveActiveFree(run, at: t(130))
        // The plan-run resume offer neither sees it nor wipes it.
        #expect(try store.activeRun() == nil)
        #expect(try store.activeFreeRun(now: t(500)) == run)
        // Logging some other run by hand leaves it alone; saving the finished one clears it.
        try store.saveOther(.other(id: "o0", startedAt: t(-9000), durationSec: 600))
        #expect(try store.activeFreeRun(now: t(500)) == run)
        try store.saveOther(run.record(id: "o1", endedAt: t(500)), finishingActive: true)
        #expect(try store.activeFreeRun(now: t(500)) == nil)
    }

    @Test func planRunStateIsNotAFreeRun() throws {
        let store = try store()
        var engine = RunEngine(plan: RunPlan(workout: Program.workouts[0], warmupSec: 300, cooldownSec: 300))
        _ = engine.start(at: t0)
        try store.saveActive(ActiveRun(engine: engine, mode: .treadmill), at: t(10))
        #expect(try store.activeFreeRun(now: t(20)) == nil)
        #expect(try store.activeRun() != nil)
    }
}
