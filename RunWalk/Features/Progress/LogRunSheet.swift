import RunKit
import SwiftUI

/// Type in a run done without the app: when, how long, and (if you like) distance and how it felt.
struct LogRunSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    /// Matches the default 30 minutes, so the run ends about now.
    @State private var startedAt = Date().addingTimeInterval(-1800)
    @State private var hours = 0
    @State private var minutes = 30
    @State private var distanceText = ""
    @State private var feeling: Feeling?
    @State private var pain = false
    @State private var notes = ""
    @FocusState private var typing: Bool

    private var unit: DistanceUnit { model.settings?.units ?? .km }
    private var durationSec: Int { (hours * 60 + minutes) * 60 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.xl) {
                    Text("It shows in your history and totals. Your plan stays where it is.")
                        .font(Theme.body)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    whenField
                    durationField
                    DistanceField(text: $distanceText, unit: unit, typing: $typing)
                    CheckInFields(feeling: $feeling, pain: $pain, notes: $notes, typing: $typing)
                }
                .padding(Theme.padding)
            }
            .scrollDismissesKeyboard(.interactively)
            .foregroundStyle(Theme.text)
            .background(Theme.background)
            .navigationTitle("Log a run")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(durationSec == 0)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { typing = false }
                }
            }
        }
        .tint(Theme.accent)
    }

    private var whenField: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text("When did you start?").font(Theme.heading)
            DatePicker(
                "Started", selection: $startedAt, in: ...Date(), displayedComponents: [.date, .hourAndMinute]
            )
            .font(Theme.body)
            .frame(minHeight: Theme.minTarget)
            .padding(.horizontal, Theme.Space.l)
            .background(Theme.card, in: Theme.shape(Theme.smallCorner))
            .overlay(Theme.shape(Theme.smallCorner).strokeBorder(Theme.hairline, lineWidth: 1))
        }
    }

    private var durationField: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text("How long?").font(Theme.heading)
            HStack(spacing: 0) {
                Picker("Hours", selection: $hours) {
                    ForEach(0..<6, id: \.self) { Text("\($0) h").tag($0) }
                }
                Picker("Minutes", selection: $minutes) {
                    ForEach(0..<60, id: \.self) { Text("\($0) min").tag($0) }
                }
            }
            .pickerStyle(.wheel)
            .monospacedDigit()
            .frame(height: 140)
            .background(Theme.card, in: Theme.shape(Theme.smallCorner))
            .overlay(Theme.shape(Theme.smallCorner).strokeBorder(Theme.hairline, lineWidth: 1))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Duration")
        }
    }

    private func save() {
        typing = false
        model.logRun(
            .other(
                startedAt: startedAt, durationSec: durationSec,
                distanceM: DistanceField.meters(distanceText, unit: unit), feeling: feeling, pain: pain,
                notes: notes))
        dismiss()
    }
}
