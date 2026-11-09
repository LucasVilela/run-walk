import Foundation
import Testing

@testable import RunKit

@Suite struct DayByDayTests {
    func days(_ runs: [RunRecord] = [], completed: Set<String> = [], now: Date, last: Date? = nil)
        -> [DayEntry]
    {
        DayByDay.days(
            settings: Cal.settings, runs: runs, completed: completed, now: now, lastCompletedAt: last,
            calendar: Cal.calendar)
    }

    func entry(_ list: [DayEntry], _ month: Int, _ day: Int) -> DayEntry? {
        list.first { $0.date == Cal.day(month, day) }
    }

    @Test func freshPlanCoversEveryDayToTheFinish() throws {
        let list = days(now: Cal.date(11, 9))
        #expect(list.first?.date == Cal.day(11, 9))
        #expect(list.last?.date == Cal.day(1, 9, year: 2027), "forecast finish")
        #expect(list.count == 62)
        #expect(list.filter { if case .planned = $0.kind { true } else { false } }.count == 27)
        #expect(entry(list, 11, 9)?.kind == .planned(Program.workouts[0]))
        #expect(entry(list, 11, 9)?.isToday == true)
        #expect(entry(list, 11, 10)?.kind == .rest)
        #expect(entry(list, 11, 11)?.kind == .planned(Program.workouts[1]))
    }

    @Test func pastDaysShowWhatYouRanAndSkippedDaysAreRest() throws {
        let monday = Cal.run("a", "w1r1", ended: Cal.date(11, 9, 8))
        let list = days([monday], completed: ["w1r1"], now: Cal.date(11, 13), last: monday.endedAt)
        #expect(entry(list, 11, 9)?.kind == .ran([monday]))
        #expect(entry(list, 11, 11)?.kind == .rest, "a skipped run day is rest, never 'missed'")
        #expect(entry(list, 11, 13)?.kind == .rest)
        #expect(entry(list, 11, 13)?.isToday == true)
        #expect(entry(list, 11, 14)?.kind == .planned(Program.workouts[1]), "the missed run slid forward")
    }

    @Test func runAnywayOnARestDayAndTwoRunsInADay() {
        let sunday = Cal.run("a", "w1r1", ended: Cal.date(11, 8, 9))
        let first = Cal.run("b", "w1r2", ended: Cal.date(11, 10, 7))
        let second = Cal.run("c", "w1r2", ended: Cal.date(11, 10, 18))
        let list = days(
            [second, sunday, first], completed: ["w1r1", "w1r2"], now: Cal.date(11, 10, 19),
            last: second.endedAt)
        #expect(list.first?.date == Cal.day(11, 8), "starts at the first run, before the start date")
        #expect(entry(list, 11, 8)?.kind == .ran([sunday]))
        #expect(entry(list, 11, 10)?.kind == .ran([first, second]), "oldest first")
        #expect(entry(list, 11, 10)?.isToday == true)
    }

    @Test func finishedPlanEndsToday() {
        let list = days(completed: Cal.ids(through: "w9r3"), now: Cal.date(11, 12))
        #expect(list.last?.date == Cal.day(11, 12))
        #expect(!list.contains { if case .planned = $0.kind { true } else { false } })
    }
}
