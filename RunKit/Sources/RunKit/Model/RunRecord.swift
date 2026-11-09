import Foundation

public enum Feeling: String, Codable, Sendable, CaseIterable {
    case easy, right, hard
}

/// How a run was recorded. Every run is time-only now; `gps` remains only so older rows still load.
public enum RunMode: String, Codable, Sendable {
    case gps, treadmill
}

/// One saved run (a row in `runs`). `completionPct` is 0…100 of the main block.
public struct RunRecord: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var workoutId: String
    public var startedAt: Date
    public var endedAt: Date
    public var movingSec: Int
    public var runningSec: Int
    public var distanceM: Double?
    public var avgPaceSecPerKm: Double?
    public var completionPct: Double
    public var counted: Bool
    public var feeling: Feeling?
    public var pain: Bool
    public var notes: String
    public var mode: RunMode

    public init(
        id: String, workoutId: String, startedAt: Date, endedAt: Date, movingSec: Int, runningSec: Int,
        distanceM: Double? = nil, avgPaceSecPerKm: Double? = nil, completionPct: Double = 100,
        counted: Bool = true, feeling: Feeling? = nil, pain: Bool = false, notes: String = "",
        mode: RunMode = .gps
    ) {
        self.id = id
        self.workoutId = workoutId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.movingSec = movingSec
        self.runningSec = runningSec
        self.distanceM = distanceM
        self.avgPaceSecPerKm = avgPaceSecPerKm
        self.completionPct = completionPct
        self.counted = counted
        self.feeling = feeling
        self.pain = pain
        self.notes = notes
        self.mode = mode
    }

    public var workout: Workout? { Program.workout(id: workoutId) }

    /// "Count it anyway" is offered for plan runs under 80% that got into the main block at all.
    public var canCountAnyway: Bool { !isOther && !counted && completionPct >= 1 }

    // MARK: - Other runs

    /// The `workoutId` of a run outside the plan (timed in the app or logged by hand).
    public static let otherWorkoutId = "other"

    /// A run outside the 9-week plan. It shows in your history and totals but never moves the plan.
    public var isOther: Bool { workoutId == Self.otherWorkoutId }

    public var title: String { workout?.title ?? (isOther ? "Other run" : "Run") }

    /// An other run: all of its time counts as running. Never counted towards the plan.
    public static func other(
        id: String = UUID().uuidString, startedAt: Date, durationSec: Int, distanceM: Double? = nil,
        feeling: Feeling? = nil, pain: Bool = false, notes: String = ""
    ) -> RunRecord {
        let seconds = max(0, durationSec)
        return RunRecord(
            id: id, workoutId: otherWorkoutId, startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(TimeInterval(seconds)), movingSec: seconds,
            runningSec: seconds,
            distanceM: distanceM,
            avgPaceSecPerKm: distanceM.flatMap {
                Pace.secondsPerKm(movingSec: Double(seconds), distanceM: $0)
            },
            completionPct: 0, counted: false, feeling: feeling, pain: pain, notes: notes, mode: .treadmill)
    }
}
