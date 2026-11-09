import Foundation
import RunKit
import Testing

@testable import RunWalk

/// Runs outside the plan: timed in the app or logged by hand. They never move the plan.
@MainActor
@Suite struct OtherRunAppTests {
    let base = AppModelTests()

    @Test func loggedRunShowsInHistoryButLeavesThePlan() throws {
        let (_, app) = try base.onboarded(at: base.date(12))
        let before = (app.today, app.forecast.map(\.date))
        app.logRun(.other(startedAt: base.date(10, 7), durationSec: 1800, distanceM: 5000, feeling: .right))
        #expect(app.runs.count == 1)
        #expect(app.runs.first?.isOther == true)
        #expect(app.runsDone == 0)
        #expect(app.stats.otherRuns == 1)
        #expect(app.today == before.0)
        #expect(app.forecast.map(\.date) == before.1)
        #expect(!app.isResting)
        #expect(app.flow == nil)
        let day = app.days.first { $0.date == base.calendar.startOfDay(for: base.date(10)) }
        #expect(day?.kind == .ran(app.runs))
    }

    @Test func timedRunSavesAndShowsTheSummary() throws {
        let (_, app) = try base.onboarded(at: base.date(9))
        app.startFreeRun()
        guard case .freeRun = app.flow else {
            Issue.record("expected the free run")
            return
        }
        app.freeRunFinished(FreeRun(startedAt: base.date(9, 7)).record(endedAt: base.date(9, 8)))
        guard case .summary(let summary) = app.flow else {
            Issue.record("expected the summary")
            return
        }
        #expect(summary.run.isOther)
        #expect(summary.run.movingSec == 3600)
        #expect(summary.newBadges.isEmpty)
        app.saveCheckIn(
            runId: summary.run.id, feeling: .easy, pain: false, notes: "", countAnyway: true, distanceM: 8000)
        #expect(app.flow == nil)
        #expect(app.runs.first?.counted == false)
        #expect(app.runs.first?.distanceM == 8000)
        #expect(app.runsDone == 0)
    }

    @Test func noOtherRunWhileARunIsOpen() throws {
        let (_, app) = try base.onboarded(at: base.date(9))
        app.start(Program.workouts[0])
        app.startFreeRun()
        guard case .run = app.flow else {
            Issue.record("the plan run should stay")
            return
        }
    }

    @Test func otherRunStillGoingWhenTheAppClosedCarriesOn() throws {
        let (store, _) = try base.onboarded(at: base.date(9, 7))
        try store.saveActiveFree(FreeRun(startedAt: base.date(9, 7)), at: base.date(9, 7))
        let reopened = base.model(store, at: base.date(9, 8))
        #expect(reopened.resumeOffer == nil)
        guard case .freeRun(let session) = reopened.flow else {
            Issue.record("expected the free run to carry on")
            return
        }
        #expect(session.run.startedAt == base.date(9, 7))
        reopened.discardFreeRun()
        #expect(reopened.flow == nil)
        #expect(try store.activeFreeRun(now: base.date(9, 8)) == nil)
    }
}
