import Foundation

/// A stopwatch for a run outside the plan: no segments, no target, just time.
/// Like `RunEngine`, time comes from timestamps (elapsed = now − startedAt − pausedTotal), never ticks.
public struct FreeRun: Codable, Equatable, Sendable {
    /// A spoken time check every 5 minutes.
    public static let markerEvery = 300
    /// A run saved longer ago than this when the app comes back was most likely forgotten,
    /// so it comes back paused at its last save instead of counting the whole gap.
    public static let forgottenAfter: TimeInterval = 3 * 3600

    public let startedAt: Date
    public private(set) var pausedTotal: TimeInterval = 0
    public private(set) var pausedAt: Date?

    public init(startedAt: Date) {
        self.startedAt = startedAt
    }

    public var isPaused: Bool { pausedAt != nil }

    public func elapsed(at now: Date) -> Double {
        max(0, (pausedAt ?? now).timeIntervalSince(startedAt) - pausedTotal)
    }

    public mutating func pause(at now: Date) {
        guard pausedAt == nil else { return }
        pausedAt = max(now, startedAt)
    }

    public mutating func resume(at now: Date) {
        guard let pausedAt else { return }
        pausedTotal += max(0, now.timeIntervalSince(pausedAt))
        self.pausedAt = nil
    }

    /// The minutes to announce when elapsed time goes from `from` to `to` across a 5-minute mark
    /// (only the latest mark, so a long gap after the phone was locked is announced once).
    public static func marker(from: Double, to: Double) -> Int? {
        let every = Double(markerEvery)
        let mark = (to / every).rounded(.down)
        guard mark >= 1, mark > (from / every).rounded(.down) else { return nil }
        return Int(mark) * markerEvery / 60
    }

    /// Back after the app was closed: a running stopwatch keeps going (you were probably still running
    /// with the phone locked), unless the gap is so long the run was surely forgotten.
    public mutating func restore(savedAt: Date, now: Date) {
        guard pausedAt == nil, now.timeIntervalSince(savedAt) > Self.forgottenAfter else { return }
        pausedAt = max(savedAt, startedAt)
    }

    /// The finished run, ending `now`.
    public func record(id: String = UUID().uuidString, endedAt now: Date) -> RunRecord {
        RunRecord.other(id: id, startedAt: startedAt, durationSec: Int(elapsed(at: now).rounded()))
    }
}
