import RunKit
import SwiftUI

/// One obvious next step: the next run and one big Start button.
struct TodayView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                content
                    .padding(.horizontal, Theme.padding)
                    .padding(.bottom, Theme.padding)
            }
            .scrollBounceBehavior(.basedOnSize)
            // The one obvious next step stays on screen at every text size.
            .bottomBar {
                VStack(spacing: Theme.Space.s) {
                    progressLine
                    primaryButton
                }
            }
            .foregroundStyle(Theme.text)
            .background(Theme.background)
            .navigationTitle("Today")
            .otherRunMenu()
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xl) {
            if let suggestion = model.suggestion { CoachCard(suggestion: suggestion) }
            switch model.today {
            case .run(let workout):
                WorkoutCard(workout: workout)
            case .rest(let workout, let date):
                Label {
                    Text(
                        "Rest day — next run \(DateText.day(date, from: model.now, calendar: model.calendar))"
                    )
                } icon: {
                    Image(systemName: "moon.zzz")
                        .foregroundStyle(Theme.walk)
                }
                .font(Theme.title)
                WorkoutCard(workout: workout)
                if model.isResting {
                    Text(
                        "You ran less than a day ago. Resting helps your legs get stronger, but it's your call."
                    )
                    .font(Theme.small)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
            case .finished:
                finished
            }
        }
    }

    @ViewBuilder private var primaryButton: some View {
        switch model.today {
        case .run(let workout):
            Button("Start") { model.start(workout) }
                .buttonStyle(BigButtonStyle())
                .accessibilityHint("Starts \(workout.title)")
        case .rest(let workout, _):
            Button("Run anyway") { model.start(workout) }
                .buttonStyle(SecondaryButtonStyle())
        case .finished:
            if let last = Program.workouts.last {
                Button("Do a 30-minute run") { model.start(last) }
                    .buttonStyle(BigButtonStyle())
            }
        }
    }

    private var progressLine: some View {
        let done = model.runsDone
        var text = "\(done) of \(Program.workouts.count) runs"
        if let finish = model.forecast.last?.date { text += " · forecast finish \(DateText.short(finish))" }
        return Text(text)
            .font(Theme.small)
            .monospacedDigit()
            .foregroundStyle(Theme.secondaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private var finished: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                Image(systemName: "medal.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.run)
                    .accessibilityHidden(true)
                Text("You finished the plan")
                    .font(Theme.title)
                Text("You can run for 30 minutes now. Three easy runs a week keeps it that way.")
                    .font(Theme.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .card()
        }
    }
}

/// "Week 3 · Run 2", total time, segment bar and the tip of the week.
struct WorkoutCard: View {
    @Environment(AppModel.self) private var model
    let workout: Workout

    var body: some View {
        let settings = model.settings ?? UserSettings(startDate: .now)
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text(workout.title)
                    .font(Theme.screenTitle)
                Label("\(Format.minutes(model.totalSeconds(workout))) incl. warm-up", systemImage: "clock")
                    .font(Theme.body)
                    .monospacedDigit()
                    .foregroundStyle(Theme.secondaryText)
            }
            SegmentBar(
                segments: workout.segments(warmupSec: settings.warmupSec, cooldownSec: settings.cooldownSec)
            )
            .frame(height: 28)
            SegmentLegend()
            Divider()
            Label {
                Text(Tips.tip(for: workout))
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(Theme.run)
            }
            .font(Theme.body)
        }
        .card()
    }
}
