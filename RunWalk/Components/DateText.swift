import Foundation

/// Plain-word dates for the UI, in the user's locale ("Thursday", "14 Jan").
enum DateText {
    /// "today", "tomorrow", "Thursday", or "Thursday 20 Nov" when more than a week away.
    static func day(_ date: Date, from now: Date, calendar: Calendar) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: date).day ?? 0
        switch days {
        case 0: return "today"
        case 1: return "tomorrow"
        case 2...6: return date.formatted(.dateTime.weekday(.wide))
        default: return date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
        }
    }

    /// "14 Jan".
    static func short(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }

    /// "Thu 13", under the Plan chips.
    static func chip(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day())
    }
}
