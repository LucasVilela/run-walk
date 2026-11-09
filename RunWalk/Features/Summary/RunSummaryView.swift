import RunKit
import SwiftUI

/// Celebration, numbers, the 80% choice and the check-in.
struct RunSummaryView: View {
    @Environment(AppModel.self) private var model
    let summary: RunSummary

    @State private var feeling: Feeling?
    @State private var pain = false
    @State private var notes = ""
    @State private var countAnyway = false
    @State private var distanceText = ""
    @FocusState private var typing: Bool

    private var run: RunRecord { summary.run }
    private var unit: DistanceUnit { model.settings?.units ?? .km }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                header
                RunStatsCard(run: run, distanceM: enteredDistanceM ?? run.distanceM, unit: unit)
                if !run.counted { completionChoice }
                distanceField
                CheckInFields(feeling: $feeling, pain: $pain, notes: $notes, typing: $typing)
            }
            .padding(Theme.padding)
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            // The number pad has no return key.
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { typing = false }
            }
        }
        .bottomBar {
            Button("Done") { save() }
                .buttonStyle(BigButtonStyle())
        }
        .foregroundStyle(Theme.text)
        .background(Theme.background)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Image(systemName: run.counted ? "checkmark.circle.fill" : "hand.thumbsup.circle.fill")
                .font(.system(size: 44))
                .symbolRenderingMode(.palette)
                .foregroundStyle(Theme.onColor, Theme.walk)
                .accessibilityHidden(true)
            Text(celebration)
                .font(Theme.title)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(summary.newBadges) { badge in
                Label {
                    Text("Badge earned: \(badge.title)")
                } icon: {
                    Image(systemName: "medal.fill").foregroundStyle(Theme.run)
                }
                .font(Theme.body.weight(.semibold))
                .padding(.horizontal, Theme.Space.l)
                .padding(.vertical, Theme.Space.s + 2)
                .background(Theme.card, in: Theme.shape(Theme.smallCorner))
                .overlay(Theme.shape(Theme.smallCorner).strokeBorder(Theme.hairline, lineWidth: 1))
            }
        }
        .padding(.top, Theme.Space.xl)
    }

    private var celebration: String {
        let title = run.workout?.title ?? "Run"
        if !run.counted {
            return run.runningSec > 0
                ? "Good effort. Every bit of running counts." : "Thanks for getting out there today."
        }
        if run.workout?.graduation == true { return "You did it. Thirty minutes of running." }
        return "\(title) done. Nice work."
    }

    @ViewBuilder private var completionChoice: some View {
        if run.canCountAnyway {
            choices
        } else {
            // Ended in the warm-up: nothing to count, no choice to make.
            Text("You stopped during the warm-up, so this run stays next on your plan.")
                .font(Theme.body)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var choices: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text("You did \(Int(run.completionPct))% of this run.")
                .font(Theme.heading)
            VStack(spacing: 0) {
                choiceRow("Retry this run next time", selected: !countAnyway) { countAnyway = false }
                Divider()
                choiceRow("Count it anyway", selected: countAnyway) { countAnyway = true }
            }
            .card(padding: Theme.Space.l)
        }
    }

    private func choiceRow(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.m) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(selected ? Theme.onColor : Theme.secondaryText, Theme.walk)
                Text(title)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .font(Theme.body)
            .padding(.vertical, Theme.Space.xs)
            .frame(minHeight: Theme.minTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var distanceField: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text("Distance (optional)").font(Theme.heading)
            HStack(spacing: Theme.Space.m) {
                TextField("If you know it, e.g. 3.2", text: $distanceText)
                    .focused($typing)
                    .keyboardType(.decimalPad)
                    .monospacedDigit()
                    .fieldStyle()
                Text(unit.label)
                    .font(Theme.body)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private var enteredDistanceM: Double? {
        guard let value = Double(distanceText.replacingOccurrences(of: ",", with: ".")), value > 0,
            value < 100
        else { return nil }
        return value * unit.meters
    }

    private func save() {
        model.saveCheckIn(
            runId: run.id, feeling: feeling, pain: pain, notes: notes, countAnyway: countAnyway,
            distanceM: enteredDistanceM)
    }
}
