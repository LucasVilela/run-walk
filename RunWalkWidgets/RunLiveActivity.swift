import ActivityKit
import RunKit
import SwiftUI
import WidgetKit

/// Lock screen and Dynamic Island during a run: time left counts down and the bar fills by itself,
/// with no help from the app, so it stays right while the phone is locked.
struct RunLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RunActivityAttributes.self) { context in
            LockScreenView(context: context)
                .padding(16)
                .activityBackgroundTint(Color.black.opacity(0.75))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.title, systemImage: "figure.run")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TimeLeft(attributes: context.attributes, state: context.state)
                        .font(.title3.monospacedDigit().weight(.semibold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if !context.attributes.isFree {
                        WorkoutBar(attributes: context.attributes, state: context.state)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.pausedRemaining == nil ? "figure.run" : "pause.fill")
                    .foregroundStyle(WidgetColors.run)
            } compactTrailing: {
                TimeLeft(attributes: context.attributes, state: context.state)
                    .monospacedDigit()
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: "figure.run").foregroundStyle(WidgetColors.run)
            }
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<RunActivityAttributes>
    /// Always-on / dimmed lock screen: iOS blanks timer seconds ("29:--"), so show the finish time instead.
    @Environment(\.isLuminanceReduced) private var dimmed
    private var running: Bool { context.state.pausedRemaining == nil }
    private var free: Bool { context.attributes.isFree }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.title).font(.headline)
                    Text(context.state.pausedRemaining == nil ? "Unlock for voice cues" : "Paused")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Group {
                        if dimmed && running {
                            Text(free ? context.state.start : context.state.end, style: .time)
                        } else {
                            TimeLeft(attributes: context.attributes, state: context.state)
                        }
                    }
                    .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                    .multilineTextAlignment(.trailing)
                    Text(caption).font(.caption).foregroundStyle(.white.opacity(0.7))
                }
            }
            if !free { WorkoutBar(attributes: context.attributes, state: context.state) }
        }
        .foregroundStyle(.white)
    }

    private var caption: String {
        if dimmed && running { return free ? "started" : "finishes" }
        return free ? "so far" : "left"
    }
}

/// Time left in the workout (an other run: time so far): live while running, fixed while paused.
private struct TimeLeft: View {
    let attributes: RunActivityAttributes
    let state: RunActivityAttributes.ContentState

    var body: some View {
        if let fixed = state.pausedRemaining {
            Text(Format.clock(fixed))
        } else {
            Text(timerInterval: state.start...state.end, countsDown: !attributes.isFree)
        }
    }
}

/// The run/walk blocks, with the system's progress bar filling across them.
private struct WorkoutBar: View {
    let attributes: RunActivityAttributes
    let state: RunActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let total = CGFloat(attributes.segments.reduce(0) { $0 + $1.seconds })
                HStack(spacing: 2) {
                    ForEach(Array(attributes.segments.enumerated()), id: \.offset) { _, segment in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(WidgetColors.color(for: segment.kind))
                            .frame(
                                width: max(
                                    1,
                                    (geo.size.width - CGFloat(attributes.segments.count) * 2)
                                        * CGFloat(segment.seconds) / max(total, 1)))
                    }
                }
            }
            .frame(height: 10)
            Group {
                if let fraction = state.pausedFraction {
                    ProgressView(value: fraction)
                } else {
                    ProgressView(timerInterval: state.start...state.end, countsDown: false) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                }
            }
            .tint(.white)
        }
    }
}
