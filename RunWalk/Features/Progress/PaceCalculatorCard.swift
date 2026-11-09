import RunKit
import SwiftUI

/// Fill in any two of distance, time and pace; it works out the third.
struct PaceCalculatorCard: View {
    let unit: DistanceUnit
    @State private var distance = ""
    @State private var time = ""
    @State private var pace = ""
    @State private var message: String?
    /// The field the last answer was written into; it's worked out again if all three are filled.
    @State private var answered: Int?
    @FocusState private var typing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text("Pace calculator").font(Theme.heading)
            Text("Fill in any two. Times like 34:20.")
                .font(Theme.small).foregroundStyle(Theme.secondaryText)
            field("Distance (\(unit.label))", text: $distance, keyboard: .decimalPad)
            field("Time", text: $time, keyboard: .numbersAndPunctuation)
            field("Pace (per \(unit.label))", text: $pace, keyboard: .numbersAndPunctuation)
            if let message {
                Text(message).font(Theme.small).foregroundStyle(Theme.secondaryText)
            }
            HStack(spacing: Theme.Space.m) {
                Button("Work it out", action: solve)
                    .buttonStyle(BigButtonStyle())
                Button("Clear", action: clear)
                    .font(Theme.body.weight(.semibold))
                    .frame(minWidth: Theme.minTarget + 24, minHeight: Theme.minTarget)
            }
        }
        .card()
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { typing = false }
            }
        }
    }

    private func field(_ title: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(title).font(Theme.small).foregroundStyle(Theme.secondaryText)
            TextField(title, text: text)
                .keyboardType(keyboard)
                .focused($typing)
                .monospacedDigit()
                .fieldStyle()
        }
    }

    private func solve() {
        typing = false
        // Changed a number after an answer? Work the answered field out again.
        let full = !distance.isEmpty && !time.isEmpty && !pace.isEmpty
        let skip = full ? answered : nil
        let distanceM = skip == 0 ? nil : number(distance).map { $0 * unit.meters }
        let timeSec = skip == 1 ? nil : Format.parseClock(time).map(Double.init)
        let paceSecPerKm = skip == 2 ? nil : Format.parseClock(pace).map { Double($0) * 1000 / unit.meters }
        if skip != 0 && !distance.isEmpty && distanceM == nil || skip != 1 && !time.isEmpty && timeSec == nil
            || skip != 2 && !pace.isEmpty && paceSecPerKm == nil
        {
            message = "Check the numbers: distance like 5 or 2.5, times like 34:20."
            return
        }
        do {
            let result = try PaceCalculator.solve(
                distanceM: distanceM, timeSec: timeSec, paceSecPerKm: paceSecPerKm)
            answered = distanceM == nil ? 0 : timeSec == nil ? 1 : 2
            distance = String(format: "%.2f", result.distanceM / unit.meters)
            time = Format.clock(Int(result.timeSec.rounded()))
            pace = Format.clock(Int((result.paceSecPerKm * unit.meters / 1000).rounded()))
            message = nil
        } catch {
            switch error {
            case .needExactlyTwo: message = "Fill in any two and leave one empty."
            case .invalid: message = "Check the numbers: they need to be more than zero."
            case .outOfRange: message = "That works out to a pace no one runs. Check the numbers."
            }
        }
    }

    private func clear() {
        answered = nil
        distance = ""
        time = ""
        pace = ""
        message = nil
    }

    private func number(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }
}
