import Foundation
import Testing

@testable import RunKit

@Suite struct FormatTests {
    @Test func clock() {
        #expect(Format.clock(90) == "1:30")
        #expect(Format.clock(0) == "0:00")
        #expect(Format.clock(-5) == "0:00")
        #expect(Format.clock(25 * 60) == "25:00")
        #expect(Format.clock(3725) == "1:02:05")
    }

    @Test func parseClock() {
        #expect(Format.parseClock("34:20") == 34 * 60 + 20)
        #expect(Format.parseClock("34") == 34 * 60)
        #expect(Format.parseClock("1:02:05") == 3725)
        #expect(Format.parseClock("5:75") == nil)
        #expect(Format.parseClock("abc") == nil)
        #expect(Format.parseClock("-1:00") == nil)
        #expect(Format.parseClock("") == nil)
    }

    @Test func paceAndDistance() {
        #expect(Format.pace(secondsPerKm: 365, unit: .km) == "6:05 /km")
        #expect(Format.pace(secondsPerKm: 365, unit: .mi) == "9:47 /mi")
        #expect(Format.pace(secondsPerKm: nil, unit: .km) == "—")
        #expect(Format.distance(meters: 2450, unit: .km) == "2.45 km")
        #expect(Format.distance(meters: 1609.344, unit: .mi) == "1.00 mi")
        #expect(Format.distance(meters: nil, unit: .km) == "—")
        #expect(Format.minutes(28 * 60 + 20) == "28 min")
        #expect(Format.estimate(34 * 60 + 10) == "about 34 min")
    }
}

@Suite struct PaceTests {
    @Test func paceIsMovingTimeOverDistance() {
        #expect(Pace.secondsPerKm(movingSec: 1800, distanceM: 5000) == 360)
        #expect(Pace.secondsPerKm(movingSec: 60, distanceM: 99) == nil, "— until 100 m")
        #expect(Pace.secondsPerKm(movingSec: 0, distanceM: 500) == nil)
        // Regression (QA P2): "4:44:10 /km" from bad data. Slower than 30 min/km shows "—".
        #expect(Pace.secondsPerKm(movingSec: 1800, distanceM: 1000) == 1800)
        #expect(Pace.secondsPerKm(movingSec: 1801, distanceM: 1000) == nil)
    }

    @Test func calculatorSolvesEachField() throws {
        let pace = try PaceCalculator.solve(distanceM: 5000, timeSec: 1800, paceSecPerKm: nil)
        #expect(pace.paceSecPerKm == 360)
        let time = try PaceCalculator.solve(distanceM: 5000, timeSec: nil, paceSecPerKm: 360)
        #expect(time.timeSec == 1800)
        let distance = try PaceCalculator.solve(distanceM: nil, timeSec: 1800, paceSecPerKm: 360)
        #expect(distance.distanceM == 5000)
    }

    @Test func calculatorValidatesInput() {
        #expect(throws: PaceCalculator.Failure.needExactlyTwo) {
            try PaceCalculator.solve(distanceM: 5000, timeSec: nil, paceSecPerKm: nil)
        }
        #expect(throws: PaceCalculator.Failure.needExactlyTwo) {
            try PaceCalculator.solve(distanceM: 5000, timeSec: 1800, paceSecPerKm: 360)
        }
        #expect(throws: PaceCalculator.Failure.invalid(.distance)) {
            try PaceCalculator.solve(distanceM: -1, timeSec: 1800, paceSecPerKm: nil)
        }
        #expect(throws: PaceCalculator.Failure.invalid(.time)) {
            try PaceCalculator.solve(distanceM: 5000, timeSec: .nan, paceSecPerKm: nil)
        }
        // 5 km in 5 minutes is a 1:00 /km pace: not a human pace.
        #expect(throws: PaceCalculator.Failure.outOfRange(.pace)) {
            try PaceCalculator.solve(distanceM: 5000, timeSec: 300, paceSecPerKm: nil)
        }
    }
}

@Suite struct StatsTests {
    static let day = Date(timeIntervalSince1970: 1_800_000_000)

    static func run(
        _ id: String, _ workoutId: String, running: Int, distance: Double? = nil, pace: Double? = nil,
        counted: Bool = true
    ) -> RunRecord {
        RunRecord(
            id: id, workoutId: workoutId, startedAt: day, endedAt: day, movingSec: running + 600,
            runningSec: running, distanceM: distance, avgPaceSecPerKm: pace, counted: counted)
    }

    @Test func emptyStats() {
        let stats = Stats.compute(runs: [], completed: [])
        #expect(stats == Stats(runsDone: 0, totalDistanceM: 0, totalRunningSec: 0, longestNonStopSec: 0))
        #expect(Stats.runningSecondsPerWeek(runs: []) == Array(repeating: 0, count: 9))
    }

    @Test func totalsLongestAndBestPace() {
        let runs = [
            Self.run("a", "w1r1", running: 480, distance: 1800, pace: 500),
            Self.run("b", "w5r3", running: 1200, distance: 3200, pace: 420),
            Self.run("c", "w6r3", running: 900, distance: 2100, pace: 400, counted: false),
            Self.run("d", "w5r2", running: 960, distance: 1500, pace: 300),
        ]
        let stats = Stats.compute(runs: runs, completed: ["w1r1", "w5r3", "w5r2", "bogus"])
        #expect(stats.runsDone == 3)
        #expect(stats.totalDistanceM == 8600)
        #expect(stats.totalRunningSec == 480 + 1200 + 900 + 960)
        #expect(stats.longestNonStopSec == 1200, "w6r3 wasn't counted")
        #expect(stats.bestAvgPaceSecPerKm == 400, "only runs of 2 km or more; d is too short")
    }

    @Test func runningMinutesPerWeek() {
        let runs = [
            Self.run("a", "w1r1", running: 480), Self.run("b", "w1r2", running: 480),
            Self.run("c", "w9r3", running: 1800),
        ]
        let weeks = Stats.runningSecondsPerWeek(runs: runs)
        #expect(weeks[0] == 960)
        #expect(weeks[8] == 1800)
        #expect(weeks.reduce(0, +) == 2760)
    }

}

@Suite struct DateHelperTests {
    @Test func consecutiveDays() {
        #expect(!DateHelpers.hasConsecutiveDays([2, 4, 7]))
        #expect(DateHelpers.hasConsecutiveDays([2, 3, 6]))
        #expect(DateHelpers.hasConsecutiveDays([1, 4, 7]), "Saturday then Sunday")
        #expect(!DateHelpers.hasConsecutiveDays([]))
    }
}
