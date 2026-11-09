import Foundation

/// Something to announce. The engine emits these; the app's CuePlayer turns them into
/// voice, beeps and vibration. Lines come from `CueLines`.
public enum CueEvent: Equatable, Codable, Sendable {
    case segmentStart(index: Int)
    /// 3-2-1 beeps before every switch.
    case countdown(Int)
    case halfway(index: Int)
    case oneMinute(index: Int)
    /// Back from the background: say where we are, once.
    case current(index: Int, remainingSec: Int)
    case paused
    case resumed(index: Int, remainingSec: Int)
    case finished(early: Bool)
}

/// Where each cue sits on the run's timeline.
public enum CueTimeline {
    public static let halfwayMinSec = 180
    public static let oneMinuteMinSec = 120

    /// Every timed cue, in order. Segment 0's start is announced by `start` itself.
    public static func marks(for plan: RunPlan) -> [(at: Double, event: CueEvent)] {
        var marks: [(Double, CueEvent)] = []
        for (i, segment) in plan.segments.enumerated() {
            let start = plan.start(of: i)
            let end = plan.end(of: i)
            if i > 0 { marks.append((start, .segmentStart(index: i))) }
            if segment.kind == .run && segment.seconds >= halfwayMinSec {
                marks.append((start + Double(segment.seconds) / 2, .halfway(index: i)))
            }
            if segment.kind == .run && segment.seconds >= oneMinuteMinSec {
                marks.append((end - 60, .oneMinute(index: i)))
            }
            for n in [3, 2, 1] where segment.seconds > n {
                marks.append((end - Double(n), .countdown(n)))
            }
        }
        return marks.sorted { $0.0 < $1.0 }
    }

    /// Cues whose time falls in (from, to].
    public static func events(in plan: RunPlan, from: Double, to: Double) -> [CueEvent] {
        guard to > from else { return [] }
        return marks(for: plan).filter { $0.at > from && $0.at <= to }.map(\.event)
    }

    /// When one tick crosses several cues (dev speed, a slow frame), keep only what still matters:
    /// the latest segment start and anything after it, and at most one countdown beep.
    public static func coalesce(_ events: [CueEvent]) -> [CueEvent] {
        if events.contains(.finished(early: false)) { return [.finished(early: false)] }
        var kept = events
        if let lastStart = kept.lastIndex(where: { if case .segmentStart = $0 { true } else { false } }) {
            kept = Array(kept[lastStart...])
        }
        let countdowns = kept.indices.filter { if case .countdown = kept[$0] { true } else { false } }
        for i in countdowns.dropLast().reversed() { kept.remove(at: i) }
        return kept
    }
}

/// A clock that can run faster than real time. Dev builds use ×10 / ×60 to test whole workouts.
public struct ScaledClock: Sendable {
    public private(set) var speed: Double = 1
    private var anchorReal: Date
    private var anchorVirtual: Date

    public init(now: Date) {
        anchorReal = now
        anchorVirtual = now
    }

    public func now(real: Date) -> Date {
        anchorVirtual.addingTimeInterval(real.timeIntervalSince(anchorReal) * speed)
    }

    /// Changes speed without a jump in virtual time.
    public mutating func setSpeed(_ newSpeed: Double, real: Date) {
        anchorVirtual = now(real: real)
        anchorReal = real
        speed = Swift.max(1, newSpeed)
    }
}
