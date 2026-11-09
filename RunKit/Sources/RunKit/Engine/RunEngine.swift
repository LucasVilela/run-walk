import Foundation

public enum RunPhase: String, Codable, Sendable {
    case idle, running, paused, finished
}

/// Ground jumped over by "Skip segment". Positions on the plan's timeline.
public struct SkipRange: Codable, Equatable, Sendable {
    public let from: Double
    public let to: Double
}

/// What the Run screen draws.
public struct RunSnapshot: Equatable, Sendable {
    public let phase: RunPhase
    public let index: Int
    public let segment: Segment
    public let next: Segment?
    public let segmentRemaining: Double
    public let movingSec: Double
    /// Seconds left in the whole workout.
    public let remainingSec: Double
    /// 0…1 along the whole workout, for the marker on the segment bar.
    public let fraction: Double
    public let completionPct: Double
}

/// Pure state machine: idle → running ⇄ paused → finished. Every call takes `now`, so tests use a
/// fake clock. Time is never summed from ticks: moving time = now − startedAt − pausedTotal.
/// Codable so the app can save it every 10 s and offer "Resume your run?".
public struct RunEngine: Codable, Equatable, Sendable {
    /// At or above this share of the main block, the workout counts as done.
    public static let countedPct = 80.0

    public let plan: RunPlan
    public private(set) var phase: RunPhase = .idle
    public private(set) var startedAt: Date?
    public private(set) var pausedTotal: TimeInterval = 0
    public private(set) var pausedAt: Date?
    public private(set) var endedAt: Date?
    public private(set) var endedEarly = false
    public private(set) var skips: [SkipRange] = []
    /// Position up to which cues have been handled.
    private var cuedPosition = 0.0

    public init(plan: RunPlan) {
        self.plan = plan
    }

    // MARK: - Time

    public func movingSec(at now: Date) -> Double {
        guard let startedAt else { return 0 }
        let reference = endedAt ?? pausedAt ?? now
        return Swift.max(0, reference.timeIntervalSince(startedAt) - pausedTotal)
    }

    public var skippedSec: Double { skips.reduce(0) { $0 + $1.to - $1.from } }

    public func position(at now: Date) -> Double {
        Swift.min(plan.totalSec, movingSec(at: now) + skippedSec)
    }

    // MARK: - Transitions (each returns the cues to play)

    public mutating func start(at now: Date) -> [CueEvent] {
        guard phase == .idle else { return [] }
        phase = .running
        startedAt = now
        cuedPosition = 0
        return [.segmentStart(index: 0)]
    }

    /// Call every ~250 ms while in the foreground.
    public mutating func tick(at now: Date) -> [CueEvent] {
        guard phase == .running else { return [] }
        let position = position(at: now)
        var events = CueTimeline.events(in: plan, from: cuedPosition, to: position)
        cuedPosition = position
        if position >= plan.totalSec {
            finishAtPlanEnd()
            events.append(.finished(early: false))
        }
        return CueTimeline.coalesce(events)
    }

    /// Back from the background (or a long gap): jump to the right place and announce the current
    /// segment once, without replaying the cues that were missed.
    public mutating func resync(at now: Date) -> [CueEvent] {
        guard phase == .running else { return [] }
        let position = position(at: now)
        cuedPosition = position
        if position >= plan.totalSec {
            finishAtPlanEnd()
            return [.finished(early: false)]
        }
        let snap = snapshot(at: now)
        return [.current(index: snap.index, remainingSec: Int(snap.segmentRemaining.rounded(.up)))]
    }

    public mutating func pause(at now: Date) -> [CueEvent] {
        guard phase == .running else { return [] }
        let events = tick(at: now)
        guard phase == .running else { return events }
        phase = .paused
        pausedAt = now
        return events + [.paused]
    }

