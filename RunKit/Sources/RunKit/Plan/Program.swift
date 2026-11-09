/// One of the 27 workouts. `main` is the block between warm-up and cool-down;
/// warm-up and cool-down are added at runtime from settings.
public struct Workout: Identifiable, Hashable, Sendable {
    public let id: String
    public let week: Int
    public let run: Int
    public let main: [Segment]
    public let bigJump: Bool
    public let graduation: Bool

    public var title: String { "Week \(week) · Run \(run)" }
    public var mainSeconds: Int { main.reduce(0) { $0 + $1.seconds } }
    public var runningSeconds: Int { main.filter { $0.kind == .run }.reduce(0) { $0 + $1.seconds } }
    public var longestRunSeconds: Int { main.filter { $0.kind == .run }.map(\.seconds).max() ?? 0 }
    /// True when the main block is a single run with no walk breaks.
    public var isNonStop: Bool { main.count == 1 && main[0].kind == .run }

    public func segments(warmupSec: Int, cooldownSec: Int) -> [Segment] {
        [Segment(.warmup, warmupSec)] + main + [Segment(.cooldown, cooldownSec)]
    }

    public func totalSeconds(warmupSec: Int, cooldownSec: Int) -> Int {
        warmupSec + mainSeconds + cooldownSec
    }
}

/// The 9-week beginner run/walk plan. Exact data from the brief: do not change.
public enum Program {
    public static let weeks = 1...9
    public static let workouts: [Workout] = build()

    public static func workout(id: String) -> Workout? {
        workouts.first { $0.id == id }
    }

    public static func index(of id: String) -> Int? {
        workouts.firstIndex { $0.id == id }
    }

    public static func workouts(inWeek week: Int) -> [Workout] {
        workouts.filter { $0.week == week }
    }

    private static func build() -> [Workout] {
        let w1 = repeating(8, [run(60), walk(90)])
        let w2 = repeating(6, [run(90), walk(120)])
        let w3 = repeating(2, [run(90), walk(90), run(180), walk(180)])
        let w4 = [run(180), walk(90), run(300), walk(150), run(180), walk(90), run(300)]

        let mains: [[[Segment]]] = [
            [w1, w1, w1],
            [w2, w2, w2],
            [w3, w3, w3],
            [w4, w4, w4],
            [
                [run(min(5)), walk(min(3)), run(min(5)), walk(min(3)), run(min(5))],
                [run(min(8)), walk(min(5)), run(min(8))],
                [run(min(20))],
            ],
            [
                [run(min(5)), walk(min(3)), run(min(8)), walk(min(3)), run(min(5))],
                [run(min(10)), walk(min(3)), run(min(10))],
                [run(min(25))],
            ],
            [[run(min(25))], [run(min(25))], [run(min(25))]],
            [[run(min(28))], [run(min(28))], [run(min(28))]],
            [[run(min(30))], [run(min(30))], [run(min(30))]],
        ]

        let bigJumps: Set<String> = ["w5r3", "w6r3"]
        return mains.enumerated().flatMap { weekIndex, runs in
            runs.enumerated().map { runIndex, main in
                let id = "w\(weekIndex + 1)r\(runIndex + 1)"
                return Workout(
                    id: id, week: weekIndex + 1, run: runIndex + 1, main: main,
                    bigJump: bigJumps.contains(id), graduation: id == "w9r3")
            }
        }
    }

    private static func run(_ seconds: Int) -> Segment { Segment(.run, seconds) }
    private static func walk(_ seconds: Int) -> Segment { Segment(.walk, seconds) }
    private static func min(_ minutes: Int) -> Int { minutes * 60 }
    private static func repeating(_ count: Int, _ block: [Segment]) -> [Segment] {
        Array(repeating: block, count: count).flatMap { $0 }
    }
}
