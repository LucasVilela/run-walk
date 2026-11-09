import Foundation
import RunKit

/// What the full-screen flow shows: the active run, then its summary.
enum Flow {
    case run(RunSession)
    case summary(RunSummary)
}

struct RunSummary {
    let run: RunRecord
    let newBadges: [Badge]
}

/// App state loaded from SQLite. Every plan change goes through `RunStore`, then reloads.
@Observable
@MainActor
final class AppModel {
    private(set) var settings: UserSettings?
    private(set) var completed: Set<String> = []
    private(set) var runs: [RunRecord] = []
    private(set) var badges: [Badge: Date] = [:]
    private(set) var lastCompletedAt: Date?
    private(set) var dismissals: Set<CoachDismissal> = []
    private(set) var now: Date
    var flow: Flow?
    var resumeOffer: ActiveRun?
    private(set) var problem: String?
    /// Bumped on every reload, so views can refresh things derived from the data (e.g. exports).
    private(set) var revision = 0

    @ObservationIgnored private let store: RunStore?
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored let calendar: Calendar
    @ObservationIgnored private let reminders: ReminderNotifications?

    init(
        store: RunStore?, calendar: Calendar = .autoupdatingCurrent, clock: @escaping () -> Date = Date.init,
        reminders: ReminderNotifications? = nil
    ) {
        self.store = store
        self.reminders = reminders
        self.calendar = calendar
        self.clock = clock
        now = clock()
        if store == nil { problem = "Your data couldn't be opened." }
        reload()
        resumeOffer = attempt { try store?.activeRun() } ?? nil
    }

    /// The real database in Application Support.
    static func live() -> AppModel {
        let url = URL.applicationSupportDirectory.appending(path: "RunWalk/runwalk.sqlite")
        return AppModel(store: try? RunStore.open(at: url), reminders: .shared)
    }

    /// Reloads everything, recomputes dates and reschedules reminders (on every app open and change).
    func reload() {
        now = clock()
        revision += 1
        guard let store else { return }
        attempt {
            settings = try store.settings()
            completed = try store.completed()
            runs = try store.runs()
            badges = try store.badges()
            lastCompletedAt = try store.lastCompletedAt()
            dismissals = try store.dismissals()
        }
        if let settings, let reminders {
            reminders.replace(
                with: Reminders.plan(
                    settings: settings, completed: completed, now: now, lastCompletedAt: lastCompletedAt,
                    calendar: calendar),
                calendar: calendar)
        }
    }

    // MARK: - Derived

    var nextWorkout: Workout? { Scheduler.nextWorkout(completed: completed) }

    /// Workouts ever completed ("8 of 27 runs"). Repeating a week doesn't take any away.
    var runsDone: Int { stats.runsDone }
    var currentWeek: Int { nextWorkout?.week ?? 9 }

    var today: TodayState {
        guard let settings else { return .finished }
        return Scheduler.today(
            completed: completed, settings: settings, now: now, lastCompletedAt: lastCompletedAt,
            calendar: calendar)
    }

    var forecast: [(workout: Workout, date: Date)] {
        guard let settings else { return [] }
        return Scheduler.forecast(
            completed: completed, settings: settings, now: now, lastCompletedAt: lastCompletedAt,
            calendar: calendar)
    }

    /// The one coach card for Today, if a rule fires.
    var suggestion: Suggestion? {
        Coach.suggestion(
            CoachContext(
                now: now, calendar: calendar, runs: runs, completed: completed,
                nextDate: forecast.first?.date,
                dismissed: dismissals))
    }

    var stats: Stats { Stats.compute(runs: runs, completed: completed) }

    /// Every day from the start to the forecast finish: what you ran, and what's planned.
    var days: [DayEntry] {
        guard let settings else { return [] }
        return DayByDay.days(
            settings: settings, runs: runs, completed: completed, now: now, lastCompletedAt: lastCompletedAt,
            calendar: calendar)
    }

    var isResting: Bool { Scheduler.isResting(now: now, lastCompletedAt: lastCompletedAt) }

    func totalSeconds(_ workout: Workout) -> Int {
        let s = settings ?? UserSettings(startDate: now)
        return workout.totalSeconds(warmupSec: s.warmupSec, cooldownSec: s.cooldownSec)
    }

    // MARK: - Actions

    func finishOnboarding(_ settings: UserSettings) {
        var s = settings
        s.onboardedAt = clock()
        attempt { try store?.save(s) }
        reload()
    }

    func start(_ workout: Workout) {
        guard let settings, flow == nil else { return }
        let plan = RunPlan(workout: workout, warmupSec: settings.warmupSec, cooldownSec: settings.cooldownSec)
        startSession(engine: RunEngine(plan: plan))
    }

