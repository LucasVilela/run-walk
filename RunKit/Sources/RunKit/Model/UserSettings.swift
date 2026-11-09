import Foundation

public enum DistanceUnit: String, Codable, Sendable, CaseIterable {
    case km, mi

    /// Metres in one unit.
    public var meters: Double { self == .km ? 1000 : 1609.344 }
    public var label: String { rawValue }
}

/// The single settings row. Weekdays use `Calendar` numbering: 1 = Sunday … 7 = Saturday.
public struct UserSettings: Codable, Equatable, Sendable {
    public static let warmupRange = 180...600
    public static let defaultRunDays: Set<Int> = [2, 4, 7]  // Mon, Wed, Sat

    public var units: DistanceUnit = .km
    public var runDays: Set<Int> = UserSettings.defaultRunDays
    /// Minutes after midnight. Default 7:00.
    public var reminderMinutes: Int = 7 * 60
    public var remindersOn = true
    public var startDate: Date
    public var voiceOn = true
    public var beepsOn = true
    public var hapticsOn = true
    public var warmupSec = 300
    public var cooldownSec = 300
    public var onboardedAt: Date?

    public init(startDate: Date) {
        self.startDate = startDate
    }

    /// Clamps values a user (or an old database row) could get out of range.
    public func sanitized() -> UserSettings {
        var copy = self
        let range = Self.warmupRange
        copy.warmupSec = Swift.min(Swift.max(warmupSec, range.lowerBound), range.upperBound)
        copy.cooldownSec = Swift.min(Swift.max(cooldownSec, range.lowerBound), range.upperBound)
        copy.reminderMinutes = Swift.min(Swift.max(reminderMinutes, 0), 24 * 60 - 1)
        let validDays = runDays.filter { (1...7).contains($0) }
        copy.runDays = validDays.isEmpty ? Self.defaultRunDays : validDays
        return copy
    }
}
