import Foundation
import Testing

@testable import RunKit

/// Fake clock: `t(90)` is 90 seconds after the run started.
private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
private func t(_ seconds: Double) -> Date { t0.addingTimeInterval(seconds) }

private func plan(_ id: String, warmup: Int = 300, cooldown: Int = 300) -> RunPlan {
    RunPlan(workout: Program.workout(id: id)!, warmupSec: warmup, cooldownSec: cooldown)
}

private func started(_ id: String) -> RunEngine {
    var engine = RunEngine(plan: plan(id))
    _ = engine.start(at: t0)
    return engine
}

/// Ticks every 250 ms from `from` to `to`, collecting every cue.
private func tickThrough(_ engine: inout RunEngine, from: Double, to: Double) -> [CueEvent] {
    var events: [CueEvent] = []
    var s = from
    while s <= to {
        events += engine.tick(at: t(s))
        s += 0.25
    }
    return events
}

@Suite struct EngineTests {
    @Test func startsInWarmup() {
        var engine = RunEngine(plan: plan("w1r1"))
        #expect(engine.phase == .idle)
        #expect(engine.start(at: t0) == [.segmentStart(index: 0)])
        #expect(engine.start(at: t(1)).isEmpty, "can't start twice")
        let snap = engine.snapshot(at: t(10))
        #expect(snap.segment == Segment(.warmup, 300))
        #expect(snap.segmentRemaining == 290)
        #expect(snap.next == Segment(.run, 60))
        #expect(snap.remainingSec == 1790)
    }

    @Test func fullWorkoutTickByTickWeek1() {
        var engine = started("w1r1")
        let events = tickThrough(&engine, from: 0.25, to: 1805)
        let segmentCount = engine.plan.segments.count  // warm-up + 16 + cool-down
        let starts = events.filter { if case .segmentStart = $0 { true } else { false } }
        #expect(starts.count == segmentCount - 1)
        #expect(events.filter { $0 == .countdown(3) }.count == segmentCount)
        #expect(events.filter { $0 == .countdown(1) }.count == segmentCount)
        #expect(events.last == .finished(early: false))
        #expect(events.filter { $0 == .finished(early: false) }.count == 1)
        #expect(!events.contains { if case .halfway = $0 { true } else { false } }, "runs are under 3:00")
        #expect(engine.phase == .finished)
        #expect(engine.endedAt == t(1800))
        #expect(engine.completionPct(at: t(1900)) == 100)
        #expect(engine.runningSec(at: t(1900)) == 480)
    }

    @Test func halfwayAndOneMinuteCues() {
        // Week 3: run 1:30, walk 1:30, run 3:00, walk 3:00 (×2). The 3:00 runs get both cues.
        var engine = started("w3r1")
        let events = tickThrough(&engine, from: 0.25, to: 600)
        // First 3:00 run starts at 300 + 180 = 480 → halfway at 570, one minute to go at 600.
        #expect(events.contains(.halfway(index: 3)))
        #expect(events.contains(.oneMinute(index: 3)))
        #expect(!events.contains(.halfway(index: 1)), "1:30 run is too short for halfway")
        #expect(!events.contains(.oneMinute(index: 1)), "1:30 run is too short for one minute")
    }

    @Test func cueMarksForANonStopRun() {
        let marks = CueTimeline.marks(for: plan("w5r3"))
        #expect(marks.contains { $0.at == 900 && $0.event == .halfway(index: 1) })
        #expect(marks.contains { $0.at == 1440 && $0.event == .oneMinute(index: 1) })
        #expect(marks.filter { $0.event == .countdown(2) }.count == 3)
    }

    @Test func twoMinutePauseKeepsSegmentTimesCorrect() {
        var engine = started("w1r1")
        _ = tickThrough(&engine, from: 0.25, to: 400)
        #expect(engine.pause(at: t(400)) == [.paused])
        #expect(engine.phase == .paused)
        #expect(engine.snapshot(at: t(500)).movingSec == 400, "clock stands still while paused")
        #expect(engine.tick(at: t(510)).isEmpty)
        let resumed = engine.resume(at: t(520))
        // 400 s in: warm-up 300, run 60 (to 360), walk 90 (to 450) → 50 s of walk left.
        #expect(resumed == [.resumed(index: 2, remainingSec: 50)])
        let snap = engine.snapshot(at: t(530))
        #expect(snap.movingSec == 410)
        #expect(snap.segment.kind == .walk)
        #expect(snap.segmentRemaining == 40)
        let events = tickThrough(&engine, from: 530, to: 571)
        #expect(events.contains(.segmentStart(index: 3)))
        #expect(engine.snapshot(at: t(571)).segmentRemaining == 59, "next run started at 570")
    }

