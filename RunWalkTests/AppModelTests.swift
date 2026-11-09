import Foundation
import RunKit
import Testing

@testable import RunWalk

/// The core loop end to end, on an in-memory database. 9 Nov 2026 is a Monday.
@MainActor
@Suite struct AppModelTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Australia/Sydney")!
        return c
    }()

    func date(_ day: Int, _ hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    func model(_ store: RunStore, at now: Date) -> AppModel {
        AppModel(store: store, calendar: calendar, clock: { now })
    }

    func onboarded(at now: Date) throws -> (RunStore, AppModel) {
        let store = try RunStore(db: .inMemory())
        let app = model(store, at: now)
        app.finishOnboarding(UserSettings(startDate: calendar.startOfDay(for: now)))
        return (store, app)
    }

    /// A finished engine for the workout, started at `start`, ended after `seconds` (or run to the end).
    func engine(_ id: String, start: Date, endAfter seconds: Double? = nil) -> RunEngine {
        var engine = RunEngine(
            plan: RunPlan(workout: Program.workout(id: id)!, warmupSec: 300, cooldownSec: 300))
        _ = engine.start(at: start)
        if let seconds {
            _ = engine.end(at: start.addingTimeInterval(seconds))
        } else {
            _ = engine.tick(at: start.addingTimeInterval(99_999))
        }
        return engine
    }

    @Test func freshInstallShowsOnboardingThenWeek1Run1() throws {
        let store = try RunStore(db: .inMemory())
        let app = model(store, at: date(9))
        #expect(app.settings == nil)
        app.finishOnboarding(UserSettings(startDate: calendar.startOfDay(for: date(9))))
        #expect(app.settings?.onboardedAt == date(9))
        #expect(app.today == .run(Program.workouts[0]))
        #expect(app.forecast.count == 27)
    }

    @Test func countedRunAdvancesAndShowsSummary() throws {
        let (_, app) = try onboarded(at: date(9, 7))
        app.runFinished(engine("w1r1", start: date(9, 7)), mode: .gps)
        guard case .summary(let summary) = app.flow else {
            Issue.record("expected the summary")
            return
        }
        #expect(summary.run.counted)
        #expect(summary.newBadges == [.firstRun])
        #expect(app.completed == ["w1r1"])
        #expect(app.nextWorkout?.id == "w1r2")

        app.saveCheckIn(
            runId: summary.run.id, feeling: .right, pain: false, notes: "", countAnyway: false, distanceM: nil
        )
        #expect(app.flow == nil)
        #expect(app.runs.first?.feeling == .right)
        // Ran this morning: today is a rest day, next run Wednesday.
        #expect(app.today == .rest(next: Program.workouts[1], nextDate: calendar.startOfDay(for: date(11))))
    }

    @Test func shortRunRetriesByDefaultOrCountsAnyway() throws {
        let (_, app) = try onboarded(at: date(9))
        app.runFinished(engine("w1r1", start: date(9), endAfter: 600), mode: .treadmill)
        guard case .summary(let first) = app.flow else {
            Issue.record("expected the summary")
            return
        }
        #expect(!first.run.counted)
        app.saveCheckIn(
            runId: first.run.id, feeling: nil, pain: false, notes: "", countAnyway: false, distanceM: 1200)
        #expect(app.completed.isEmpty, "retry next time")
        #expect(app.nextWorkout?.id == "w1r1")
        #expect(app.runs.first?.distanceM == 1200)

        app.runFinished(engine("w1r1", start: date(9, 12), endAfter: 600), mode: .treadmill)
        guard case .summary(let second) = app.flow else {
            Issue.record("expected the summary")
            return
        }
        app.saveCheckIn(
            runId: second.run.id, feeling: nil, pain: false, notes: "", countAnyway: true, distanceM: nil)
        #expect(app.completed == ["w1r1"])
        #expect(app.runs.count == 2)
    }

    @Test func killedMidRunOffersResume() throws {
        let (store, _) = try onboarded(at: date(9))
        var running = RunEngine(plan: RunPlan(workout: Program.workouts[0], warmupSec: 300, cooldownSec: 300))
        _ = running.start(at: date(9))
        try store.saveActive(ActiveRun(engine: running, mode: .gps), at: date(9))

        let relaunched = model(store, at: date(9, 10))
        var expected = running
        expected.suspend(at: date(9))
        #expect(relaunched.resumeOffer?.engine == expected, "comes back paused at the last save")
        relaunched.discardResume()
        #expect(relaunched.resumeOffer == nil)
        #expect(model(store, at: date(9, 10)).resumeOffer == nil)
    }

    @Test func repeatWeekGoesBackToRun1() throws {
        let (_, app) = try onboarded(at: date(9))
        for (i, id) in ["w1r1", "w1r2", "w1r3", "w2r1"].enumerated() {
            app.runFinished(engine(id, start: date(9 + i * 2)), mode: .gps)
        }
        #expect(app.currentWeek == 2)
        app.repeatWeek(2)
        #expect(app.nextWorkout?.id == "w2r1")
        #expect(app.completed.count == 3)
    }
}

