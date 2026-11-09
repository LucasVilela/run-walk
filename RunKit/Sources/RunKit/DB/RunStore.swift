import Foundation

/// The in-progress run saved every 10 s, so a crash can offer "Resume your run?".
public struct ActiveRun: Codable, Equatable, Sendable {
    public var engine: RunEngine
    public var mode: RunMode

    public init(engine: RunEngine, mode: RunMode) {
        self.engine = engine
        self.mode = mode
    }
}

/// Typed access to every table. All plan changes go through here.
public final class RunStore {
    public let db: Database

    public init(db: Database) throws {
        self.db = db
        try Migrations.migrate(db)
    }

    public static func open(at url: URL) throws -> RunStore {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        return try RunStore(db: Database(path: url.path))
    }

    // MARK: - Settings

    public func settings() throws -> UserSettings? {
        guard let row = try db.query("SELECT * FROM settings WHERE id = 1").first else { return nil }
        var s = UserSettings(startDate: row.date("startDate") ?? Date())
        s.units = DistanceUnit(rawValue: row.text("units") ?? "") ?? .km
        s.runDays = Set((row.text("runDays") ?? "").split(separator: ",").compactMap { Int($0) })
        s.reminderMinutes = row.int("reminderTime")
        s.remindersOn = row.bool("remindersOn")
        s.voiceOn = row.bool("voiceOn")
        s.beepsOn = row.bool("beepsOn")
        s.hapticsOn = row.bool("hapticsOn")
        s.warmupSec = row.int("warmupSec")
        s.cooldownSec = row.int("cooldownSec")
        s.onboardedAt = row.date("onboardedAt")
        return s.sanitized()
    }

