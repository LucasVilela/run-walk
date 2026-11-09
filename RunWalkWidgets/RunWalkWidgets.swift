import RunKit
import SwiftUI
import WidgetKit

@main
struct RunWalkWidgets: WidgetBundle {
    var body: some Widget {
        NextRunWidget()
        RunLiveActivity()
    }
}

/// Colours for the widgets (the app's Calm look). Lock-screen widgets are tinted by iOS anyway.
enum WidgetColors {
    static let run = Color(red: 1, green: 0.42, blue: 0.29)
    static let walk = Color(red: 0.17, green: 0.70, blue: 0.64)
    static let easy = Color(red: 0.42, green: 0.48, blue: 0.56)

    static func color(for kind: SegmentKind) -> Color {
        switch kind {
        case .run: run
        case .walk: walk
        case .warmup, .cooldown: easy
        }
    }
}

// MARK: - Timeline

struct RunEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    /// During a run: the segment on screen at `date`, and the one after it.
    var segment: WidgetSnapshot.LiveSegment?
    var nextSegment: WidgetSnapshot.LiveSegment?
}

/// During a run, one entry per segment: iOS switches entries at their dates, so the widget shows the
/// right segment even while the app is asleep. Otherwise one entry for the next run.
struct RunProvider: TimelineProvider {
    func placeholder(in context: Context) -> RunEntry {
        RunEntry(
            date: .now,
            snapshot: WidgetSnapshot(
                next: .init(title: "Week 1 · Run 1", date: .now, minutes: 30), runsDone: 0))
    }

    func getSnapshot(in context: Context, completion: @escaping (RunEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entries(now: .now).first!)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RunEntry>) -> Void) {
        let list = entries(now: .now)
        // Refresh after midnight so "today" / "tomorrow" stay right.
        let midnight = Calendar.current.startOfDay(for: .now).addingTimeInterval(86_400 + 60)
        completion(Timeline(entries: list, policy: .after(min(midnight, (list.last?.date ?? .now) + 3600))))
    }

    private func entries(now: Date) -> [RunEntry] {
        let snapshot = WidgetShared.load()
        guard let active = snapshot?.active, active.paused == nil else {
            return [RunEntry(date: now, snapshot: snapshot)]
        }
        let upcoming = active.segments.filter { $0.end > now }
        guard !upcoming.isEmpty else { return [RunEntry(date: now, snapshot: idle(snapshot))] }
        var list = upcoming.enumerated().map { i, segment in
            RunEntry(
                date: max(segment.start, now), snapshot: snapshot, segment: segment,
                nextSegment: i + 1 < upcoming.count ? upcoming[i + 1] : nil)
        }
        // After the last segment, fall back to "next run" until the app updates it.
        list.append(RunEntry(date: upcoming.last!.end, snapshot: idle(snapshot)))
        return list
    }

    private func idle(_ snapshot: WidgetSnapshot?) -> WidgetSnapshot? {
        var copy = snapshot
        copy?.active = nil
        return copy
    }
}

// MARK: - Widget

struct NextRunWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetShared.kind, provider: RunProvider()) { entry in
            RunWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Run-Walk")
        .description("Your next run, and the current segment during a run.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline, .systemSmall])
    }
}

struct RunWidgetView: View {
    @Environment(\.widgetFamily) private var family
    /// Always-on lock screen: timer seconds are blanked, so show when the segment ends instead.
    @Environment(\.isLuminanceReduced) private var dimmed
    let entry: RunEntry

    var body: some View {
        if let segment = entry.segment {
            running(segment)
        } else if let paused = entry.snapshot?.active?.paused {
            pausedView(paused)
        } else {
            idle
        }
    }

    // MARK: Running

    @ViewBuilder private func running(_ segment: WidgetSnapshot.LiveSegment) -> some View {
        let interval = segment.start...segment.end
        switch family {
        case .accessoryInline:
            Text("\(segment.kind.name) · \(Text(timerInterval: interval, countsDown: true))")
        case .accessoryCircular:
            ProgressView(timerInterval: interval, countsDown: true) {
                Text(segment.kind.label.prefix(4))
            } currentValueLabel: {
                Text(segment.kind.label.prefix(4)).font(.system(size: 11, weight: .heavy))
            }
            .progressViewStyle(.circular)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(segment.kind.label).font(.headline.weight(.heavy))
                    if dimmed {
                        Text("until \(Text(segment.end, style: .time))").font(.caption)
                    } else {
                        Text(timerInterval: interval, countsDown: true)
                            .font(.headline.monospacedDigit())
                            .multilineTextAlignment(.trailing)
                    }
                }
                Text(nextText).font(.caption)
                ProgressView(
                    timerInterval: interval, countsDown: false, label: { EmptyView() },
                    currentValueLabel: { EmptyView() })
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.snapshot?.active?.title ?? "").font(.caption).foregroundStyle(.secondary)
                Text(segment.kind.label)
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(WidgetColors.color(for: segment.kind))
                Text(timerInterval: interval, countsDown: true)
                    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                Text(nextText).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var nextText: String {
        guard let next = entry.nextSegment else { return "Last stretch" }
        return "Next: \(next.kind.name) \(Format.clock(next.seconds))"
    }

    // MARK: Paused

    @ViewBuilder private func pausedView(_ paused: WidgetSnapshot.Paused) -> some View {
        switch family {
        case .accessoryInline:
            Text("Paused · \(paused.kind.name) \(Format.clock(paused.segmentRemaining)) left")
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "pause.fill").font(.title3)
            }
        default:
            VStack(alignment: .leading, spacing: 2) {
                Label("Paused", systemImage: "pause.fill").font(.headline)
                Text("\(paused.kind.name) · \(Format.clock(paused.segmentRemaining)) left").font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Idle

    @ViewBuilder private var idle: some View {
        let snapshot = entry.snapshot
        switch family {
        case .accessoryInline:
            if let next = snapshot?.next {
                Text("\(day(next.date)) · \(next.title)")
            } else {
                Text("Run-Walk")
            }
        case .accessoryCircular:
            Gauge(value: Double(snapshot?.runsDone ?? 0), in: 0...Double(snapshot?.total ?? 27)) {
                Image(systemName: "figure.run")
            } currentValueLabel: {
                Text("\(snapshot?.runsDone ?? 0)")
            }
            .gaugeStyle(.accessoryCircular)
        default:
            VStack(alignment: .leading, spacing: 2) {
                if let next = snapshot?.next {
                    Text(day(next.date).uppercased()).font(.caption.weight(.semibold))
                    Text(next.title).font(.headline)
                    Text("\(next.minutes) min · \(snapshot?.runsDone ?? 0) of \(snapshot?.total ?? 27) done")
                        .font(.caption)
                } else if snapshot != nil {
                    Text("Plan complete").font(.headline)
                    Text("You can run for 30 minutes.").font(.caption)
                } else {
                    Text("Run-Walk").font(.headline)
                    Text("Open the app to start.").font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func day(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.wide))
    }
}