@MainActor
@Suite struct AppModelPhase5Tests {
    let base = AppModelTests()

    @Test func hardRunsSuggestRepeatingTheWeekAndAcceptingDoesIt() throws {
        let (_, app) = try base.onboarded(at: base.date(9))
        for (i, id) in ["w1r1", "w1r2", "w1r3", "w2r1"].enumerated() {
            app.runFinished(base.engine(id, start: base.date(9 + i * 2)), mode: .gps)
            guard case .summary(let s) = app.flow else {
                Issue.record("no summary")
                return
            }
            app.saveCheckIn(
                runId: s.run.id, feeling: .hard, pain: false, notes: "", countAnyway: false, distanceM: nil)
        }
        let suggestion = try #require(app.suggestion)
        #expect(suggestion.rule == .hardRepeat)
        app.accept(suggestion)
        #expect(app.nextWorkout?.id == "w2r1")
        #expect(app.suggestion == nil, "dismissed once acted on")
        #expect(app.runsDone == 4, "repeating a week keeps the count")
    }

    @Test func dismissedSuggestionStaysDismissed() throws {
        let (store, app) = try base.onboarded(at: base.date(9))
        app.runFinished(base.engine("w1r1", start: base.date(1)), mode: .gps)
        let relaunched = base.model(store, at: base.date(12))
        let suggestion = try #require(relaunched.suggestion)
        #expect(suggestion.rule == .gapRedo)
        relaunched.dismiss(suggestion)
        #expect(base.model(store, at: base.date(12)).suggestion == nil)
    }

    @Test func settingsDeleteStartOverAndExport() throws {
        let (_, app) = try base.onboarded(at: base.date(9))
        var settings = try #require(app.settings)
        settings.units = .mi
        settings.warmupSec = 240
        app.update(settings)
        #expect(app.settings?.units == .mi)
        #expect(app.totalSeconds(Program.workouts[0]) == 240 + 1200 + 300)

        app.runFinished(base.engine("w1r1", start: base.date(9)), mode: .gps)
        let run = try #require(app.runs.first)
        app.updateRun(run, feeling: .easy, pain: false, notes: "Lovely")
        #expect(app.runs.first?.notes == "Lovely")

        let files = try #require(app.exportFiles())
        #expect(try JSONSerialization.jsonObject(with: Data(contentsOf: files.json)) is [String: Any])
        #expect(try String(contentsOf: files.csv, encoding: .utf8).components(separatedBy: "\r\n").count == 3)

        app.deleteRun(run)
        #expect(app.runs.isEmpty)
        #expect(app.nextWorkout?.id == "w1r1")

        app.runFinished(base.engine("w1r1", start: base.date(9)), mode: .gps)
        app.startOver()
        #expect(app.runs.isEmpty && app.completed.isEmpty && app.badges.isEmpty)
        #expect(app.settings?.units == .mi, "settings stay")
    }
}

@MainActor
@Suite struct RestartResetTests {
    let base = AppModelTests()

    @Test func restartFromAnEarlierWeekKeepsHistory() throws {
        let (_, app) = try base.onboarded(at: base.date(9))
        for (i, id) in ["w1r1", "w1r2", "w1r3", "w2r1", "w2r2"].enumerated() {
            app.runFinished(base.engine(id, start: base.date(9 + i)), mode: .treadmill)
        }
        #expect(app.restartableWeeks == [1, 2])
        app.repeatWeek(1)
        #expect(app.nextWorkout?.id == "w1r1")
        #expect(app.runs.count == 5, "history stays")
        #expect(app.badges[.week1] != nil, "badges stay")
        #expect(app.runsDone == 5)
    }

    @Test func eraseEverythingGoesBackToOnboarding() throws {
        let (store, app) = try base.onboarded(at: base.date(9))
        app.runFinished(base.engine("w1r1", start: base.date(9)), mode: .treadmill)
        Theme.apply(.bold)
        app.eraseEverything()
        #expect(app.settings == nil)
        #expect(app.runs.isEmpty)
        #expect(Theme.look == .calm)
        #expect(base.model(store, at: base.date(10)).settings == nil, "stays erased after relaunch")
    }
}
