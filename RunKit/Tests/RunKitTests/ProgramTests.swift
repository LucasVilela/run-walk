import Testing

@testable import RunKit

@Suite struct ProgramTests {
    /// (main block total, running seconds) per workout, straight from the brief's table.
    static let expected: [String: (main: Int, running: Int)] = {
        var table: [String: (Int, Int)] = [:]
        for run in 1...3 {
            table["w1r\(run)"] = (20 * 60, 8 * 60)
            table["w2r\(run)"] = (21 * 60, 6 * 90)
            table["w3r\(run)"] = (18 * 60, 2 * (90 + 180))
            table["w4r\(run)"] = (21 * 60 + 30, 16 * 60)
            table["w7r\(run)"] = (25 * 60, 25 * 60)
            table["w8r\(run)"] = (28 * 60, 28 * 60)
            table["w9r\(run)"] = (30 * 60, 30 * 60)
        }
        table["w5r1"] = (21 * 60, 15 * 60)
        table["w5r2"] = (21 * 60, 16 * 60)
        table["w5r3"] = (20 * 60, 20 * 60)
        table["w6r1"] = (24 * 60, 18 * 60)
        table["w6r2"] = (23 * 60, 20 * 60)
        table["w6r3"] = (25 * 60, 25 * 60)
        return table
    }()

    @Test func has27WorkoutsInOrder() {
        #expect(Program.workouts.count == 27)
        let ids = Program.workouts.map(\.id)
        let expectedIds = (1...9).flatMap { week in (1...3).map { "w\(week)r\($0)" } }
        #expect(ids == expectedIds)
        for workout in Program.workouts {
            #expect(workout.id == "w\(workout.week)r\(workout.run)")
        }
    }

    @Test(arguments: Program.workouts)
    func mainBlockAndRunningSecondsMatchTable(workout: Workout) throws {
        let row = try #require(Self.expected[workout.id])
        #expect(workout.mainSeconds == row.main, "\(workout.id) main block")
        #expect(workout.runningSeconds == row.running, "\(workout.id) running seconds")
    }

    @Test func bigJumpAndGraduationFlags() {
        let bigJumps = Program.workouts.filter(\.bigJump).map(\.id)
        #expect(bigJumps == ["w5r3", "w6r3"])
        let graduation = Program.workouts.filter(\.graduation).map(\.id)
        #expect(graduation == ["w9r3"])
    }

    @Test func segmentsAddWarmupAndCooldownFromSettings() {
        let workout = Program.workouts[0]
        let segments = workout.segments(warmupSec: 240, cooldownSec: 420)
        #expect(segments.first == Segment(.warmup, 240))
        #expect(segments.last == Segment(.cooldown, 420))
        #expect(segments.count == workout.main.count + 2)
        #expect(workout.totalSeconds(warmupSec: 300, cooldownSec: 300) == 30 * 60)
    }

    @Test func mainBlocksAlternateAndOnlyContainRunsAndWalks() {
        for workout in Program.workouts {
            #expect(workout.main.allSatisfy { $0.kind == .run || $0.kind == .walk })
            #expect(workout.main.first?.kind == .run)
            #expect(workout.main.last?.kind == .run || workout.main.last?.kind == .walk)
            for (a, b) in zip(workout.main, workout.main.dropFirst()) {
                #expect(a.kind != b.kind, "\(workout.id) has two \(a.kind) segments in a row")
            }
        }
    }

    @Test func nonStopAndLongestRun() {
        #expect(Program.workout(id: "w5r3")?.isNonStop == true)
        #expect(Program.workout(id: "w5r2")?.isNonStop == false)
        #expect(Program.workout(id: "w6r2")?.longestRunSeconds == 600)
    }

    @Test func everyWeekHasATip() {
        for workout in Program.workouts {
            #expect(!Tips.tip(for: workout).isEmpty)
        }
    }
}
