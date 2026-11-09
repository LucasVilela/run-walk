import Foundation
import RunKit

#if canImport(ActivityKit)
    import ActivityKit
#endif

// Compiled into both the app and the widget extension. The app writes a small snapshot into the
// shared app group; the widgets read it. Nothing leaves the phone.

enum WidgetShared {
    static let appGroup = "group.com.lucasvilela.runwalk"
    static let kind = "RunWalkWidget"
    private static let key = "widgetSnapshot"

    static func load() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults(suiteName: appGroup)?.set(data, forKey: key)
    }
}

/// What the lock-screen widgets show.
struct WidgetSnapshot: Codable, Equatable, Sendable {
    struct NextRun: Codable, Equatable, Sendable {
        var title: String
        var date: Date
        var minutes: Int
    }

    /// One segment of the run in progress, in real (wall-clock) time.
    struct LiveSegment: Codable, Equatable, Sendable {
        var kind: SegmentKind
        var seconds: Int
        var start: Date
        var end: Date
    }

    struct ActiveRun: Codable, Equatable, Sendable {
        var title: String
        /// From the current segment to the end of the workout.
        var segments: [LiveSegment]
        /// Set while paused: the clock is frozen, so the widget shows fixed numbers.
        var paused: Paused?
    }

    struct Paused: Codable, Equatable, Sendable {
        var kind: SegmentKind
        var segmentRemaining: Int
    }

    var next: NextRun?
    var runsDone = 0
    var total = 27
    var active: ActiveRun?
}

#if canImport(ActivityKit) && os(iOS)
    /// The Live Activity shown on the lock screen and Dynamic Island during a run.
    struct RunActivityAttributes: ActivityAttributes {
        struct ContentState: Codable, Hashable, Sendable {
            /// Wall-clock time the workout would have started if it had never been paused or skipped,
            /// and when it will end. The system animates the countdown and bar between them by itself.
            var start: Date
            var end: Date
            /// When paused, the share of the workout done and the time left, shown as fixed values.
            var pausedFraction: Double?
            var pausedRemaining: Int?
        }

        var title: String
        /// Empty for an other run (a stopwatch with no plan).
        var segments: [Segment]

        var isFree: Bool { segments.isEmpty }
    }
#endif
