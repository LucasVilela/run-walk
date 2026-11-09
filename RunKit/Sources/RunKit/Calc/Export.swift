import Foundation

/// Data export for the share sheet: everything as JSON, and runs as CSV.
public enum Export {
    public struct Snapshot: Codable, Equatable, Sendable {
        public var exportedAt: Date
        public var settings: UserSettings?
        public var completedWorkouts: [String]
        public var badges: [String: Date]
        public var runs: [RunRecord]
    }

    public static func json(
        settings: UserSettings?, completed: Set<String>, badges: [Badge: Date], runs: [RunRecord], now: Date
    ) throws -> Data {
        let snapshot = Snapshot(
            exportedAt: now, settings: settings,
            completedWorkouts: Program.workouts.map(\.id).filter(completed.contains),
            badges: Dictionary(uniqueKeysWithValues: badges.map { ($0.key.rawValue, $0.value) }),
            runs: runs.sorted { $0.startedAt < $1.startedAt })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    static let csvHeader = [
        "id", "workout", "started_at", "ended_at", "moving_sec", "running_sec", "distance_m",
        "avg_pace_sec_per_km", "completion_pct", "counted", "feeling", "pain", "mode", "notes",
    ]

    /// One row per run, oldest first. RFC 4180 quoting; dates in ISO 8601.
    public static func csv(runs: [RunRecord]) -> String {
        let dates = ISO8601DateFormatter()
        var lines = [csvHeader.joined(separator: ",")]
        for run in runs.sorted(by: { $0.startedAt < $1.startedAt }) {
            let fields: [String] = [
                run.id, run.workoutId, dates.string(from: run.startedAt), dates.string(from: run.endedAt),
                "\(run.movingSec)", "\(run.runningSec)",
                run.distanceM.map { String(format: "%.1f", $0) } ?? "",
                run.avgPaceSecPerKm.map { String(format: "%.1f", $0) } ?? "",
                String(format: "%.1f", run.completionPct), run.counted ? "1" : "0",
                run.feeling?.rawValue ?? "",
                run.pain ? "1" : "0", run.mode.rawValue, run.notes,
            ]
            lines.append(fields.map(quote).joined(separator: ","))
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    static func quote(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
