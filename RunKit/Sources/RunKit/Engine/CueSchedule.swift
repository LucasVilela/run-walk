import Foundation

/// A segment switch still to come, for scheduling a local-notification fallback.
/// `index == plan.segments.count` means the end of the workout.
public struct ScheduledCue: Equatable, Sendable {
    public let index: Int
    public let secondsFromNow: Double
}

public enum CueSchedule {
    /// Every segment start (and the finish) after `position`, in workout seconds from now.
    public static func upcoming(in plan: RunPlan, position: Double) -> [ScheduledCue] {
        var cues: [ScheduledCue] = []
        for index in 1...plan.segments.count {
            let at = index == plan.segments.count ? plan.totalSec : plan.start(of: index)
            if at > position { cues.append(ScheduledCue(index: index, secondsFromNow: at - position)) }
        }
        return cues
    }

    /// Short title and spoken line for a notification at `index`.
    public static func text(for index: Int, in plan: RunPlan) -> (title: String, body: String) {
        guard index < plan.segments.count else {
            return ("Workout complete", CueLines.line(for: .finished(early: false), plan: plan) ?? "")
        }
        let segment = plan.segments[index]
        return (
            "\(segment.kind.name) \(Format.clock(segment.seconds))",
            CueLines.line(for: .segmentStart(index: index), plan: plan) ?? ""
        )
    }
}
