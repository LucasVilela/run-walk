import Foundation
import RunKit

/// Drives the pure RunEngine from the UI: a 250 ms loop, the (dev-speed) clock, cues, the
/// notification fallback for a locked phone, saving state every 10 s, and handing the finished run back.
@Observable
@MainActor
final class RunSession {
    private(set) var engine: RunEngine
    private(set) var snapshot: RunSnapshot
    private(set) var speed: Double = 1

    @ObservationIgnored private var clock: ScaledClock
    @ObservationIgnored private let cues: CuePlayer
    @ObservationIgnored private let notifications: CueNotifications?
    @ObservationIgnored private let widgets: WidgetBridge?
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var lastTickReal = Date()
    @ObservationIgnored private var lastSaveReal = Date.distantPast
    @ObservationIgnored private var reportedFinish = false
    @ObservationIgnored private let persist: (ActiveRun) -> Void
    @ObservationIgnored private let finished: (RunEngine) -> Void

    /// A gap longer than this between ticks means the app was suspended: resync, don't replay.
    static let suspendedGap: TimeInterval = 2
    static let saveEvery: TimeInterval = 10

    init(
        engine: RunEngine, settings: UserSettings, cues: CuePlayer = .shared,
        notifications: CueNotifications? = .shared, widgets: WidgetBridge? = nil,
        persist: @escaping (ActiveRun) -> Void = { _ in },
        finished: @escaping (RunEngine) -> Void = { _ in }
    ) {
        let now = Date()
        self.engine = engine
        clock = ScaledClock(now: now)
        snapshot = engine.snapshot(at: now)
        self.cues = cues
        self.notifications = notifications
        self.widgets = widgets
        self.persist = persist
        self.finished = finished
        cues.options = .init(voice: settings.voiceOn, beeps: settings.beepsOn, haptics: settings.hapticsOn)
    }

    var plan: RunPlan { engine.plan }
    private var now: Date { clock.now(real: Date()) }
    /// Whole percent of the main block done right now, for "End run? You've done 64%."
    var currentCompletionPct: Int { Int(engine.completionPct(at: now)) }

    /// Starts a new run, or picks up a resumed one where the clock says it is.
    func begin() {
        guard loop == nil else { return }
        apply(engine.phase == .idle ? engine.start(at: now) : engine.resync(at: now), save: true)
        if engine.phase == .paused {
            notifications?.cancelAll(plan: plan)
            updateWidgets()
        } else {
            reschedule()
        }
        lastTickReal = Date()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                self?.tick()
            }
        }
    }

    func togglePause() {
        if engine.phase == .paused {
            apply(engine.resume(at: now), save: true)
            reschedule()
        } else {
            apply(engine.pause(at: now), save: true)
            notifications?.cancelAll(plan: plan)
            updateWidgets()
        }
    }

    func skip() {
        apply(engine.skip(at: now), save: true)
        if engine.phase == .running { reschedule() } else { updateWidgets() }
    }

    func end() { apply(engine.end(at: now), save: true) }

    func stop() {
        loop?.cancel()
        loop = nil
        notifications?.cancelAll(plan: plan)
        widgets?.runEnded()
    }

    /// Dev only: ×1, ×10, ×60.
    func cycleSpeed() {
        let next: Double = speed == 1 ? 10 : speed == 10 ? 60 : 1
        clock.setSpeed(next, real: Date())
        speed = next
        if engine.phase == .running { reschedule() }
    }

    // MARK: - Loop

    private func tick() {
        let real = Date()
        let suspended = real.timeIntervalSince(lastTickReal) > Self.suspendedGap
        lastTickReal = real
        apply(suspended ? engine.resync(at: now) : engine.tick(at: now), save: false)
    }

    private func apply(_ events: [CueEvent], save: Bool) {
        for event in events {
            cues.play(event, plan: engine.plan)
            if case .segmentStart(let index) = event { notifications?.announced(index: index) }
        }
        snapshot = engine.snapshot(at: now)
        if engine.phase == .finished {
            guard !reportedFinish else { return }
            reportedFinish = true
            stop()
            finished(engine)
            return
        }
        if save || !events.isEmpty || Date().timeIntervalSince(lastSaveReal) >= Self.saveEvery {
            lastSaveReal = Date()
            persist(ActiveRun(engine: engine, mode: .treadmill))
        }
    }

    /// Also refreshes the lock-screen widget and Live Activity, which follow the same timeline.
    private func reschedule() {
        notifications?.schedule(plan: plan, position: engine.position(at: now), speed: speed)
        updateWidgets()
    }

    private func updateWidgets() {
        guard engine.phase == .running || engine.phase == .paused else { return }
        widgets?.runChanged(engine, now: now, speed: speed)
    }
}