    public func save(_ settings: UserSettings) throws {
        let s = settings.sanitized()
        try db.run(
            """
            INSERT OR REPLACE INTO settings (id, units, runDays, reminderTime, remindersOn, startDate, voiceOn,
                beepsOn, hapticsOn, gpsOn, warmupSec, cooldownSec, onboardedAt)
            VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                SQLValue(s.units.rawValue),
                SQLValue(s.runDays.sorted().map(String.init).joined(separator: ",")),
                SQLValue(s.reminderMinutes), SQLValue(s.remindersOn), SQLValue(s.startDate),
                SQLValue(s.voiceOn),
                SQLValue(s.beepsOn), SQLValue(s.hapticsOn), SQLValue(false), SQLValue(s.warmupSec),
                SQLValue(s.cooldownSec), SQLValue(s.onboardedAt),
            ])
    }

    // MARK: - Plan progress

    public func completed() throws -> Set<String> {
        Set(
            try db.query("SELECT workoutId FROM workout_progress WHERE status = 'done'").compactMap {
                $0.text("workoutId")
            })
    }

    func markDone(_ workoutId: String, at date: Date, pct: Double) throws {
        try db.run(
            """
            INSERT INTO workout_progress (workoutId, status, completedAt, bestCompletionPct) VALUES (?, 'done', ?, ?)
            ON CONFLICT (workoutId) DO UPDATE SET status = 'done', completedAt = excluded.completedAt,
                bestCompletionPct = max(bestCompletionPct, excluded.bestCompletionPct)
            """, [SQLValue(workoutId), SQLValue(date), SQLValue(pct)])
    }

    func markNotDone(_ ids: some Sequence<String>) throws {
        for id in ids {
            try db.run("UPDATE workout_progress SET status = 'not_done' WHERE workoutId = ?", [SQLValue(id)])
        }
    }

    /// "Repeat this week" or "go back a week": everything from `week` on is to do again.
    public func restart(fromWeek week: Int) throws {
        let done = try completed()
        try db.transaction {
            try markNotDone(done.subtracting(Scheduler.restart(fromWeek: week, completed: done)))
        }
    }

    /// "Redo your last run first".
    public func redo(_ workoutId: String) throws {
        try markNotDone([workoutId])
    }

    // MARK: - Runs

    /// Newest first.
    public func runs() throws -> [RunRecord] {
        try db.query("SELECT * FROM runs ORDER BY endedAt DESC").map(Self.record)
    }

    public func run(id: String) throws -> RunRecord? {
        try db.query("SELECT * FROM runs WHERE id = ?", [SQLValue(id)]).first.map(Self.record)
    }

    func insert(_ run: RunRecord) throws {
        try db.run(
            """
            INSERT INTO runs (id, workoutId, startedAt, endedAt, movingSec, runningSec, distanceM, avgPaceSecPerKm,
                completionPct, counted, feeling, pain, notes, mode)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                SQLValue(run.id), SQLValue(run.workoutId), SQLValue(run.startedAt), SQLValue(run.endedAt),
                SQLValue(run.movingSec), SQLValue(run.runningSec), SQLValue(run.distanceM),
                SQLValue(run.avgPaceSecPerKm), SQLValue(run.completionPct), SQLValue(run.counted),
                SQLValue(run.feeling?.rawValue), SQLValue(run.pain), SQLValue(run.notes),
                SQLValue(run.mode.rawValue),
            ])
    }

    /// Saves a finished run in one transaction: the run, plan progress if it counts, new badges,
    /// and clears the crash-resume state. Returns the badges earned by this run.
    @discardableResult
    public func saveFinished(_ run: RunRecord) throws -> [Badge] {
        try db.transaction {
            try insert(run)
            try clearActive()
            guard run.counted else { return [] }
            try markDone(run.workoutId, at: run.endedAt, pct: run.completionPct)
            return try unlockEarnedBadges(at: run.endedAt)
        }
    }

    /// "Count it anyway" for a run under 80%. A run that never reached the main block has nothing to count.
    @discardableResult
    public func countAnyway(runId: String) throws -> [Badge] {
        guard let run = try run(id: runId), run.canCountAnyway else { return [] }
        return try db.transaction {
            try db.run("UPDATE runs SET counted = 1 WHERE id = ?", [SQLValue(runId)])
            try markDone(run.workoutId, at: run.endedAt, pct: run.completionPct)
            return try unlockEarnedBadges(at: run.endedAt)
        }
    }

    /// The check-in after a run, and a manual treadmill distance.
    public func updateCheckIn(runId: String, feeling: Feeling?, pain: Bool, notes: String, distanceM: Double?)
        throws
    {
        guard let run = try run(id: runId) else { return }
        let distance = distanceM ?? run.distanceM
        let pace = distance.flatMap { Pace.secondsPerKm(movingSec: Double(run.movingSec), distanceM: $0) }
        try db.run(
            "UPDATE runs SET feeling = ?, pain = ?, notes = ?, distanceM = ?, avgPaceSecPerKm = ? WHERE id = ?",
            [
                SQLValue(feeling?.rawValue), SQLValue(pain), SQLValue(notes), SQLValue(distance),
                SQLValue(pace),
                SQLValue(runId),
            ])
    }

    /// Deletes a run (its route and splits go with it). If no other counted run of that workout is
    /// left, the workout goes back to "to do". Badges are kept.
    public func deleteRun(id: String) throws {
        guard let run = try run(id: id) else { return }
        try db.transaction {
            try db.run("DELETE FROM runs WHERE id = ?", [SQLValue(id)])
            let others = try db.query(
                "SELECT count(*) AS n FROM runs WHERE workoutId = ? AND counted = 1",
                [SQLValue(run.workoutId)])
            if run.counted, others.first?.int("n") == 0 { try markNotDone([run.workoutId]) }
        }
    }

    /// "Erase everything": like a fresh install. Settings go too, so the app shows onboarding again.
    public func eraseEverything() throws {
        try db.transaction {
            try clearProgress()
            try db.run("DELETE FROM settings")
        }
    }

    /// "Start the plan over": clears runs, routes, progress, badges and coach dismissals.
    /// Settings stay.
    public func startOver() throws {
        try db.transaction { try clearProgress() }
    }

    private func clearProgress() throws {
        for table in [
            "runs", "route_points", "splits", "workout_progress", "badges", "coach_dismissals", "active_run",
        ] {
            try db.run("DELETE FROM \(table)")
        }
    }

    /// End of the last run that counted: the start of the 20-hour rest window.
    public func lastCompletedAt() throws -> Date? {
        try db.query("SELECT max(endedAt) AS last FROM runs WHERE counted = 1").first?.date("last")
    }

    private static func record(_ row: Row) -> RunRecord {
        RunRecord(
            id: row.text("id") ?? "", workoutId: row.text("workoutId") ?? "",
            startedAt: row.date("startedAt") ?? .distantPast, endedAt: row.date("endedAt") ?? .distantPast,
            movingSec: row.int("movingSec"), runningSec: row.int("runningSec"),
            distanceM: row.double("distanceM"),
            avgPaceSecPerKm: row.double("avgPaceSecPerKm"), completionPct: row.double("completionPct") ?? 0,
            counted: row.bool("counted"), feeling: row.text("feeling").flatMap(Feeling.init(rawValue:)),
            pain: row.bool("pain"), notes: row.text("notes") ?? "",
            mode: RunMode(rawValue: row.text("mode") ?? "") ?? .gps)
    }

    // MARK: - Badges

    public func badges() throws -> [Badge: Date] {
        var result: [Badge: Date] = [:]
        for row in try db.query("SELECT * FROM badges") {
            if let badge = row.text("id").flatMap(Badge.init(rawValue:)), let date = row.date("unlockedAt") {
                result[badge] = date
            }
        }
        return result
    }

    private func unlockEarnedBadges(at date: Date) throws -> [Badge] {
        let fresh = Badge.newlyEarned(completed: try completed(), alreadyUnlocked: Set(try badges().keys))
        for badge in fresh {
            try db.run(
                "INSERT OR IGNORE INTO badges (id, unlockedAt) VALUES (?, ?)",
                [SQLValue(badge.rawValue), SQLValue(date)])
        }
        return fresh
    }

    // MARK: - Coach dismissals

    public func dismissals() throws -> Set<CoachDismissal> {
        Set(
            try db.query("SELECT ruleId, contextKey FROM coach_dismissals").compactMap { row in
                guard let rule = row.text("ruleId").flatMap(CoachRule.init(rawValue:)),
                    let key = row.text("contextKey")
                else { return nil }
                return CoachDismissal(rule: rule, contextKey: key)
            })
    }

    public func dismiss(_ dismissal: CoachDismissal, at date: Date) throws {
        try db.run(
            "INSERT OR REPLACE INTO coach_dismissals (ruleId, contextKey, dismissedAt) VALUES (?, ?, ?)",
            [SQLValue(dismissal.rule.rawValue), SQLValue(dismissal.contextKey), SQLValue(date)])
    }

    // MARK: - Crash-resume

    public func saveActive(_ active: ActiveRun, at date: Date) throws {
        let json = String(decoding: try JSONEncoder().encode(active), as: UTF8.self)
        try db.run(
            "INSERT OR REPLACE INTO active_run (id, state, savedAt) VALUES (1, ?, ?)",
            [SQLValue(json), SQLValue(date)])
    }

    /// The saved in-progress run, if one was still going. Unreadable state is dropped.
    /// A run that was still running comes back paused at the moment it was last saved: nobody knows
    /// what happened while the app was closed, so that time never counts as running.
    public func activeRun() throws -> ActiveRun? {
        guard let row = try db.query("SELECT state, savedAt FROM active_run WHERE id = 1").first,
            let json = row.text("state")
        else { return nil }
        guard var active = try? JSONDecoder().decode(ActiveRun.self, from: Data(json.utf8)),
            active.engine.phase == .running || active.engine.phase == .paused
        else {
            try clearActive()
            return nil
        }
        if let savedAt = row.date("savedAt") { active.engine.suspend(at: savedAt) }
        return active
    }

    public func clearActive() throws {
        try db.run("DELETE FROM active_run")
    }
}

extension RunRecord {
    /// The record for a finished engine. Counts when at least 80% of the main block was done.
    public static func finished(
        _ engine: RunEngine, id: String = UUID().uuidString, mode: RunMode, distanceM: Double? = nil
    ) -> RunRecord? {
        guard let startedAt = engine.startedAt, let endedAt = engine.endedAt else { return nil }
        let moving = engine.movingSec(at: endedAt)
        return RunRecord(
            id: id, workoutId: engine.plan.workoutId, startedAt: startedAt, endedAt: endedAt,
            movingSec: Int(moving.rounded()), runningSec: Int(engine.runningSec(at: endedAt).rounded()),
            distanceM: distanceM,
            avgPaceSecPerKm: distanceM.flatMap { Pace.secondsPerKm(movingSec: moving, distanceM: $0) },
            completionPct: engine.completionPct(at: endedAt), counted: engine.isCounted(at: endedAt),
            mode: mode)
    }
}
