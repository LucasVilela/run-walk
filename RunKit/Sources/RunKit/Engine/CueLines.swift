import Foundation

/// The spoken lines: short, warm, original. Countdown beeps have no words.
public enum CueLines {
    static let runStarts = [
        "Start running. Run for %@.",
        "Time to run. %@ this time.",
        "Off you go. Run for %@.",
    ]
    static let walkStarts = [
        "Walk now. Nice work.",
        "And walk. Get your breath back.",
        "Walk for %@. Well done.",
    ]
    static let halfways = ["Halfway there.", "Halfway. You're doing really well."]
    static let oneMinute = "One minute to go."
    static let lastRun = "Last run — finish strong. Run for %@."
    static let bigJump = "This is your first %@ run. Nice and slow, slow enough to talk."
    static let nonStop = "Run for %@. Steady and easy, you can do this."
    static let graduationStart = "This is your graduation run. Thirty minutes, nice and easy."
    static let warmup = "Warm up with %@ of brisk walking."
    static let cooldown = "Running's done! %@ cool-down walk."
    static let finished = "Workout complete. That's week %d, run %d done."
    static let graduated = "Workout complete. You just ran for thirty minutes. You've graduated."
    static let endedEarly = "Run saved. Well done for getting out there today."
    static let paused = "Paused. Take your time."
    static let resumed = "Back to it. %@, %@ left."
    static let current = "You're on a %@. %@ left."

    public static func line(for event: CueEvent, plan: RunPlan) -> String? {
        let workout = plan.workout
        switch event {
        case .segmentStart(let index):
            return segmentStart(index, plan: plan)
        case .countdown:
            return nil
        case .halfway(let index):
            let earlier = plan.segments[..<index].filter {
                $0.kind == .run && $0.seconds >= CueTimeline.halfwayMinSec
            }
            return halfways[earlier.count % halfways.count]
        case .oneMinute:
            return oneMinute
        case .current(let index, let remaining):
            return String(format: current, plan.segments[index].kind.name.lowercased(), spoken(remaining))
        case .paused:
            return paused
        case .resumed(let index, let remaining):
            return String(format: resumed, plan.segments[index].kind.name, spoken(remaining))
        case .finished(let early):
            if early { return endedEarly }
            if workout?.graduation == true { return graduated }
            return String(format: finished, workout?.week ?? 0, workout?.run ?? 0)
        }
    }

    private static func segmentStart(_ index: Int, plan: RunPlan) -> String {
        let segment = plan.segments[index]
        let duration = spoken(segment.seconds)
        switch segment.kind {
        case .warmup:
            return String(format: warmup, duration)
        case .cooldown:
            return String(format: cooldown, hyphenatedMinutes(segment.seconds).capitalizedFirst)
        case .walk:
            let line = walkStarts[ordinal(of: index, in: plan) % walkStarts.count]
            return line.contains("%@") ? String(format: line, duration) : line
        case .run:
            let workout = plan.workout
            let runs = plan.runIndices
            if runs.count == 1 {
                if workout?.graduation == true { return graduationStart }
                if workout?.bigJump == true {
                    return String(format: bigJump, hyphenatedMinutes(segment.seconds))
                }
                return String(format: nonStop, duration)
            }
            if index == runs.last { return String(format: lastRun, duration) }
            let line = runStarts[ordinal(of: index, in: plan) % runStarts.count]
            return String(
                format: line, ordinal(of: index, in: plan) == 1 ? duration.capitalizedFirst : duration)
        }
    }

    /// 0 for the first run (or walk), 1 for the second, and so on.
    private static func ordinal(of index: Int, in plan: RunPlan) -> Int {
        let kind = plan.segments[index].kind
        return plan.segments[..<index].filter { $0.kind == kind }.count
    }

    // MARK: - Spoken durations

    static let words = [
        "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
    ]

    static func word(_ n: Int) -> String { n < words.count ? words[n] : "\(n)" }

    /// "90 seconds", "three minutes", "two and a half minutes", "1 minute 12 seconds".
    public static func spoken(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        if seconds < 60 || seconds == 90 { return "\(seconds) seconds" }
        if s == 0 { return "\(word(m)) minute\(m == 1 ? "" : "s")" }
        if s == 30 { return "\(word(m)) and a half minutes" }
        return "\(m) minute\(m == 1 ? "" : "s") \(s) seconds"
    }

    /// "five-minute", "twenty-minute" style for whole minutes.
    static func hyphenatedMinutes(_ seconds: Int) -> String {
        let m = seconds / 60
        let tens = [20: "twenty", 25: "twenty-five", 28: "twenty-eight", 30: "thirty"]
        return "\(tens[m] ?? word(m))-minute"
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
