import RunKit
import SwiftUI

/// 9 weeks × 3 runs: done ✓, next ▶, upcoming with forecast dates. Never a "missed" state.
struct PlanView: View {
    @Environment(AppModel.self) private var model
    @State private var preview: Workout?
    @State private var pendingStart: Workout?
    @State private var confirmRepeat = false
    /// "weeks" (the 9×3 grid) or "days" (every day, past and planned). Remembered between launches.
    @AppStorage("planMode") private var mode = "weeks"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                modePicker
                if mode == "days" {
                    DayByDayList { preview = $0 }
                } else {
                    weeks
                }
            }
            .background(Theme.background)
            .navigationTitle("Plan")
            .navigationDestination(for: RunRecord.self) { RunDetailView(run: $0) }
            .sheet(
                item: $preview,
                onDismiss: {
                    if let workout = pendingStart {
                        pendingStart = nil
                        model.start(workout)
                    }
                }
            ) { workout in
                WorkoutPreviewSheet(workout: workout) { pendingStart = $0 }
            }
            .alert("Repeat week \(model.currentWeek)?", isPresented: $confirmRepeat) {
                Button("Repeat week \(model.currentWeek)") { model.repeatWeek(model.currentWeek) }
                Button("Not now", role: .cancel) {}
            } message: {
                Text("Your next run will be week \(model.currentWeek), run 1. Lots of people repeat a week.")
            }
        }
    }

    private var modePicker: some View {
        HStack(spacing: Theme.Space.s) {
            modeChip("weeks", "Weeks")
            modeChip("days", "Day by day")
        }
        .padding(.horizontal, Theme.padding)
        .padding(.vertical, Theme.Space.s)
        .background(Theme.background)
    }

    private func modeChip(_ value: String, _ title: String) -> some View {
        Button {
            mode = value
        } label: {
            ChoiceChip(title: title, selected: mode == value)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(mode == value ? .isSelected : [])
    }

    private var weeks: some View {
        let dates = Dictionary(
            model.forecast.map { ($0.workout.id, $0.date) }, uniquingKeysWith: { a, _ in a })
        return List(Array(Program.weeks), id: \.self) { week in
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                HStack {
                    Text("Week \(week)")
                        .font(Theme.heading)
                    Spacer()
                    if canRepeat(week) {
                        Button {
                            confirmRepeat = true
                        } label: {
                            Label("Repeat this week", systemImage: "arrow.counterclockwise")
                                .font(Theme.small.weight(.semibold))
                                .padding(.horizontal, Theme.Space.m)
                                .frame(minHeight: 36)
                                .background(Theme.quietFill, in: Capsule())
                                .frame(minHeight: Theme.minTarget)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(Theme.text)
                    }
                }
                HStack(alignment: .top, spacing: Theme.Space.m) {
                    ForEach(Program.workouts(inWeek: week)) { workout in
                        RunChip(workout: workout, state: state(of: workout), date: dates[workout.id]) {
                            preview = workout
                        }
                    }
                }
            }
            .padding(.vertical, Theme.Space.s)
            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            .listRowBackground(Theme.card)
            .listRowSeparatorTint(Theme.hairline)
        }
        .scrollContentBackground(.hidden)
    }

    private func state(of workout: Workout) -> RunChip.State {
        if workout.id == model.nextWorkout?.id { return .next }
        return model.completed.contains(workout.id) ? .done : .upcoming
    }

    private func canRepeat(_ week: Int) -> Bool {
        week == model.currentWeek
            && Program.workouts(inWeek: week).contains { model.completed.contains($0.id) }
    }
}

private struct RunChip: View {
    enum State { case done, next, upcoming }

    let workout: Workout
    let state: State
    let date: Date?
    let action: () -> Void
    @ScaledMetric(relativeTo: .body) private var dot: CGFloat = 52

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Space.s) {
                ZStack {
                    switch state {
                    case .done:
                        Circle().fill(Theme.walk)
                        Image(systemName: "checkmark")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Theme.onColor)
                    case .next:
                        Circle().fill(Theme.text)
                        Image(systemName: "play.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.background)
                    case .upcoming:
                        Circle().fill(Theme.card)
                        Circle().strokeBorder(Theme.text.opacity(0.3), lineWidth: 2)
                        Text("\(workout.run)")
                            .font(Theme.body.weight(.semibold))
                            .monospacedDigit()
                    }
                }
                // Grows with text size, but three must still fit across the card.
                .frame(width: min(dot, 76), height: min(dot, 76))
                Text(state == .done ? "Run \(workout.run)" : (date.map(DateText.chip) ?? " "))
                    .font(Theme.small.weight(state == .next ? .semibold : .regular))
                    .foregroundStyle(state == .next ? Theme.text : Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(workout.title), \(accessibilityState)")
        .accessibilityHint("Shows the run")
    }

    private var accessibilityState: String {
        switch state {
        case .done: "done"
        case .next: "next"
        case .upcoming:
            date.map { "planned for \($0.formatted(.dateTime.weekday(.wide).day().month()))" } ?? "upcoming"
        }
    }
}
