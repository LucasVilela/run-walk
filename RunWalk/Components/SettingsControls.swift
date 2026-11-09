import RunKit
import SwiftUI

// Controls shared by onboarding and the Settings tab.

/// Seven day chips, Monday first; exactly 3 allowed. Warns, never blocks, about back-to-back days.
struct RunDayPicker: View {
    @Binding var runDays: Set<Int>
    @State private var pickedTooMany = false

    /// Calendar weekday numbers (1 = Sunday), Monday first.
    private let order = [2, 3, 4, 5, 6, 7, 1]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Theme.Space.s) { ForEach(order, id: \.self, content: chip) }
                VStack(spacing: Theme.Space.s) {
                    HStack(spacing: Theme.Space.s) { ForEach(order.prefix(4), id: \.self, content: chip) }
                    HStack(spacing: Theme.Space.s) { ForEach(order.suffix(3), id: \.self, content: chip) }
                }
            }
            if pickedTooMany {
                note("That's 3 already. Untick a day to choose a different one.")
            } else if runDays.count < 3 {
                note("Pick \(3 - runDays.count) more.")
            }
            if DateHelpers.hasConsecutiveDays(runDays) {
                note(
                    "Two of your days are back to back. That's fine, but a rest day in between helps your legs recover."
                )
            }
        }
    }

    private func chip(_ day: Int) -> some View {
        let on = runDays.contains(day)
        return Button {
            if on {
                runDays.remove(day)
                pickedTooMany = false
            } else if runDays.count < 3 {
                runDays.insert(day)
            } else {
                pickedTooMany = true
            }
        } label: {
            ChoiceChip(title: String(Calendar.current.shortWeekdaySymbols[day - 1].prefix(2)), selected: on)
                .frame(minWidth: 40)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(Theme.small)
            .foregroundStyle(Theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Kilometres / Miles as chips (the segmented control doesn't grow with Dynamic Type).
struct UnitPicker: View {
    @Binding var units: DistanceUnit

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            chip(.km, "Kilometres")
            chip(.mi, "Miles")
        }
    }

    private func chip(_ unit: DistanceUnit, _ title: String) -> some View {
        Button {
            units = unit
        } label: {
            ChoiceChip(title: title, selected: units == unit)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Distance in \(title.lowercased())")
        .accessibilityAddTraits(units == unit ? .isSelected : [])
    }
}

/// Label and control side by side; stacked at accessibility text sizes so neither gets squeezed.
struct PickerRow<Picker: View>: View {
    let title: String
    @ViewBuilder let picker: Picker
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let stacked = typeSize.isAccessibilitySize
        let layout =
            stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Space.s)) : AnyLayout(HStackLayout())
        layout {
            Text(title).accessibilityHidden(true)
            if !stacked { Spacer() }
            picker.labelsHidden()
        }
        .frame(minHeight: Theme.minTarget)
    }
}

/// A toggle's title with a short explanation underneath.
struct ToggleLabel: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(title)
            Text(detail)
                .font(Theme.small)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: Theme.minTarget)
    }
}

extension Binding where Value == UserSettings {
    /// The reminder time (stored as minutes after midnight) as a Date for a DatePicker.
    var reminderTime: Binding<Date> {
        Binding<Date>(
            get: { DateHelpers.at(minutes: wrappedValue.reminderMinutes, on: .now, .current) },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                wrappedValue.reminderMinutes = (parts.hour ?? 7) * 60 + (parts.minute ?? 0)
            })
    }
}
