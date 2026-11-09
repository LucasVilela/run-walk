import Foundation

/// Versioned schema. Each entry runs once, in order, tracked by `PRAGMA user_version`.
/// Never edit a shipped migration: add a new one. (Ask before schema changes after phase 3.)
public enum Migrations {
    public static let all: [String] = [v1]

    public static func migrate(_ db: Database) throws {
        let current = db.userVersion
        for (index, sql) in all.enumerated() where index >= current {
            try db.transaction {
                try db.execute(sql)
                try db.setUserVersion(index + 1)
            }
        }
    }

    static let v1 = """
        CREATE TABLE settings (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            units TEXT NOT NULL,
            runDays TEXT NOT NULL,
            reminderTime INTEGER NOT NULL,
            remindersOn INTEGER NOT NULL,
            startDate REAL NOT NULL,
            voiceOn INTEGER NOT NULL,
            beepsOn INTEGER NOT NULL,
            hapticsOn INTEGER NOT NULL,
            gpsOn INTEGER NOT NULL,
            warmupSec INTEGER NOT NULL,
            cooldownSec INTEGER NOT NULL,
            onboardedAt REAL
        );
        CREATE TABLE workout_progress (
            workoutId TEXT PRIMARY KEY,
            status TEXT NOT NULL CHECK (status IN ('done', 'not_done')),
            completedAt REAL,
            bestCompletionPct REAL NOT NULL DEFAULT 0
        );
        CREATE TABLE runs (
            id TEXT PRIMARY KEY,
            workoutId TEXT NOT NULL,
            startedAt REAL NOT NULL,
            endedAt REAL NOT NULL,
            movingSec INTEGER NOT NULL,
            runningSec INTEGER NOT NULL,
            distanceM REAL,
            avgPaceSecPerKm REAL,
            completionPct REAL NOT NULL,
            counted INTEGER NOT NULL,
            feeling TEXT CHECK (feeling IN ('easy', 'right', 'hard')),
            pain INTEGER NOT NULL DEFAULT 0,
            notes TEXT NOT NULL DEFAULT '',
            mode TEXT NOT NULL CHECK (mode IN ('gps', 'treadmill'))
        );
        CREATE INDEX runs_endedAt ON runs (endedAt);
        CREATE TABLE route_points (
            runId TEXT NOT NULL REFERENCES runs (id) ON DELETE CASCADE,
            ts REAL NOT NULL,
            lat REAL NOT NULL,
            lng REAL NOT NULL,
            accuracy REAL NOT NULL,
            segmentKind TEXT NOT NULL
        );
        CREATE INDEX route_points_run ON route_points (runId, ts);
        CREATE TABLE splits (
            runId TEXT NOT NULL REFERENCES runs (id) ON DELETE CASCADE,
            idx INTEGER NOT NULL,
            distanceM REAL NOT NULL,
            seconds REAL NOT NULL,
            PRIMARY KEY (runId, idx)
        );
        CREATE TABLE badges (
            id TEXT PRIMARY KEY,
            unlockedAt REAL NOT NULL
        );
        CREATE TABLE coach_dismissals (
            ruleId TEXT NOT NULL,
            contextKey TEXT NOT NULL,
            dismissedAt REAL NOT NULL,
            PRIMARY KEY (ruleId, contextKey)
        );
        CREATE TABLE active_run (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            state TEXT NOT NULL,
            savedAt REAL NOT NULL
        );
        """
}
