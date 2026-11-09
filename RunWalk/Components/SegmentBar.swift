import RunKit
import SwiftUI

/// Colored blocks proportional to time, with an optional marker for "you are here".
struct SegmentBar: View {
    let segments: [Segment]
    var fraction: Double?

    private let gap: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            let total = CGFloat(segments.reduce(0) { $0 + $1.seconds })
            let usable = geo.size.width - gap * CGFloat(max(0, segments.count - 1))
            ZStack(alignment: .leading) {
                HStack(spacing: gap) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                        RoundedRectangle(cornerRadius: Theme.barCorner, style: .continuous)
                            .fill(Theme.color(for: segment.kind))
                            .frame(width: max(1, usable * CGFloat(segment.seconds) / max(total, 1)))
                    }
                }
                if let fraction {
                    // A ring in the background colour keeps the marker visible on every segment colour.
                    Capsule()
                        .fill(Theme.text)
                        .overlay(Capsule().strokeBorder(Theme.background, lineWidth: 1.5))
                        .frame(width: 7, height: geo.size.height + 12)
                        .offset(x: geo.size.width * CGFloat(min(max(fraction, 0), 1)) - 3.5)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .accessibilityElement()
        .accessibilityLabel(summary)
    }

    private var summary: String {
        let runs = segments.filter { $0.kind == .run }.count
        let walks = segments.filter { $0.kind == .walk }.count
        var text = "\(runs) run\(runs == 1 ? "" : "s")"
        if walks > 0 { text += " and \(walks) walk\(walks == 1 ? "" : "s")" }
        if let fraction { text += ", \(Int(fraction * 100)) percent done" }
        return text
    }
}

/// Words for the segment bar's colours, so colour is never the only cue.
struct SegmentLegend: View {
    @ScaledMetric(relativeTo: .subheadline) private var swatch: CGFloat = 12

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Space.l) { items }
            VStack(alignment: .leading, spacing: Theme.Space.xs) { items }
        }
        .font(Theme.small)
        .foregroundStyle(Theme.secondaryText)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var items: some View {
        item("Run", Theme.run)
        item("Walk", Theme.walk)
        item("Warm-up / cool-down", Theme.easy)
    }

    private func item(_ title: String, _ color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            RoundedRectangle(cornerRadius: Theme.barCorner, style: .continuous)
                .fill(color)
                .frame(width: swatch, height: swatch)
            Text(title)
        }
    }
}