    public mutating func resume(at now: Date) -> [CueEvent] {
        guard phase == .paused, let pausedAt else { return [] }
        pausedTotal += Swift.max(0, now.timeIntervalSince(pausedAt))
        self.pausedAt = nil
        phase = .running
        let snap = snapshot(at: now)
        return [.resumed(index: snap.index, remainingSec: Int(snap.segmentRemaining.rounded(.up)))]
    }

    /// Jumps to the start of the next segment. Skipping the last segment finishes the run.
    public mutating func skip(at now: Date) -> [CueEvent] {
        guard phase == .running || phase == .paused else { return [] }
        let position = position(at: now)
        let index = plan.index(at: position)
        guard index < plan.segments.count - 1 else {
            stop(at: now, early: false)
            return [.finished(early: false)]
        }
        let target = plan.start(of: index + 1)
        skips.append(SkipRange(from: position, to: target))
        cuedPosition = target
        return [.segmentStart(index: index + 1)]
    }

    /// Restoring after the app was closed: a running engine becomes paused at `date` (its last save),
    /// so the time the app was closed counts as paused, never as running.
    public mutating func suspend(at date: Date) {
        guard phase == .running, let startedAt else { return }
        let at = Swift.max(date, startedAt)
        pausedAt = at
        phase = .paused
        cuedPosition = position(at: at)
    }

    /// "End & save" before the plan is over.
    public mutating func end(at now: Date) -> [CueEvent] {
        guard phase == .running || phase == .paused else { return [] }
        stop(at: now, early: true)
        return [.finished(early: true)]
    }

    private mutating func stop(at now: Date, early: Bool) {
        if let pausedAt {
            pausedTotal += Swift.max(0, now.timeIntervalSince(pausedAt))
            self.pausedAt = nil
        }
        endedAt = now
        endedEarly = early
        phase = .finished
    }

    /// Ends exactly when the plan ran out, even if the tick came late.
    private mutating func finishAtPlanEnd() {
        guard let startedAt else { return }
        endedAt = startedAt.addingTimeInterval(pausedTotal + plan.totalSec - skippedSec)
        endedEarly = false
        phase = .finished
    }

    // MARK: - Read-outs

    public func snapshot(at now: Date) -> RunSnapshot {
        let position = position(at: now)
        let index = plan.index(at: position)
        let segments = plan.segments
        return RunSnapshot(
            phase: phase, index: index, segment: segments[index],
            next: index + 1 < segments.count ? segments[index + 1] : nil,
            segmentRemaining: Swift.max(0, plan.end(of: index) - position),
            movingSec: movingSec(at: now),
            remainingSec: Swift.max(0, plan.totalSec - position),
            fraction: plan.totalSec > 0 ? position / plan.totalSec : 0,
            completionPct: completionPct(at: now))
    }

    /// Share of the main block (runs and walks) actually done, 0…100. Skipped time doesn't count.
    public func completionPct(at now: Date) -> Double {
        let main = plan.mainSec
        guard main > 0 else { return 0 }
        let done = plan.mainIndices.reduce(0) { $0 + covered($1, upTo: position(at: now)) }
        return Swift.min(100, done / main * 100)
    }

    public func isCounted(at now: Date) -> Bool { completionPct(at: now) >= Self.countedPct }

    /// Seconds spent in run segments (skipped time doesn't count).
    public func runningSec(at now: Date) -> Double {
        plan.runIndices.reduce(0) { $0 + covered($1, upTo: position(at: now)) }
    }

    private func covered(_ index: Int, upTo position: Double) -> Double {
        let a = plan.start(of: index)
        let b = plan.end(of: index)
        var seconds = overlap(a, b, 0, position)
        for skip in skips { seconds -= overlap(a, b, skip.from, skip.to) }
        return Swift.max(0, seconds)
    }

    private func overlap(_ a: Double, _ b: Double, _ c: Double, _ d: Double) -> Double {
        Swift.max(0, Swift.min(b, d) - Swift.max(a, c))
    }
}
