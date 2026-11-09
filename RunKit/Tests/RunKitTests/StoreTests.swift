import Foundation
import Testing

@testable import RunKit

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
private func t(_ seconds: Double) -> Date { t0.addingTimeInterval(seconds) }

private func store() throws -> RunStore { try RunStore(db: .inMemory()) }

/// A finished engine for `id`, ended `after` seconds in (or run to the end).
private func finishedEngine(_ id: String, endAfter: Double? = nil) -> RunEngine {
    var engine = RunEngine(plan: RunPlan(workout: Program.workout(id: id)!, warmupSec: 300, cooldownSec: 300))
    _ = engine.start(at: t0)
    if let endAfter {
        _ = engine.tick(at: t(endAfter))
        _ = engine.end(at: t(endAfter))
    } else {
        _ = engine.tick(at: t(99_999))
    }
    return engine
}

@Suite struct StoreTests {
    @Test func migratesOnceAndIsIdempotent() throws {
        let db = try Database.inMemory()
        _ = try RunStore(db: db)
        #expect(db.userVersion == Migrations.all.count)
        _ = try RunStore(db: db)
        #expect(db.userVersion == Migrations.all.count)
        let tables = try db.query("SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name")
            .compactMap {
                $0.text("name")
            }
        #expect(
            tables == [
                "active_run", "badges", "coach_dismissals", "route_points", "runs", "settings", "splits",
                "workout_progress",
            ])
    }

    @Test func settingsRoundTrip() throws {
        let s = try store()
        #expect(try s.settings() == nil, "fresh install → onboarding")
        var settings = UserSettings(startDate: t0)
        settings.units = .mi
        settings.runDays = [1, 3, 5]
        settings.reminderMinutes = 18 * 60 + 30
        settings.voiceOn = false
        settings.warmupSec = 240
        settings.onboardedAt = t(5)
        try s.save(settings)
        #expect(try s.settings() == settings)
    }

    @Test func countedRunAdvancesThePlanAndEarnsBadges() throws {
        let s = try store()
        let run = try #require(RunRecord.finished(finishedEngine("w1r1"), id: "a", mode: .gps))
        #expect(run.counted)
        #expect(run.completionPct == 100)
        #expect(run.movingSec == 1800)
        #expect(run.runningSec == 480)
        let badges = try s.saveFinished(run)
        #expect(badges == [.firstRun])
        #expect(try s.completed() == ["w1r1"])
        #expect(Scheduler.nextWorkout(completed: try s.completed())?.id == "w1r2")
        #expect(try s.lastCompletedAt() == run.endedAt)
        #expect(try s.runs() == [run])
        #expect(try s.badges()[.firstRun] == run.endedAt)
    }

    @Test func under80PercentDoesNotAdvanceUntilCountedAnyway() throws {
        let s = try store()
        // 300 s warm-up + 768 s of a 1200 s main block = 64%.
        let run = try #require(
            RunRecord.finished(finishedEngine("w1r1", endAfter: 1068), id: "a", mode: .treadmill))
        #expect(!run.counted)
        #expect(run.completionPct == 64)
        #expect(try s.saveFinished(run).isEmpty)
        #expect(try s.completed().isEmpty)
        #expect(try s.lastCompletedAt() == nil, "an uncounted run doesn't start a rest day")

        #expect(try s.countAnyway(runId: "a") == [.firstRun])
        #expect(try s.completed() == ["w1r1"])
        #expect(try s.countAnyway(runId: "a").isEmpty, "only once")
    }

    @Test func eightyPercentCounts() throws {
        let run = try #require(
            RunRecord.finished(finishedEngine("w1r1", endAfter: 300 + 960), id: "a", mode: .gps))
        #expect(run.counted)
    }

    @Test func badgesAreNeverTakenAway() throws {
        let s = try store()
        for (i, id) in ["w1r1", "w1r2", "w1r3"].enumerated() {
            try s.saveFinished(try #require(RunRecord.finished(finishedEngine(id), id: "r\(i)", mode: .gps)))
        }
        #expect(Set(try s.badges().keys) == [.firstRun, .week1])
        try s.restart(fromWeek: 1)
        #expect(try s.completed().isEmpty)
        #expect(Set(try s.badges().keys) == [.firstRun, .week1])
    }

    @Test func repeatWeekAndRedo() throws {
        let s = try store()
        let ids = ["w1r1", "w1r2", "w1r3", "w2r1"]
        for (i, id) in ids.enumerated() {
            try s.saveFinished(try #require(RunRecord.finished(finishedEngine(id), id: "r\(i)", mode: .gps)))
        }
        try s.redo("w2r1")
        #expect(Scheduler.nextWorkout(completed: try s.completed())?.id == "w2r1")
        try s.restart(fromWeek: 1)
        #expect(Scheduler.nextWorkout(completed: try s.completed())?.id == "w1r1")
        // Doing w1r1 again marks it done again.
        try s.saveFinished(try #require(RunRecord.finished(finishedEngine("w1r1"), id: "again", mode: .gps)))
        #expect(try s.completed() == ["w1r1"])
        #expect(try s.runs().count == 5, "history keeps every run")
    }

    @Test func checkInAndTreadmillDistance() throws {
        let s = try store()
        let run = try #require(RunRecord.finished(finishedEngine("w1r1"), id: "a", mode: .treadmill))
        try s.saveFinished(run)
        try s.updateCheckIn(runId: "a", feeling: .hard, pain: true, notes: "Windy", distanceM: 3600)
        let saved = try #require(try s.run(id: "a"))
        #expect(saved.feeling == .hard)
        #expect(saved.pain)
        #expect(saved.notes == "Windy")
        #expect(saved.distanceM == 3600)
        #expect(saved.avgPaceSecPerKm == 500, "1800 s over 3.6 km")
    }

    @Test func dismissals() throws {
        let s = try store()
        let d = CoachDismissal(rule: .hardRepeat, contextKey: "run-3")
        try s.dismiss(d, at: t0)
        try s.dismiss(d, at: t(1))
        #expect(try s.dismissals() == [d])
    }

    @Test func crashResumeKeepsOnlyUnfinishedRuns() throws {
        let s = try store()
        var engine = RunEngine(plan: RunPlan(workout: Program.workouts[0], warmupSec: 300, cooldownSec: 300))
        _ = engine.start(at: t0)
        _ = engine.tick(at: t(400))
        let active = ActiveRun(engine: engine, mode: .gps)
        try s.saveActive(active, at: t(400))
        var expected = engine
        expected.suspend(at: t(400))
        #expect(try s.activeRun() == ActiveRun(engine: expected, mode: .gps))

        _ = engine.end(at: t(500))
        try s.saveActive(ActiveRun(engine: engine, mode: .gps), at: t(500))
        #expect(try s.activeRun() == nil, "a finished engine isn't offered for resume")

        try s.db.run("INSERT OR REPLACE INTO active_run (id, state, savedAt) VALUES (1, 'garbage', 0)")
        #expect(try s.activeRun() == nil)
    }

    /// Regression (QA P0): the hours the app was closed were counted as running, so a 40 s run
    /// could resume straight into a "complete", counted workout.
    @Test func resumedRunComesBackPausedAtItsLastSave() throws {
        let s = try store()
        var engine = RunEngine(plan: RunPlan(workout: Program.workouts[0], warmupSec: 300, cooldownSec: 300))
        _ = engine.start(at: t0)
        _ = engine.tick(at: t(40))
        try s.saveActive(ActiveRun(engine: engine, mode: .gps), at: t(40))

        var restored = try #require(try s.activeRun()).engine
        #expect(restored.phase == .paused)
        #expect(restored.movingSec(at: t(7200)) == 40, "two hours later, still 40 s in")
        _ = restored.resume(at: t(7200))
        #expect(restored.movingSec(at: t(7210)) == 50)
        #expect(restored.tick(at: t(7210)).isEmpty, "no cues replayed for the gap")
        #expect(restored.completionPct(at: t(7210)) == 0)
    }

    @Test func nothingToCountAtZeroPercent() throws {
        let s = try store()
        let run = try #require(RunRecord.finished(finishedEngine("w1r1", endAfter: 17), id: "a", mode: .gps))
        #expect(run.completionPct == 0)
        #expect(!run.canCountAnyway)
        try s.saveFinished(run)
        #expect(try s.countAnyway(runId: "a").isEmpty)
        #expect(try s.completed().isEmpty)
        #expect(try s.badges().isEmpty)
    }

    @Test func savingAFinishedRunClearsResumeState() throws {
        let s = try store()
        let engine = finishedEngine("w1r1")
        try s.saveActive(ActiveRun(engine: RunEngine(plan: engine.plan), mode: .gps), at: t0)
        try s.saveFinished(try #require(RunRecord.finished(engine, id: "a", mode: .gps)))
        #expect(try s.db.query("SELECT * FROM active_run").isEmpty)
    }
}

@Suite struct DataManagementTests {
    @Test func deletingTheOnlyCountedRunPutsTheWorkoutBack() throws {
        let s = try store()
        try s.saveFinished(try #require(RunRecord.finished(finishedEngine("w1r1"), id: "a", mode: .gps)))
        try s.saveFinished(try #require(RunRecord.finished(finishedEngine("w1r2"), id: "b", mode: .gps)))
        try s.saveFinished(try #require(RunRecord.finished(finishedEngine("w1r2"), id: "c", mode: .gps)))
        try s.deleteRun(id: "b")
        #expect(try s.completed() == ["w1r1", "w1r2"], "w1r2 still has run c")
        try s.deleteRun(id: "c")
        #expect(try s.completed() == ["w1r1"])
        #expect(try s.runs().map(\.id) == ["a"])
        #expect(try s.badges()[.firstRun] != nil, "badges stay")
    }

    @Test func eraseEverythingIsAFreshInstall() throws {
        let s = try store()
        try s.save(UserSettings(startDate: t0))
        try s.saveFinished(try #require(RunRecord.finished(finishedEngine("w1r1"), id: "a", mode: .gps)))
        try s.eraseEverything()
        #expect(try s.settings() == nil, "onboarding again")
        #expect(try s.runs().isEmpty && s.completed().isEmpty && s.badges().isEmpty)
    }

    @Test func startOverKeepsSettingsOnly() throws {
        let s = try store()
        try s.save(UserSettings(startDate: t0))
        try s.saveFinished(try #require(RunRecord.finished(finishedEngine("w1r1"), id: "a", mode: .gps)))
        try s.dismiss(CoachDismissal(rule: .easyStreak, contextKey: "a"), at: t0)
        try s.startOver()
        #expect(try s.settings() != nil)
        #expect(try s.runs().isEmpty)
        #expect(try s.completed().isEmpty)
        #expect(try s.badges().isEmpty)
        #expect(try s.dismissals().isEmpty)
    }
}

@Suite struct ExportTests {
    let runs = [
        RunRecord(
            id: "b", workoutId: "w1r2", startedAt: Date(timeIntervalSince1970: 1_800_100_000),
            endedAt: Date(timeIntervalSince1970: 1_800_101_800), movingSec: 1800, runningSec: 480,
            distanceM: 3200,
            avgPaceSecPerKm: 562.5, feeling: .hard, pain: true, notes: "Windy, \"tough\"\nbut done",
            mode: .gps),
        RunRecord(
            id: "a", workoutId: "w1r1", startedAt: Date(timeIntervalSince1970: 1_800_000_000),
            endedAt: Date(timeIntervalSince1970: 1_800_001_800), movingSec: 1800, runningSec: 480,
            mode: .treadmill),
    ]

    @Test func jsonIsValidAndRoundTrips() throws {
        let data = try Export.json(
            settings: UserSettings(startDate: t0), completed: ["w1r2", "w1r1"], badges: [.firstRun: t0],
            runs: runs, now: t0)
        #expect(try JSONSerialization.jsonObject(with: data) is [String: Any])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(Export.Snapshot.self, from: data)
        #expect(snapshot.completedWorkouts == ["w1r1", "w1r2"], "in plan order")
        #expect(snapshot.runs.map(\.id) == ["a", "b"], "oldest first")
        #expect(snapshot.badges["firstRun"] == t0)
    }

    @Test func csvHasHeaderRowsAndQuoting() {
        let csv = Export.csv(runs: runs)
        let lines = csv.components(separatedBy: "\r\n")
        #expect(lines[0].hasPrefix("id,workout,started_at"))
        #expect(lines[1].hasPrefix("a,w1r1,"))
        #expect(lines[1].hasSuffix(",treadmill,"))
        #expect(lines[2].contains("3200.0,562.5,100.0,1,hard,1,gps,"))
        #expect(csv.contains("\"Windy, \"\"tough\"\"\nbut done\""))
        #expect(lines.last == "")
        #expect(Export.quote("plain") == "plain")
    }

    @Test func emptyExport() throws {
        #expect(Export.csv(runs: []) == Export.csvHeader.joined(separator: ",") + "\r\n")
        let data = try Export.json(settings: nil, completed: [], badges: [:], runs: [], now: t0)
        #expect(try JSONSerialization.jsonObject(with: data) is [String: Any])
    }

}
