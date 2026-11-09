import RunKit
import SwiftUI

// Pieces shared by the Run Summary and Run detail screens.

/// Duration, running time, distance and average pace: 2×2, or one column at large text sizes.
struct RunStatsCard: View {
    let run: RunRecord
    var distanceM: Double?
    let unit: DistanceUnit

    var body: some View {
        let pace = distanceM.flatMap { Pace.secondsPerKm(movingSec: Double(run.movingSec), distanceM: $0) }
        let items = [
            ("Duration", Format.clock(run.movingSec)), ("Running", Format.clock(run.runningSec)),
            ("Distance", Format.distance(meters: distanceM, unit: unit)),
            ("Avg pace", Format.pace(secondsPerKm: pace, unit: unit)),
        ]
        ViewThatFits(in: .horizontal) {
            Grid(alignment: .leading, horizontalSpacing: Theme.Space.l, verticalSpacing: Theme.Space.l) {
                GridRow {
                    StatValue(label: items[0].0, value: items[0].1)
                    StatValue(label: items[1].0, value: items[1].1)
                }
                Divider().gridCellUnsizedAxes(.horizontal)
                GridRow {
                    StatValue(label: items[2].0, value: items[2].1)
                    StatValue(label: items[3].0, value: items[3].1)
                }
            }
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                ForEach(items, id: \.0) { StatValue(label: $0.0, value: $0.1) }
            }
        }
        .card()
    }
}

/// A small label over a big number.
struct StatValue: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(label).font(Theme.small).foregroundStyle(Theme.secondaryText)
            Text(value)
                .font(Theme.title)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// "How did that feel?" chips, the pain switch and a notes field.
struct CheckInFields: View {
    @Binding var feeling: Feeling?
    @Binding var pain: Bool
    @Binding var notes: String
    var typing: FocusState<Bool>.Binding
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text("How did that feel?").font(Theme.heading)
            // Chips shrink their text rather than overflow, so stack them at accessibility sizes.
            if typeSize.isAccessibilitySize {
                VStack(spacing: Theme.Space.s) { chips }
            } else {
                HStack(spacing: Theme.Space.s) { chips }
            }
            Toggle("Any pain?", isOn: $pain)
                .font(Theme.body)
                .tint(Theme.walk)
                .frame(minHeight: Theme.minTarget)
                .padding(.horizontal, Theme.Space.l)
                .background(Theme.card, in: Theme.shape(Theme.smallCorner))
                .overlay(Theme.shape(Theme.smallCorner).strokeBorder(Theme.hairline, lineWidth: 1))
            TextField("Notes (optional)", text: $notes, axis: .vertical)
                .focused(typing)
                .lineLimit(2...5)
                .fieldStyle()
        }
    }

    @ViewBuilder private var chips: some View {
        chip(.easy, "Easy")
        chip(.right, "Just right")
        chip(.hard, "Hard")
    }

    private func chip(_ value: Feeling, _ title: String) -> some View {
        let on = feeling == value
        return Button {
            feeling = on ? nil : value
        } label: {
            ChoiceChip(title: title, selected: on)
                .frame(minWidth: 96)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