    @Test func skipJumpsToTheNextSegmentAndDoesNotCount() {
        var engine = started("w1r1")
        _ = tickThrough(&engine, from: 0.25, to: 310)
        #expect(engine.skip(at: t(310)) == [.segmentStart(index: 2)])
        let snap = engine.snapshot(at: t(310))
        #expect(snap.segment.kind == .walk)
        #expect(snap.segmentRemaining == 90)
        #expect(engine.runningSec(at: t(310)) == 10, "only 10 s of that run were done")
        #expect(engine.completionPct(at: t(310)) == 10.0 / 1200 * 100)
        let events = tickThrough(&engine, from: 310.25, to: 400.25)
        #expect(events.first == .countdown(3))
        #expect(events.contains(.segmentStart(index: 3)))
        #expect(!events.contains(.segmentStart(index: 2)), "the skipped-to segment isn't announced twice")
    }

    @Test func skippingTheCooldownFinishes() {
        var engine = started("w1r1")
        _ = engine.tick(at: t(1600))
        #expect(engine.skip(at: t(1600)) == [.finished(early: false)])
        #expect(engine.phase == .finished)
        #expect(engine.completionPct(at: t(1600)) == 100)
    }

    @Test func endEarlyAsksWithPercentAndFreezes() {
        var engine = started("w1r1")
        _ = engine.tick(at: t(300 + 768))
        // 768 of 1200 main-block seconds done = 64%.
        #expect(engine.snapshot(at: t(1068)).completionPct == 64)
        #expect(engine.end(at: t(1068)) == [.finished(early: true)])
        #expect(engine.endedEarly)
        #expect(!engine.isCounted(at: t(5000)))
        #expect(engine.movingSec(at: t(5000)) == 1068)
        #expect(engine.tick(at: t(5000)).isEmpty)
    }

    @Test func eightyPercentCounts() {
        var engine = started("w1r1")
        _ = engine.pause(at: t(300 + 960))
        _ = engine.end(at: t(2000))
        #expect(engine.completionPct(at: t(2000)) == 80)
        #expect(engine.isCounted(at: t(2000)))
        #expect(engine.movingSec(at: t(2000)) == 1260, "paused time before ending doesn't count")
    }

    @Test func backFromBackgroundAnnouncesOnceWithoutReplaying() {
        var engine = started("w1r1")
        _ = tickThrough(&engine, from: 0.25, to: 100)
        // Locked phone: no ticks until 700. 700 s in: run 7 of 8 pairs… compute via snapshot.
        let events = engine.resync(at: t(700))
        let snap = engine.snapshot(at: t(700))
        #expect(
            events == [.current(index: snap.index, remainingSec: Int(snap.segmentRemaining.rounded(.up)))])
        #expect(engine.tick(at: t(700.25)).isEmpty, "missed cues are not replayed")
    }

    @Test func lateTickFinishesAtTheRightTime() {
        var engine = started("w1r1")
        _ = engine.tick(at: t(1790))
        #expect(engine.tick(at: t(1900)) == [.finished(early: false)])
        #expect(engine.endedAt == t(1800))
        #expect(engine.movingSec(at: t(9999)) == 1800)
        var gone = started("w1r1")
        #expect(gone.resync(at: t(4000)) == [.finished(early: false)])
    }

    @Test func savedStateResumesExactly() throws {
        var engine = started("w4r2")
        _ = tickThrough(&engine, from: 0.25, to: 500)
        _ = engine.pause(at: t(500))
        _ = engine.resume(at: t(560))
        let data = try JSONEncoder().encode(engine)
        var restored = try JSONDecoder().decode(RunEngine.self, from: data)
        #expect(restored == engine)
        #expect(restored.snapshot(at: t(700)) == engine.snapshot(at: t(700)))
        #expect(restored.tick(at: t(560.25)) == engine.tick(at: t(560.25)))
    }

    @Test func coalesceKeepsOnlyWhatMatters() {
        #expect(
            CueTimeline.coalesce([.countdown(3), .countdown(2), .countdown(1), .segmentStart(index: 4)])
                == [.segmentStart(index: 4)])
        #expect(CueTimeline.coalesce([.countdown(3), .countdown(2)]) == [.countdown(2)])
        #expect(
            CueTimeline.coalesce([.segmentStart(index: 1), .finished(early: false)]) == [
                .finished(early: false)
            ])
    }

    @Test func scaledClockChangesSpeedWithoutJumping() {
        var clock = ScaledClock(now: t0)
        #expect(clock.now(real: t(10)) == t(10))
        clock.setSpeed(60, real: t(10))
        #expect(clock.now(real: t(10)) == t(10))
        #expect(clock.now(real: t(11)) == t(70))
        clock.setSpeed(1, real: t(11))
        #expect(clock.now(real: t(12)) == t(71))
    }
}

