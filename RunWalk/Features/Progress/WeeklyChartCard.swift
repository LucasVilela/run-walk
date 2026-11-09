import Charts
import SwiftUI

/// Running minutes for each of the 9 plan weeks.
struct WeeklyChartCard: View {
    let secondsPerWeek: [Int]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text("Running minutes per week").font(Theme.heading)
            Chart(Array(secondsPerWeek.enumerated()), id: \.offset) { index, seconds in
                BarMark(x: .value("Week", "\(index + 1)"), y: .value("Minutes", seconds / 60))
                    .foregroundStyle(Theme.run)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.barCorner, style: .continuous))
                    .accessibilityLabel("Week \(index + 1)")
                    .accessibilityValue("\(seconds / 60) minutes")
            }
            .chartXAxisLabel("Week", alignment: .center)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(Theme.hairline)
                    AxisValueLabel()
                }
            }
            .frame(height: 180)
        }
        .card()
    }
}
