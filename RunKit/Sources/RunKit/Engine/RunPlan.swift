import Foundation

/// The full list of segments for one run: warm-up + main block + cool-down.
/// Positions are seconds along this timeline (0 … totalSec).
public struct RunPlan: Codable, Equatable, Sendable {
    public let workoutId: String
    public let segments: [Segment]

    public init(workout: Workout, warmupSec: Int, cooldownSec: Int) {
        workoutId = workout.id
        segments = workout.segments(warmupSec: warmupSec, cooldownSec: cooldownSec)
    }

    public init(workoutId: String, segments: [Segment]) {
        self.workoutId = workoutId
        self.segments = segments
    }

    public var workout: Workout? { Program.workout(id: workoutId) }
    public var totalSec: Double { Double(segments.reduce(0) { $0 + $1.seconds }) }

    public func start(of index: Int) -> Double {
        Double(segments.prefix(index).reduce(0) { $0 + $1.seconds })
    }

    public func end(of index: Int) -> Double {
        start(of: index) + Double(segments[index].seconds)
    }

    /// The segment at a position. The end of the run belongs to the last segment.
    public func index(at position: Double) -> Int {
        var end = 0.0
        for (i, segment) in segments.enumerated() {
            end += Double(segment.seconds)
            if position < end { return i }
        }
        return segments.count - 1
    }

    /// Run and walk segments: the main block that the 80% rule measures.
    public var mainIndices: [Int] { segments.indices.filter { isMain(segments[$0].kind) } }
    public var mainSec: Double { Double(mainIndices.reduce(0) { $0 + segments[$1].seconds }) }
    public var runIndices: [Int] { segments.indices.filter { segments[$0].kind == .run } }

    private func isMain(_ kind: SegmentKind) -> Bool { kind == .run || kind == .walk }
}