@Suite struct CueLineTests {
    func line(_ event: CueEvent, _ id: String) -> String? {
        CueLines.line(for: event, plan: plan(id))
    }

    @Test func examplesFromTheBrief() {
        #expect(line(.segmentStart(index: 0), "w2r1") == "Warm up with five minutes of brisk walking.")
        #expect(line(.segmentStart(index: 1), "w2r1") == "Start running. Run for 90 seconds.")
        #expect(line(.segmentStart(index: 2), "w2r1") == "Walk now. Nice work.")
        #expect(line(.halfway(index: 3), "w3r1") == "Halfway there.")
        #expect(line(.segmentStart(index: 17), "w1r1") == "Running's done! Five-minute cool-down walk.")
        #expect(line(.finished(early: false), "w3r2") == "Workout complete. That's week 3, run 2 done.")
    }

    @Test func lastRunOnlyWhenThereAreSeveral() {
        #expect(line(.segmentStart(index: 15), "w1r1") == "Last run — finish strong. Run for one minute.")
        #expect(
            line(.segmentStart(index: 1), "w7r1") == "Run for 25 minutes. Steady and easy, you can do this.")
    }

    @Test func specialRuns() {
        #expect(line(.segmentStart(index: 1), "w5r3")?.contains("first twenty-minute run") == true)
        #expect(line(.segmentStart(index: 1), "w9r3")?.contains("graduation") == true)
        #expect(line(.finished(early: false), "w9r3")?.contains("graduated") == true)
    }

    @Test func variedRunAndWalkLines() {
        #expect(line(.segmentStart(index: 3), "w2r1") == "Time to run. 90 seconds this time.")
        #expect(line(.segmentStart(index: 5), "w2r1") == "Off you go. Run for 90 seconds.")
        #expect(line(.segmentStart(index: 6), "w2r1") == "Walk for two minutes. Well done.")
        #expect(line(.countdown(3), "w2r1") == nil)
    }

    @Test func pauseResumeAndCurrent() {
        #expect(line(.paused, "w1r1") == "Paused. Take your time.")
        #expect(
            line(.resumed(index: 2, remainingSec: 72), "w1r1")
                == "Back to it. Walk, 1 minute 12 seconds left.")
        #expect(line(.current(index: 1, remainingSec: 30), "w1r1") == "You're on a run. 30 seconds left.")
        #expect(line(.finished(early: true), "w1r1") == "Run saved. Well done for getting out there today.")
    }

    @Test func spokenDurations() {
        #expect(CueLines.spoken(90) == "90 seconds")
        #expect(CueLines.spoken(60) == "one minute")
        #expect(CueLines.spoken(180) == "three minutes")
        #expect(CueLines.spoken(150) == "two and a half minutes")
        #expect(CueLines.spoken(1500) == "25 minutes")
        #expect(CueLines.spoken(72) == "1 minute 12 seconds")
    }

    @Test func everyCueInEveryWorkoutHasAShortLine() {
        for workout in Program.workouts {
            let p = RunPlan(workout: workout, warmupSec: 300, cooldownSec: 300)
            var events: [CueEvent] = [.segmentStart(index: 0), .finished(early: false)]
            events += CueTimeline.marks(for: p).map(\.event)
            for event in events {
                guard let text = CueLines.line(for: event, plan: p) else { continue }
                #expect(!text.contains("%"), "\(workout.id): \(text)")
                #expect(text.count <= 80, "\(workout.id): \(text)")
            }
        }
    }
}
