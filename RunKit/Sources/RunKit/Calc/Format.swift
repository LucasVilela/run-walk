import Foundation

/// Plain-text formatting for times, paces and distances. "—" means "not enough data yet".
public enum Format {
    public static let none = "—"

    /// "1:30", "25:00", "1:02:05".
    public static func clock(_ seconds: Int) -> String {
        let s = Swift.max(0, seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }

    /// Parses "m:ss", "h:mm:ss" or plain minutes ("34") into seconds. Nil if invalid.
    public static func parseClock(_ text: String) -> Int? {
        let parts = text.trimmingCharacters(in: .whitespaces).split(
            separator: ":", omittingEmptySubsequences: false)
        guard (1...3).contains(parts.count) else { return nil }
        let values = parts.compactMap { Int($0) }.filter { $0 >= 0 }
        guard values.count == parts.count else { return nil }
        switch values.count {
        case 1: return values[0] * 60
        case 2: return values[1] < 60 ? values[0] * 60 + values[1] : nil
        default: return values[1] < 60 && values[2] < 60 ? values[0] * 3600 + values[1] * 60 + values[2] : nil
        }
    }

    /// "6:05 /km" or "9:47 /mi". Nil pace shows "—".
    public static func pace(secondsPerKm: Double?, unit: DistanceUnit) -> String {
        guard let secondsPerKm, secondsPerKm.isFinite, secondsPerKm > 0 else { return none }
        let perUnit = Int((secondsPerKm * unit.meters / 1000).rounded())
        return "\(clock(perUnit)) /\(unit.label)"
    }

    /// "2.45 km". Nil distance shows "—".
    public static func distance(meters: Double?, unit: DistanceUnit) -> String {
        guard let meters, meters.isFinite, meters >= 0 else { return none }
        return String(format: "%.2f %@", meters / unit.meters, unit.label)
    }

    /// Whole minutes, rounded: "28 min".
    public static func minutes(_ seconds: Int) -> String {
        "\(Int((Double(seconds) / 60).rounded())) min"
    }

    /// An estimate, clearly labelled as one: "about 34 min".
    public static func estimate(_ seconds: Double) -> String {
        "about \(minutes(Int(seconds.rounded())))"
    }
}
