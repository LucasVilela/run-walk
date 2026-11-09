import Foundation
import RunKit

/// Drives an other run: a stopwatch with a spoken time check every 5 minutes, saved every 10 s so a
/// closed app picks it up again, and the lock-screen Live Activity counting up.
@Observable
@MainActor
final class FreeRunSession {
    private(set) var run: FreeRun
    private(set) var elapsed: Double

    @ObservationIgnored private let cues: CuePlayer?
    @ObservationIgnored private let widgets: WidgetBridge?
    @ObservationIgnored private let persist: (FreeRun) -> Void
    @ObservationIgnored private let finished: (RunRecord) -> Void
    @ObservationIgnored private let discarded: () -> Void
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var lastSaveReal = Date.distantPast

    init(
        run: FreeRun, settings: UserSettings, cues: CuePlayer? = .shared, widgets: WidgetBridge? = nil,
        persist: @escaping (FreeRun) -> Void = { _ in }, finished: @escaping (RunRecord) -> Void = { _ in },
        discarded: @escaping () -> Void = {}
    ) {
        self.run = run
        elapsed = run.elapsed(at: Date())
        self.cues = cues
        self.widgets = widgets
        self.persist = persist
        self.finished = finished
        self.discarded = discarded
        cues?.options = .init(voice: settings.voiceOn, beeps: settings.beepsOn, haptics: settings.hapticsOn)
    }

    var isPaused: Bool { run.isPaused }

    func begin() {
        guard loop == nil else { return }
        if elapsed < 1 && !run.isPaused { cues?.announce("Off you go. Run at your own pace.") }
        changed()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                self?.tick()
            }
        }
    }

    func togglePause() {
        let now = Date()
        if run.isPaused {
            run.resume(at: now)
            cues?.announce("Back to it.")
        } else {
            run.pause(at: now)
            cues?.announce("Paused.")
        }
        elapsed = run.elapsed(at: now)
        changed()
    }

    func end() {
        let record = run.record(endedAt: Date())
        stop()
        cues?.announce("Run saved. Nice work.")
        finished(record)
    }

    func discard() {
        stop()
        discarded()
    }

    func stop() {
        loop?.cancel()
        loop = nil
        widgets?.runEnded()
    }

    private func tick() {
        let now = Date()
        let next = run.elapsed(at: now)
        // After the phone was locked, only the latest 5-minute mark is announced.
        if let minutes = FreeRun.marker(from: elapsed, to: next) {
            cues?.announce(CueLines.freeRunTime(minutes: minutes))
        }
        elapsed = next
        if now.timeIntervalSince(lastSaveReal) >= RunSession.saveEvery { save() }
    }

    private func changed() {
        save()
        widgets?.freeRunChanged(run)
    }

    private func save() {
        lastSaveReal = Date()
        persist(run)
    }
}
