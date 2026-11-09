import Foundation
import Testing

@testable import RunKit

@Suite struct CueScheduleTests {
    let plan = RunPlan(workout: Program.workouts[0], warmupSec: 300, cooldownSec: 300)

    @Test func upcomingCuesFromTheStart() {
        let cues = CueSchedule.upcoming(in: plan, position: 0)
        #expect(cues.count == plan.segments.count, "every segment after the warm-up, plus the finish")
        #expect(cues.first == ScheduledCue(index: 1, secondsFromNow: 300))
        #expect(cues.last == ScheduledCue(index: plan.segments.count, secondsFromNow: 1800))
    }

    @Test func upcomingCuesMidRunAndAfterTheEnd() {
        // 310 s in: inside the first run (300–360). Next switch is the walk at 360.
        let cues = CueSchedule.upcoming(in: plan, position: 310)
        #expect(cues.first == ScheduledCue(index: 2, secondsFromNow: 50))
        #expect(CueSchedule.upcoming(in: plan, position: 1800).isEmpty)
    }

    @Test func notificationText() {
        #expect(CueSchedule.text(for: 2, in: plan).title == "Walk 1:30")
        #expect(CueSchedule.text(for: 1, in: plan).body == "Start running. Run for one minute.")
        #expect(CueSchedule.text(for: plan.segments.count, in: plan).title == "Workout complete")
    }
}