    func resume(_ active: ActiveRun) {
        resumeOffer = nil
        startSession(engine: active.engine)
    }

    func discardResume() {
        resumeOffer = nil
        attempt { try store?.clearActive() }
    }

    private func startSession(engine: RunEngine) {
        guard let settings else { return }
        // Locked-screen beeps come as notifications, so make sure we've asked (once).
        if reminders != nil { Task { await CueNotifications.shared.requestPermissionIfNeeded() } }
        let session = RunSession(
            engine: engine, settings: settings, notifications: reminders == nil ? nil : .shared,
            persist: { [weak self] active in self?.attempt { try self?.store?.saveActive(active, at: Date()) }
            },
            finished: { [weak self] engine in self?.runFinished(engine, mode: .treadmill) })
        flow = .run(session)
    }

    /// Saves the run (advancing the plan if ≥ 80%), then shows the summary.
    func runFinished(_ engine: RunEngine, mode: RunMode) {
        guard var record = RunRecord.finished(engine, mode: mode) else {
            flow = nil
            return
        }
        // The DEBUG ×10/×60 clock runs ahead of real time; never save a run that ends in the future.
        let realNow = clock()
        if record.endedAt > realNow {
            record.startedAt = realNow.addingTimeInterval(record.startedAt.timeIntervalSince(record.endedAt))
            record.endedAt = realNow
        }
        let badges = attempt { try store?.saveFinished(record) } ?? nil
        reload()
        flow = .summary(RunSummary(run: record, newBadges: badges ?? []))
    }

    /// The check-in from the summary screen. Closes the flow.
    func saveCheckIn(
        runId: String, feeling: Feeling?, pain: Bool, notes: String, countAnyway: Bool, distanceM: Double?
    ) {
        attempt {
            try store?.updateCheckIn(
                runId: runId, feeling: feeling, pain: pain, notes: notes, distanceM: distanceM)
            if countAnyway { try store?.countAnyway(runId: runId) }
        }
        reload()
        flow = nil
    }

    // MARK: - Coach

    func accept(_ suggestion: Suggestion) {
        switch suggestion.action {
        case .repeatWeek(let week), .goBackToWeek(let week): attempt { try store?.restart(fromWeek: week) }
        case .redoWorkout(let id): attempt { try store?.redo(id) }
        case nil: break
        }
        dismiss(suggestion)
    }

    func dismiss(_ suggestion: Suggestion) {
        attempt { try store?.dismiss(suggestion.dismissal, at: clock()) }
        reload()
    }

    // MARK: - Settings and data

    func update(_ newSettings: UserSettings) {
        attempt { try store?.save(newSettings) }
        reload()
    }

    func updateRun(_ run: RunRecord, feeling: Feeling?, pain: Bool, notes: String) {
        attempt {
            try store?.updateCheckIn(
                runId: run.id, feeling: feeling, pain: pain, notes: notes, distanceM: nil)
        }
        reload()
    }

    func deleteRun(_ run: RunRecord) {
        attempt { try store?.deleteRun(id: run.id) }
        reload()
    }

    func startOver() {
        attempt { try store?.startOver() }
        reload()
    }

    /// Back to the welcome screen with nothing saved: data, settings, look and reminders all go.
    func eraseEverything() {
        attempt { try store?.eraseEverything() }
        reminders?.replace(with: [], calendar: calendar)
        for key in [Theme.lookKey, "tab", "planMode"] { UserDefaults.standard.removeObject(forKey: key) }
        Theme.apply(.calm)
        flow = nil
        resumeOffer = nil
        reload()
    }

    /// Weeks you can restart from: the current week or any earlier one (never ahead).
    var restartableWeeks: [Int] { Array(1...currentWeek) }

    /// Writes the JSON and CSV exports to temporary files for the share sheet.
    func exportFiles() -> (json: URL, csv: URL)? {
        attempt {
            let dir = FileManager.default.temporaryDirectory
            let json = dir.appending(path: "run-walk-data.json")
            let csv = dir.appending(path: "run-walk-runs.csv")
            try Export.json(
                settings: settings, completed: completed, badges: badges, runs: runs, now: clock()
            )
            .write(to: json)
            try Data(Export.csv(runs: runs).utf8).write(to: csv)
            return (json, csv)
        }
    }

    func repeatWeek(_ week: Int) {
        attempt { try store?.restart(fromWeek: week) }
        reload()
    }

    // MARK: - Errors

    /// Storage errors are rare; show one calm line instead of crashing.
    @discardableResult
    private func attempt<T>(_ body: () throws -> T) -> T? {
        do {
            return try body()
        } catch {
            problem = "Something went wrong saving your data. Please try again."
            return nil
        }
    }
}
