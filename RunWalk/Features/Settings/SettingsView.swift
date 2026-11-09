import RunKit
import SwiftUI
import UserNotifications

/// Units, run days, reminders, run cues, warm-up / cool-down, data export, start over, safety.
/// Edits save as you make them.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var draft = UserSettings(startDate: .now)
    @State private var loaded = false
    @State private var exports: (json: URL, csv: URL)?
    @State private var confirmStartOver = false
    @State private var confirmErase = false
    /// The week picked in "Restart from a week", waiting for confirmation.
    @State private var restartWeek: Int?
    @State private var notificationsDenied = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.xl) {
                    section("Look") { LookPicker() }
                    section("Distance") { UnitPicker(units: $draft.units) }
                    section("Run days") { RunDayPicker(runDays: $draft.runDays) }
                    section("Reminders") { reminders }
                    section("During a run") { runOptions }
                    section("Your data") { data }
                    section("Restart or reset") { restartOrReset }
                    section("Safety and privacy") { about }
                    #if DEBUG
                        devMenu
                    #endif
                }
                .font(Theme.body)
                .tint(Theme.walk)
                .padding(.horizontal, Theme.padding)
                .padding(.bottom, Theme.padding)
            }
            .foregroundStyle(Theme.text)
            .background(Theme.background)
            .navigationTitle("Settings")
        }
        .onAppear {
            if let settings = model.settings { draft = settings }
            loaded = true
        }
        .onChange(of: draft) {
            // Run days only save once there are exactly 3.
            if loaded, draft.runDays.count == 3, draft != model.settings { model.update(draft) }
        }
        // Rebuilt after every data change, so a share is never stale.
        .task(id: model.revision) { exports = model.exportFiles() }
        .task(id: scenePhase) {
            let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            notificationsDenied = status == .denied
        }
        .alert(
            "Restart from week \(restartWeek ?? 1)?",
            isPresented: Binding(get: { restartWeek != nil }, set: { if !$0 { restartWeek = nil } })
        ) {
            Button("Restart") {
                if let week = restartWeek { model.repeatWeek(week) }
                restartWeek = nil
            }
            Button("Not now", role: .cancel) { restartWeek = nil }
        } message: {
            Text("Your next run will be week \(restartWeek ?? 1), run 1. Your run history and badges stay.")
        }
        .alert("Erase everything?", isPresented: $confirmErase) {
            Button("Erase everything", role: .destructive) { model.eraseEverything() }
            Button("Keep my data", role: .cancel) {}
        } message: {
            Text(
                "This deletes all your runs, badges, progress and settings, and takes you back to the welcome screen. It can't be undone. Export a copy first if you want to keep it."
            )
        }
        .alert("Start the plan over?", isPresented: $confirmStartOver) {
            Button("Start over", role: .destructive) { model.startOver() }
            Button("Keep my progress", role: .cancel) {}
        } message: {
            Text(
                "This clears your runs, badges and progress, and takes you back to week 1. Your settings stay."
            )
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text(title).font(Theme.heading)
            VStack(alignment: .leading, spacing: Theme.Space.m) { content() }
                .card(padding: Theme.Space.l)
        }
    }

    @ViewBuilder private var reminders: some View {
        if notificationsDenied {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                Label {
                    Text(
                        "Notifications are off for Run-Walk, so reminders and locked-screen beeps can't arrive."
                    )
                    .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "bell.slash.fill").foregroundStyle(Theme.run)
                }
                .font(Theme.small)
                Button("Turn on in iOS Settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(Theme.small.weight(.semibold))
                .frame(minHeight: Theme.minTarget)
            }
            Divider()
        }
        Toggle("Remind me on run days", isOn: $draft.remindersOn)
            .frame(minHeight: Theme.minTarget)
        if draft.remindersOn {
            Divider()
            PickerRow(title: "Time") {
                DatePicker(
                    "Reminder time", selection: $draft.reminderTime, displayedComponents: .hourAndMinute)
            }
        }
    }

    @ViewBuilder private var runOptions: some View {
        Toggle(isOn: $draft.voiceOn) {
            ToggleLabel(title: "Voice cues", detail: "A friendly voice tells you when to run and walk.")
        }
        Divider()
        Toggle("Beeps", isOn: $draft.beepsOn).frame(minHeight: Theme.minTarget)
        Divider()
        Toggle("Vibration", isOn: $draft.hapticsOn).frame(minHeight: Theme.minTarget)
        Divider()
        minutesStepper("Warm-up walk", seconds: $draft.warmupSec)
        Divider()
        minutesStepper("Cool-down walk", seconds: $draft.cooldownSec)
    }

    private func minutesStepper(_ title: String, seconds: Binding<Int>) -> some View {
        let range = UserSettings.warmupRange
        let value = Format.minutes(seconds.wrappedValue)
        // At accessibility sizes the label goes above the stepper instead of breaking mid-word.
        if typeSize.isAccessibilitySize {
            return AnyView(
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    Text("\(title): \(value)").monospacedDigit()
                    Stepper(title, value: seconds, in: range, step: 60).labelsHidden()
                }
                .accessibilityElement(children: .combine)
                .accessibilityValue(value))
        }
        return AnyView(stepperRow(title, seconds: seconds, range: range))
    }

    private func stepperRow(_ title: String, seconds: Binding<Int>, range: ClosedRange<Int>) -> some View {
        Stepper(value: seconds, in: range, step: 60) {
            HStack {
                Text(title)
                Spacer()
                Text(Format.minutes(seconds.wrappedValue)).monospacedDigit().foregroundStyle(
                    Theme.secondaryText)
            }
        }
        .frame(minHeight: Theme.minTarget)
        .accessibilityValue(Format.minutes(seconds.wrappedValue))
    }

    @ViewBuilder private var data: some View {
        Text("Everything stays on this phone. Export a copy to keep or share.")
            .font(Theme.small).foregroundStyle(Theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        if let exports {
            ShareLink(item: exports.json, preview: SharePreview("Run-Walk data (JSON)")) {
                Label("Export all data (JSON)", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity, minHeight: Theme.minTarget, alignment: .leading)
            }
            Divider()
            ShareLink(item: exports.csv, preview: SharePreview("Run-Walk runs (CSV)")) {
                Label("Export runs (CSV)", systemImage: "tablecells")
                    .frame(maxWidth: .infinity, minHeight: Theme.minTarget, alignment: .leading)
            }
        }
    }

    /// Three levels, gentlest first. Each one asks before doing anything.
    @ViewBuilder private var restartOrReset: some View {
        Menu {
            ForEach(model.restartableWeeks.reversed(), id: \.self) { week in
                Button(week == model.currentWeek ? "Week \(week) (this week)" : "Week \(week)") {
                    restartWeek = week
                }
            }
        } label: {
            resetRow(
                "Restart from a week", detail: "Go back to an earlier week. Your runs and badges stay.",
                icon: "arrow.uturn.backward")
        }
        Divider()
        Button {
            confirmStartOver = true
        } label: {
            resetRow(
                "Start the plan over", detail: "Back to week 1 with a clean slate. Your settings stay.",
                icon: "arrow.counterclockwise")
        }
        Divider()
        Button {
            confirmErase = true
        } label: {
            resetRow(
                "Erase everything", detail: "Delete all runs, badges and settings, as if newly installed.",
                icon: "trash")
        }
    }

    private func resetRow(_ title: String, detail: String, icon: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text(title).foregroundStyle(Theme.text)
                Text(detail)
                    .font(Theme.small)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: icon).foregroundStyle(Theme.text)
        }
        .frame(maxWidth: .infinity, minHeight: Theme.minTarget, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var about: some View {
        Label {
            Text(
                "If you have a health condition, check with a doctor first. Stop if you feel pain or dizziness."
            )
            .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "heart.fill").foregroundStyle(Theme.run)
        }
        Divider()
        Label {
            Text(
                "No account, no tracking, and the app makes no network requests. Your runs never leave this phone."
            )
            .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "lock.shield.fill").foregroundStyle(Theme.walk)
        }
        Divider()
        Text("A 9-week beginner run/walk plan · version \(version)")
            .font(Theme.small).foregroundStyle(Theme.secondaryText)
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    #if DEBUG
        private var devMenu: some View {
            Menu {
                ForEach(Program.workouts) { workout in
                    Button(workout.title) { model.start(workout) }
                }
            } label: {
                Label("Try any workout (dev)", systemImage: "hammer")
                    .font(Theme.small.weight(.semibold))
                    .padding(.horizontal, Theme.Space.l)
                    .frame(minHeight: Theme.minTarget)
                    .background(Theme.quietFill, in: Capsule())
            }
            .frame(maxWidth: .infinity)
        }
    #endif
}
