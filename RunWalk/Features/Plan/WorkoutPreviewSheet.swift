import RunKit
import SwiftUI

/// Segment list, total time, and Start (next run) or "Do this run instead" (any earlier run).
struct WorkoutPreviewSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let workout: Workout
    let start: (Workout) -> Void

    var body: some View {
        let settings = model.settings ?? UserSettings(startDate: .now)
        let segments = workout.segments(warmupSec: settings.warmupSec, cooldownSec: settings.cooldownSec)
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: Theme.Space.m) {
                        SegmentBar(segments: segments)
                            .frame(height: 24)
                        SegmentLegend()
                    }
                    .padding(.vertical, Theme.Space.s)
                    Label(
                        "\(Format.minutes(model.totalSeconds(workout))) including warm-up and cool-down",
                        systemImage: "clock"
                    )
                    .font(Theme.body)
                    .monospacedDigit()
                }
                .listRowBackground(Theme.card)
                Section {
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                        HStack(spacing: Theme.Space.m) {
                            RoundedRectangle(cornerRadius: Theme.barCorner, style: .continuous)
                                .fill(Theme.color(for: segment.kind))
                                .frame(width: 12, height: 24)
                                .accessibilityHidden(true)
                            Text(segment.kind.name)
                            Spacer()
                            Text(Format.clock(segment.seconds))
                                .monospacedDigit()
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .font(Theme.body)
                        .frame(minHeight: Theme.minTarget - 8)
                        .accessibilityElement(children: .combine)
                    }
                } header: {
                    Text("Segments")
                        .font(Theme.small.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
                .listRowBackground(Theme.card)
                .listRowSeparatorTint(Theme.hairline)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .foregroundStyle(Theme.text)
            .navigationTitle(workout.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .bottomBar { action }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder private var action: some View {
        let nextIndex = model.nextWorkout.flatMap { Program.index(of: $0.id) } ?? Program.workouts.count
        let index = Program.index(of: workout.id) ?? 0
        if index == nextIndex {
            Button("Start") { go() }
                .buttonStyle(BigButtonStyle())
        } else if index < nextIndex {
            Button("Do this run instead") { go() }
                .buttonStyle(BigButtonStyle())
        } else if let next = model.nextWorkout {
            Label("Comes after \(next.title).", systemImage: "calendar")
                .font(Theme.body)
                .foregroundStyle(Theme.secondaryText)
                .frame(maxWidth: .infinity, minHeight: Theme.minTarget)
        }
    }

    private func go() {
        start(workout)
        dismiss()
    }
}
