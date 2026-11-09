import Foundation

public enum CoachRule: String, Codable, Sendable, CaseIterable {
    case pain, gapRedo, gapBack, hardRepeat, bigJump, easyStreak
}

/// What "accept" does. The plan never changes without the user tapping it.
public enum CoachAction: Equatable, Sendable {
    case repeatWeek(Int)
    case redoWorkout(String)
    case goBackToWeek(Int)
}

public struct Suggestion: Equatable, Sendable {
    public let rule: CoachRule
    /// Identifies this instance of the rule, so a dismissal hides it until something changes.
    public let contextKey: String
    public let title: String
    public let body: String
    public let acceptLabel: String?
    public let action: CoachAction?
    public let dismissLabel: String

    public var dismissal: CoachDismissal { CoachDismissal(rule: rule, contextKey: contextKey) }
}

public struct CoachDismissal: Hashable, Codable, Sendable {
    public let rule: CoachRule
    public let contextKey: String

    public init(rule: CoachRule, contextKey: String) {
        self.rule = rule
        self.contextKey = contextKey
    }
}

public struct CoachContext: Sendable {
    public var now: Date
    public var calendar: Calendar
    public var runs: [RunRecord]
    public var completed: Set<String>
    /// Forecast date of the next workout (from `Scheduler.forecast`).
    public var nextDate: Date?
    public var dismissed: Set<CoachDismissal>

    public init(
        now: Date, calendar: Calendar, runs: [RunRecord], completed: Set<String>, nextDate: Date?,
        dismissed: Set<CoachDismissal> = []
    ) {
        self.now = now
        self.calendar = calendar
        self.runs = runs
        self.completed = completed
        self.nextDate = nextDate
        self.dismissed = dismissed
    }
}

/// Deterministic coach. Shows at most one suggestion, in priority order:
/// pain → long gap → hard runs → big jump preview → easy streak.
public enum Coach {
    public static let painDays = 2

    public static func suggestion(_ context: CoachContext) -> Suggestion? {
        candidates(context).first { !context.dismissed.contains($0.dismissal) }
    }

    /// Every rule that fires, highest priority first (before dismissals).
    public static func candidates(_ context: CoachContext) -> [Suggestion] {
        let runs = context.runs.sorted { $0.endedAt > $1.endedAt }
        let painNow = painRun(runs, context)
        let painToday = runs.contains {
            $0.pain && context.calendar.isDate($0.endedAt, inSameDayAs: context.now)
        }

        var list: [Suggestion] = []
        if let painNow { list.append(pain(painNow)) }
        if let gap = gap(runs, context) { list.append(gap) }
        // No "keep going" nudges on a day pain was flagged.
        guard !painToday else { return list }
        if let hard = hardRuns(runs) { list.append(hard) }
        if let jump = bigJump(context) { list.append(jump) }
        if let easy = easyStreak(runs) { list.append(easy) }
        return list
    }

    // MARK: - Rules

    private static func painRun(_ runs: [RunRecord], _ context: CoachContext) -> RunRecord? {
        guard let latest = runs.first(where: \.pain) else { return nil }
        let days = DateHelpers.daysBetween(latest.endedAt, context.now, context.calendar)
        return days < painDays ? latest : nil
    }

    private static func pain(_ run: RunRecord) -> Suggestion {
        Suggestion(
            rule: .pain, contextKey: run.id, title: "Look after that pain",
            body:
                "Take at least 2 days off running, even if your next run is sooner. Don't run through sharp pain. "
                + "If it's still there after a few days, see a health professional.",
            acceptLabel: nil, action: nil, dismissLabel: "Got it")
    }

    private static func gap(_ runs: [RunRecord], _ context: CoachContext) -> Suggestion? {
        guard let last = runs.first else { return nil }
        let days = DateHelpers.daysBetween(last.endedAt, context.now, context.calendar)
        if (7...13).contains(days), let redo = Scheduler.lastCompleted(completed: context.completed) {
            return Suggestion(
                rule: .gapRedo, contextKey: last.id, title: "Welcome back",
                body: "It's been a little while. Want to redo \(redo.title) first to ease back in?",
                acceptLabel: "Redo it", action: .redoWorkout(redo.id), dismissLabel: "Keep going")
        }
        if days >= 14, let next = Scheduler.nextWorkout(completed: context.completed) {
            let week = max(1, next.week - 1)
            return Suggestion(
                rule: .gapBack, contextKey: last.id, title: "Welcome back",
                body:
                    "It's been a couple of weeks. Starting again from week \(week) makes the return easier.",
                acceptLabel: "Go back to week \(week)", action: .goBackToWeek(week), dismissLabel: "Not now")
        }
        return nil
    }

    private static func hardRuns(_ runs: [RunRecord]) -> Suggestion? {
        let lastThree = runs.prefix(3)
        guard lastThree.filter({ $0.feeling == .hard }).count >= 2,
            let latest = lastThree.first, let week = latest.workout?.week
        else { return nil }
        return Suggestion(
            rule: .hardRepeat, contextKey: latest.id, title: "Feeling tough?",
            body: "Want to repeat this week? Lots of people do.",
            acceptLabel: "Repeat week", action: .repeatWeek(week), dismissLabel: "Keep going")
    }

    private static func bigJump(_ context: CoachContext) -> Suggestion? {
        guard let next = Scheduler.nextWorkout(completed: context.completed), next.bigJump,
            let date = context.nextDate
        else { return nil }
        let days = DateHelpers.daysBetween(context.now, date, context.calendar)
        guard days == 0 || days == 1 else { return nil }
        let minutes = next.longestRunSeconds / 60
        let when = days == 0 ? "Today's" : "Tomorrow's"
        return Suggestion(
            rule: .bigJump, contextKey: "\(next.id)-\(days)", title: "A big one is coming",
            body: "\(when) your first \(minutes)-minute run. Go slower than you think — slow enough to talk.",
            acceptLabel: nil, action: nil, dismissLabel: "Got it")
    }

    private static func easyStreak(_ runs: [RunRecord]) -> Suggestion? {
        let lastThree = runs.prefix(3)
        guard lastThree.count == 3, lastThree.allSatisfy({ $0.feeling == .easy }),
            let latest = lastThree.first
        else { return nil }
        return Suggestion(
            rule: .easyStreak, contextKey: latest.id, title: "Nice and easy",
            body: "Three easy runs in a row. You're ready for what's next.",
            acceptLabel: nil, action: nil, dismissLabel: "Thanks")
    }
}
