import RunKit
import SwiftUI
import UserNotifications

/// Three short steps: welcome + safety, schedule, preferences.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var step = 0
    @State private var settings = UserSettings(startDate: Calendar.current.startOfDay(for: .now))

    var body: some View {
        VStack(spacing: 0) {
            StepDots(count: 3, current: step)
                .padding(.top, Theme.Space.m)
                .padding(.bottom, Theme.Space.s)
            Group {
                switch step {
                case 0: WelcomeStep { step = 1 }
                case 1: ScheduleStep(settings: $settings) { step = 2 }
                default: PreferencesStep(settings: $settings) { model.finishOnboarding(settings) }
                }
            }
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.2), value: step)
        .foregroundStyle(Theme.text)
        .background(Theme.background)
    }
}

private struct WelcomeStep: View {
    let next: () -> Void

    var body: some View {
        // Centred when it fits; scrolls at the largest text sizes.
        ViewThatFits(in: .vertical) {
            content.frame(maxHeight: .infinity)
            ScrollView { content }
        }
        .bottomBar {
            Button("Get started", action: next)
                .buttonStyle(BigButtonStyle())
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            // The app icon itself (a small copy in the asset catalog).
            Image("Mark")
                .resizable()
                .frame(width: 88, height: 88)
                .clipShape(Theme.shape(Theme.corner + 2))
                .overlay(Theme.shape(Theme.corner + 2).strokeBorder(Theme.hairline, lineWidth: 1))
                .accessibilityHidden(true)
                .padding(.bottom, Theme.Space.s)
            Text("Welcome")
                .font(Theme.screenTitle)
            Text(
                "A 9-week beginner run/walk plan. You'll start with short bits of running and finish running 30 minutes without stopping."
            )
            .font(Theme.body)
            .fixedSize(horizontal: false, vertical: true)
            Label {
                Text(
                    "If you have a health condition, check with a doctor first. Stop if you feel pain or dizziness."
                )
                .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "heart.fill")
                    .foregroundStyle(Theme.run)
            }
            .font(Theme.body)
            .card(padding: Theme.Space.l)
            .padding(.top, Theme.Space.s)
        }
        .padding(Theme.padding)
    }
}

private struct ScheduleStep: View {
    @Binding var settings: UserSettings
    let next: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                Text("Your week")
                    .font(Theme.screenTitle)
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    Text("Pick 3 run days")
                        .font(Theme.heading)
                    RunDayPicker(runDays: $settings.runDays)
                }
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    Toggle("Remind me on run days", isOn: $settings.remindersOn)
                        .frame(minHeight: Theme.minTarget)
                    if settings.remindersOn {
                        Divider()
                        PickerRow(title: "Reminder time") {
                            DatePicker(
                                "Reminder time", selection: $settings.reminderTime,
                                displayedComponents: .hourAndMinute)
                        }
                    }
                    Divider()
                    PickerRow(title: "Start date") {
                        DatePicker(
                            "Start date", selection: $settings.startDate,
                            in: Calendar.current.startOfDay(for: .now)..., displayedComponents: .date
                        )
                    }
                }
                .font(Theme.body)
                .tint(Theme.walk)
                .card(padding: Theme.Space.l)
            }
            .padding(Theme.padding)
        }
        .scrollBounceBehavior(.basedOnSize)
        .bottomBar {
            Button("Continue") {
                settings.startDate = Calendar.current.startOfDay(for: settings.startDate)
                // Asked even with reminders off: locked-screen cues arrive as notifications.
                Task {
                    _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [
                        .alert, .sound,
                    ])
                }
                next()
            }
            .buttonStyle(BigButtonStyle())
            .disabled(settings.runDays.count != 3)
        }
    }
}

private struct PreferencesStep: View {
    @Binding var settings: UserSettings
    let done: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                Text("A few choices")
                    .font(Theme.screenTitle)
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    Text("Distance").font(Theme.heading)
                    UnitPicker(units: $settings.units)
                }
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    Toggle(isOn: $settings.voiceOn) {
                        ToggleLabel(
                            title: "Voice cues", detail: "A friendly voice tells you when to run and walk.")
                    }
                }
                .tint(Theme.walk)
                .card(padding: Theme.Space.l)
                Text("You can change any of this later in Settings.")
                    .font(Theme.small)
                    .foregroundStyle(Theme.secondaryText)
            }
            .font(Theme.body)
            .padding(Theme.padding)
        }
        .scrollBounceBehavior(.basedOnSize)
        .bottomBar {
            Button("Start my plan", action: done)
                .buttonStyle(BigButtonStyle())
        }
    }
}

private struct StepDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Theme.text : Theme.text.opacity(0.2))
                    .frame(width: i == current ? 24 : 8, height: 8)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(current + 1) of \(count)")
    }
}
