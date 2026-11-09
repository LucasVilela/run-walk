/// One block of a workout: warm-up, run, walk or cool-down, with a fixed length.
public enum SegmentKind: String, Codable, Sendable, CaseIterable {
    case warmup, run, walk, cooldown

    /// The word shown on screen. The app never relies on color alone.
    public var label: String {
        switch self {
        case .warmup: "WARM-UP"
        case .run: "RUN"
        case .walk: "WALK"
        case .cooldown: "COOL-DOWN"
        }
    }

    /// Lower-case word for sentences, e.g. "Next: Walk 1:30".
    public var name: String {
        switch self {
        case .warmup: "Warm-up"
        case .run: "Run"
        case .walk: "Walk"
        case .cooldown: "Cool-down"
        }
    }
}

public struct Segment: Codable, Hashable, Sendable {
    public let kind: SegmentKind
    public let seconds: Int

    public init(_ kind: SegmentKind, _ seconds: Int) {
        self.kind = kind
        self.seconds = seconds
    }
}
