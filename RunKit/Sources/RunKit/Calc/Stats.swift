import Foundation

/// Totals for the Progress tab.
public struct Stats: Equatable, Sendable {
    public var runsDone: Int
    public var totalDistanceM: Double
    public var totalRunningSec: Int
    /// Longest single run segment in any counted run.
    public var longestNonStopSec: Int
    /// Best average pace over runs of 2 km or more.
    public var bestAvgPaceSecPerKm: Double?

    public static let bestPaceMinDistanceM = 2000.0

    /// - Parameters:
    ///   - runs: every saved run.
    ///   - completed: workout ids marked done (the "x of 27" number).
    public static func compute(runs: [RunRecord], completed: Set<String>) -> Stats {
        let programIds = Set(Program.workouts.map(\.id))
        let longest =
            runs
            .filter(\.counted)
            .compactMap { $0.workout?.longestRunSeconds }
            .max() ?? 0
        let bestPace =
            runs
            .filter { ($0.distanceM ?? 0) >= bestPaceMinDistanceM }
            .compactMap(\.avgPaceSecPerKm)
            .min()
        return Stats(
            // Every workout ever completed: repeating a week never lowers this.
            runsDone: Set(runs.filter(\.counted).map(\.workoutId)).union(completed).intersection(programIds)
                .count,
            totalDistanceM: runs.compactMap(\.distanceM).reduce(0, +),
            totalRunningSec: runs.map(\.runningSec).reduce(0, +),
            longestNonStopSec: longest,
            bestAvgPaceSecPerKm: bestPace)
    }

    /// Running seconds per program week (index 0 = week 1), 9 bars for the weekly chart.
    public static func runningSecondsPerWeek(runs: [RunRecord]) -> [Int] {
        var weeks = Array(repeating: 0, count: Program.weeks.count)
        for run in runs {
            guard let week = run.workout?.week else { continue }
            weeks[week - 1] += run.runningSec
        }
        return weeks
    }

}
