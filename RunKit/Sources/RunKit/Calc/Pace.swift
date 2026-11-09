import Foundation

public enum Pace {
    /// Pace and distance stay "—" until this many metres.
    public static let minDistanceM = 100.0

    /// Seconds per km = moving time ÷ distance. Nil until 100 m, and nil for impossible paces.
    public static func secondsPerKm(movingSec: Double, distanceM: Double) -> Double? {
        guard distanceM >= minDistanceM, movingSec > 0, distanceM.isFinite, movingSec.isFinite else {
            return nil
        }
        let pace = movingSec / (distanceM / 1000)
        return pace <= maxSecPerKm ? pace : nil
    }

    /// Slower than 30 min/km isn't a pace anyone walks: it's bad data, so show "—".
    public static let maxSecPerKm = 1800.0
}

/// Given any two of distance, time and pace, solves the third.
public enum PaceCalculator {
    public enum Field: Sendable, Equatable { case distance, time, pace }

    public enum Failure: Error, Equatable {
        case needExactlyTwo
        case invalid(Field)
        case outOfRange(Field)
    }

    public struct Result: Equatable, Sendable {
        public let distanceM: Double
        public let timeSec: Double
        public let paceSecPerKm: Double
    }

    static let distanceRange = 10.0...100_000
    static let timeRange = 1.0...86_400
    static let paceRange = 120.0...3600  // 2:00 to 60:00 per km

    public static func solve(distanceM: Double?, timeSec: Double?, paceSecPerKm: Double?) throws(Failure)
        -> Result
    {
        let given = [distanceM, timeSec, paceSecPerKm].compactMap { $0 }.count
        guard given == 2 else { throw .needExactlyTwo }
        try validate(distanceM, .distance)
        try validate(timeSec, .time)
        try validate(paceSecPerKm, .pace)

        let result: Result
        if let distanceM, let timeSec {
            result = Result(
                distanceM: distanceM, timeSec: timeSec, paceSecPerKm: timeSec / (distanceM / 1000))
        } else if let distanceM, let paceSecPerKm {
            result = Result(
                distanceM: distanceM, timeSec: paceSecPerKm * distanceM / 1000, paceSecPerKm: paceSecPerKm)
        } else if let timeSec, let paceSecPerKm {
            result = Result(
                distanceM: timeSec / paceSecPerKm * 1000, timeSec: timeSec, paceSecPerKm: paceSecPerKm)
        } else {
            throw .needExactlyTwo
        }
        guard distanceRange.contains(result.distanceM) else { throw .outOfRange(.distance) }
        guard timeRange.contains(result.timeSec) else { throw .outOfRange(.time) }
        guard paceRange.contains(result.paceSecPerKm) else { throw .outOfRange(.pace) }
        return result
    }

    private static func validate(_ value: Double?, _ field: Field) throws(Failure) {
        guard let value else { return }
        guard value.isFinite, value > 0 else { throw .invalid(field) }
    }
}
