/// Badges are stored with their unlock time, so repeating a week never takes one away.
public enum Badge: String, Codable, Sendable, CaseIterable, Identifiable {
    case firstRun
    case week1, week2, week3, week4, week5, week6, week7, week8, week9
    case first20
    case graduation

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .firstRun: "First run"
        case .first20: "First 20-minute run"
        case .graduation: "Graduation"
        default: "Week \(weekNumber ?? 0) complete"
        }
    }

    public var weekNumber: Int? {
        rawValue.hasPrefix("week") ? Int(rawValue.dropFirst(4)) : nil
    }

    /// Badges the completed workouts have earned.
    public static func earned(completed: Set<String>) -> Set<Badge> {
        var badges: Set<Badge> = []
        if !completed.isEmpty { badges.insert(.firstRun) }
        for badge in allCases {
            guard let week = badge.weekNumber else { continue }
            if Program.workouts(inWeek: week).allSatisfy({ completed.contains($0.id) }) {
                badges.insert(badge)
            }
        }
        if completed.contains("w5r3") { badges.insert(.first20) }
        if completed.contains("w9r3") { badges.insert(.graduation) }
        return badges
    }

    /// Badges to celebrate on the summary screen: earned now and not unlocked before.
    public static func newlyEarned(completed: Set<String>, alreadyUnlocked: Set<Badge>) -> [Badge] {
        let fresh = earned(completed: completed).subtracting(alreadyUnlocked)
        return allCases.filter(fresh.contains)
    }
}
