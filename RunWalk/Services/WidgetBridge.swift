import ActivityKit
import Foundation
import RunKit
import WidgetKit

/// Keeps the lock-screen widgets and the run's Live Activity in step with the app.
/// Everything is written while the app is in the foreground (start, pause, resume, skip, plan changes);
/// after that the system animates the countdowns by itself, even when the phone is locked.
@MainActor
final class WidgetBridge {
    static let shared = WidgetBridge()

    private var snapshot = WidgetShared.load() ?? WidgetSnapshot()
    /// The Live Activity's id. Activity objects aren't Sendable, so they're looked up off the main actor.
    private var activityID: String?
    private typealias RunActivity = Activity<RunActivityAttributes>

    /// At launch no run is going on: clear any run left over from a killed app. Only the activities
    /// that exist now: an other run restored at launch starts a fresh one right after.
    func install() {
        snapshot.active = nil
        save()
        let stale = Set(RunActivity.activities.map(\.id))
        Task.detached {
            for stray in RunActivity.activities where stale.contains(stray.id) {
                await stray.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    // MARK: Plan (idle widgets)

    func updatePlan(next: (workout: Workout, date: Date, minutes: Int)?, runsDone: Int) {
        let newNext = next.map {
            WidgetSnapshot.NextRun(title: $0.workout.title, date: $0.date, minutes: $0.minutes)
        }
        guard newNext != snapshot.next || runsDone != snapshot.runsDone else { return }
        snapshot.next = newNext
        snapshot.runsDone = runsDone
        save()
    }

    // MARK: Run

    /// Call on start, resume, pause, skip and dev-speed changes. `now` is the run's (dev-speed) clock.
    func runChanged(_ engine: RunEngine, now: Date, speed: Double) {
        let real = Date()
        let plan = engine.plan
        let position = engine.position(at: now)
        let index = plan.index(at: position)
        let title = plan.workout?.title ?? "Run"
        let paused = engine.phase == .paused

        let segments = (index..<plan.segments.count).map { i in
            WidgetSnapshot.LiveSegment(
                kind: plan.segments[i].kind, seconds: plan.segments[i].seconds,
                start: real.addingTimeInterval((plan.start(of: i) - position) / speed),
                end: real.addingTimeInterval((plan.end(of: i) - position) / speed))
        }
        snapshot.active = WidgetSnapshot.ActiveRun(
            title: title, segments: segments,
            paused: paused
                ? .init(
                    kind: plan.segments[index].kind,
                    segmentRemaining: Int((plan.end(of: index) - position).rounded(.up)))
                : nil)
        save()

        let start = real.addingTimeInterval(-position / speed)
        let state = RunActivityAttributes.ContentState(
            start: start, end: start.addingTimeInterval(plan.totalSec / speed),
            pausedFraction: paused ? position / plan.totalSec : nil,
            pausedRemaining: paused ? Int((plan.totalSec - position).rounded(.up)) : nil)
        show(state, attributes: RunActivityAttributes(title: title, segments: plan.segments))
    }

    /// An other run: no segments, so the Live Activity counts up instead of down.
    /// While paused, `pausedRemaining` holds the (fixed) time so far.
    func freeRunChanged(_ run: FreeRun, now: Date = Date()) {
        let elapsed = run.elapsed(at: now)
        let start = now.addingTimeInterval(-elapsed)
        let state = RunActivityAttributes.ContentState(
            start: start, end: start.addingTimeInterval(Self.freeRunSpan), pausedFraction: nil,
            pausedRemaining: run.isPaused ? Int(elapsed) : nil)
        show(state, attributes: RunActivityAttributes(title: "Other run", segments: []))
    }

    /// How far ahead an other run's count-up timer reaches.
    private static let freeRunSpan: TimeInterval = 12 * 3600

    private func show(_ state: RunActivityAttributes.ContentState, attributes: RunActivityAttributes) {
        let content = ActivityContent(state: state, staleDate: state.end.addingTimeInterval(600))
        if let id = activityID {
            Task.detached { await RunActivity.activities.first { $0.id == id }?.update(content) }
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            activityID = try? RunActivity.request(attributes: attributes, content: content).id
        }
    }

    func runEnded() {
        snapshot.active = nil
        save()
        if let id = activityID {
            Task.detached {
                await RunActivity.activities.first { $0.id == id }?.end(nil, dismissalPolicy: .immediate)
            }
        }
        activityID = nil
    }

    private func save() {
        WidgetShared.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
