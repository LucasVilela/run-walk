import RunKit
import SwiftUI

/// Every day, grouped by week: what you ran on past days and what's planned ahead.
/// Past runs open their detail; planned runs call `onPlanned` (the preview sheet) when given.
struct DayByDayList: View {
    @Environment(AppModel.self) private var model
    var onPlanned: ((Workout) -> Void)?

    var body: some View {
        let weeks = groupedByWeek(model.days)
        ScrollViewReader { proxy in
            List {
                ForEach(weeks, id: \.start) { week in
                    Section {
                        ForEach(week.days) { day in
                            row(day)
                        }
                    } header: {
                        Text(weekTitle(week.start))
                            .font(Theme.small.weight(.semibold))
                            .foregroundStyle(Theme.secondaryText)
                            .id(week.start)
                    }
                    .listRowBackground(Theme.card)
                    .listRowSeparatorTint(Theme.hairline)
                }
            }
            .scrollContentBackground(.hidden)
            .onAppear {
                // Open on the current week, with its header showing.
                if let week = weeks.first(where: { $0.days.contains(where: \.isToday) }) {
                    proxy.scrollTo(week.start, anchor: .top)
                }
            }
        }
    }

    @ViewBuilder private func row(_ day: DayEntry) -> some View {
        switch day.kind {
        case .ran(let runs):
            ForEach(Array(runs.enumerated()), id: \.element.id) { i, run in
                // A second run on the same day leaves the date column empty.
                NavigationLink(value: run) {
                    DayRow(day: day, content: .ran(run, unit: unit), firstOfDay: i == 0)
                }
            }
        case .planned(let workout):
            if let onPlanned {
                Button {
                    onPlanned(workout)
                } label: {
                    DayRow(day: day, content: .planned(workout, minutes: model.totalSeconds(workout)))
                }
                .buttonStyle(.plain)
            } else {
                DayRow(day: day, content: .planned(workout, minutes: model.totalSeconds(workout)))
            }
        case .rest:
            DayRow(day: day, content: .rest)
        }
    }

    private var unit: DistanceUnit { model.settings?.units ?? .km }

    /// "This week", "Next week", "Last week", otherwise "Week of 16 November".
    private func weekTitle(_ start: Date) -> String {
        var calendar = model.calendar
        calendar.firstWeekday = 2
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: model.now)?.start ?? model.now
        switch calendar.dateComponents([.day], from: thisWeek, to: start).day ?? 0 {
        case 0: return "This week"
        case 7: return "Next week"
        case -7: return "Last week"
        default: return "Week of \(start.formatted(.dateTime.day().month(.wide)))"
        }
    }

    /// Monday-first weeks.
    private func groupedByWeek(_ days: [DayEntry]) -> [(start: Date, days: [DayEntry])] {
        var calendar = model.calendar
        calendar.firstWeekday = 2
        var weeks: [(start: Date, days: [DayEntry])] = []
        for day in days {
            let start = calendar.dateInterval(of: .weekOfYear, for: day.date)?.start ?? day.date
            if weeks.last?.start == start {
                weeks[weeks.count - 1].days.append(day)
            } else {
                weeks.append((start, [day]))
            }
        }
        return weeks
    }
}

private struct DayRow: View {
    enum Content {
        case ran(RunRecord, unit: DistanceUnit)
        case planned(Workout, minutes: Int)
        case rest
    }

    let day: DayEntry
    let content: Content
    var firstOfDay = true

    var body: some View {
        HStack(spacing: Theme.Space.m) {
            VStack(spacing: 0) {
                Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(Theme.small)
                    .foregroundStyle(Theme.secondaryText)
                Text(day.date.formatted(.dateTime.day()))
                    .font(Theme.font(.title3, weight: .semibold))
                    .monospacedDigit()
            }
            .frame(minWidth: 44)
            .opacity(firstOfDay ? 1 : 0)
            icon
                .font(.title3)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Theme.Space.s) {
                    Text(title).font(Theme.body.weight(isRest ? .regular : .semibold))
                    if day.isToday && firstOfDay {
                        Text("Today")
                            .font(Theme.small.weight(.semibold))
                            .padding(.horizontal, Theme.Space.s)
                            .padding(.vertical, 2)
                            .foregroundStyle(Theme.onAccent)
                            .background(Theme.accent, in: Capsule())
                    }
                }
                if let detail {
                    Text(detail).font(Theme.small).foregroundStyle(Theme.secondaryText)
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(isRest ? Theme.secondaryText : Theme.text)
        .frame(minHeight: Theme.minTarget)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var isRest: Bool { if case .rest = content { true } else { false } }

    @ViewBuilder private var icon: some View {
        switch content {
        case .ran(let run, _):
            Image(systemName: run.counted ? "checkmark.circle.fill" : "circle.dashed")
                .symbolRenderingMode(.palette)
                .foregroundStyle(Theme.onColor, Theme.walk)
        case .planned:
            Image(systemName: "figure.run.circle").foregroundStyle(Theme.run)
        case .rest:
            Image(systemName: "moon.zzz").foregroundStyle(Theme.secondaryText)
        }
    }

    private var title: String {
        switch content {
        case .ran(let run, _): run.workout?.title ?? "Run"
        case .planned(let workout, _): workout.title
        case .rest: "Rest"
        }
    }

    private var detail: String? {
        switch content {
        case .ran(let run, let unit):
            var parts = [Format.clock(run.movingSec)]
            if let distance = run.distanceM { parts.append(Format.distance(meters: distance, unit: unit)) }
            if let feeling = run.feeling { parts.append(feelingText(feeling)) }
            if !run.counted { parts.append("not counted") }
            return parts.joined(separator: " · ")
        case .planned(_, let seconds):
            return "\(Format.minutes(seconds)) · planned"
        case .rest:
            return nil
        }
    }

    private func feelingText(_ feeling: Feeling) -> String {
        switch feeling {
        case .easy: "felt easy"
        case .right: "felt just right"
        case .hard: "felt hard"
        }
    }

    private var accessibilityText: String {
        let date = day.date.formatted(.dateTime.weekday(.wide).day().month(.wide))
        let today = day.isToday ? "today, " : ""
        return "\(today)\(date): \(title)" + (detail.map { ", \($0)" } ?? "")
    }
}
