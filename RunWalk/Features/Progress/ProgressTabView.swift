import RunKit
import SwiftUI

/// Stats, weekly chart, projected 5K, history, pace calculator and badges.
/// Named ProgressTabView to avoid clashing with SwiftUI's ProgressView.
struct ProgressTabView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.xl) {
                    if model.runs.isEmpty {
                        firstRunCard
                    } else {
                        StatsGridCard(stats: model.stats, unit: unit)
                        WeeklyChartCard(secondsPerWeek: Stats.runningSecondsPerWeek(runs: model.runs))
                        history
                    }
                    PaceCalculatorCard(unit: unit)
                    BadgesGrid(earned: model.badges)
                }
                .padding(.horizontal, Theme.padding)
                .padding(.bottom, Theme.padding)
            }
            .foregroundStyle(Theme.text)
            .background(Theme.background)
            .navigationTitle("Progress")
            .otherRunMenu()
            .navigationDestination(for: RunRecord.self) { RunDetailView(run: $0) }
        }
    }

    private var unit: DistanceUnit { model.settings?.units ?? .km }

    private var firstRunCard: some View {
        Label {
            Text("Your first run unlocks your stats.")
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "chart.bar.fill").foregroundStyle(Theme.walk)
        }
        .font(Theme.body)
        .card()
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            HStack {
                Text("Your runs").font(Theme.heading)
                Spacer()
                NavigationLink {
                    DayByDayList()
                        .background(Theme.background)
                        .navigationTitle("Day by day")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label("Day by day", systemImage: "calendar")
                        .font(Theme.small.weight(.semibold))
                        .padding(.horizontal, Theme.Space.m)
                        .frame(minHeight: 36)
                        .background(Theme.quietFill, in: Capsule())
                        .frame(minHeight: Theme.minTarget)
                }
                .buttonStyle(.plain)
            }
            VStack(spacing: 0) {
                ForEach(Array(model.runs.enumerated()), id: \.element.id) { i, run in
                    if i > 0 { Divider() }
                    NavigationLink(value: run) { HistoryRow(run: run, unit: unit) }
                        .buttonStyle(.plain)
                }
            }
            .card(padding: Theme.Space.l)
        }
    }
}

/// Runs done, other runs (if any), distance, running time, longest non-stop run and best pace.
private struct StatsGridCard: View {
    let stats: Stats
    let unit: DistanceUnit

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), alignment: .leading)], spacing: Theme.Space.l) {
            ForEach(items, id: \.0) { StatValue(label: $0.0, value: $0.1) }
        }
        .card()
    }

    private var items: [(String, String)] {
        var items = [
            ("Runs done", "\(stats.runsDone) / \(Program.workouts.count)"),
            ("Distance", Format.distance(meters: stats.totalDistanceM, unit: unit)),
            ("Running time", Format.clock(stats.totalRunningSec)),
            ("Longest non-stop", Format.minutes(stats.longestNonStopSec)),
            ("Best avg pace", Format.pace(secondsPerKm: stats.bestAvgPaceSecPerKm, unit: unit)),
        ]
        if stats.otherRuns > 0 { items.insert(("Other runs", "\(stats.otherRuns)"), at: 1) }
        return items
    }
}

private struct HistoryRow: View {
    let run: RunRecord
    let unit: DistanceUnit

    var body: some View {
        HStack(spacing: Theme.Space.m) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text(run.title).font(Theme.body.weight(.semibold))
                Text(details).font(Theme.small).foregroundStyle(Theme.secondaryText)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(Theme.small.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
                .accessibilityHidden(true)
        }
        .frame(minHeight: Theme.minTarget)
        .padding(.vertical, Theme.Space.s)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var details: String {
        var parts = [run.startedAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))]
        parts.append(Format.clock(run.movingSec))
        if let distance = run.distanceM { parts.append(Format.distance(meters: distance, unit: unit)) }
        if !run.counted && !run.isOther { parts.append("not counted") }
        return parts.joined(separator: " · ")
    }
}
