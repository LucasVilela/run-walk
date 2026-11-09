import RunKit
import SwiftUI

/// The active workout. Big word + countdown on top, segment bar in the middle, big controls below.
struct RunView: View {
    let session: RunSession
    @State private var locked = false
    @State private var confirmEnd = false
    /// Captured when End is tapped: SwiftUI keeps the alert's first message, so it can't read live state.
    @State private var endPct = 0
    @ScaledMetric(relativeTo: .largeTitle) private var countdownSize = Theme.countdownSize

    private var snap: RunSnapshot { session.snapshot }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if snap.phase != .finished {
                Theme.color(for: snap.segment.kind).opacity(0.22).ignoresSafeArea()
            }
            if snap.phase == .finished {
                finished
            } else {
                running
            }
            if locked { LockOverlay { locked = false } }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            session.begin()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            session.stop()
        }
        .alert("End run?", isPresented: $confirmEnd) {
            // Not red: ending early is fine, never a failure.
            Button("End & save") { session.end() }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text(endPct == 0 ? "You're still in the warm-up." : "You've done \(endPct)%.")
        }
    }

    // MARK: - Running

    private var running: some View {
        VStack(spacing: Theme.Space.l) {
            topBar
            Spacer(minLength: 0)
            VStack(spacing: Theme.Space.s) {
                // The word on its segment colour: colour and word always travel together.
                Text(snap.segment.kind.label)
                    .font(Theme.segmentLabel)
                    .tracking(2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(Theme.onColor)
                    .padding(.horizontal, Theme.Space.xl)
                    .padding(.vertical, Theme.Space.s)
                    .background(Theme.color(for: snap.segment.kind), in: Capsule())
                // Scales with Dynamic Type, capped so four digits still fit across the screen.
                Text(Format.clock(Int(snap.segmentRemaining.rounded(.up))))
                    .font(Theme.countdown(size: min(countdownSize, 132)))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
            }
            .layoutPriority(1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "\(snap.segment.kind.name), \(CueLines.spoken(Int(snap.segmentRemaining.rounded(.up)))) left")

            Text(nextText)
                .font(Theme.title)
                .monospacedDigit()
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            VStack(spacing: Theme.Space.m) {
                SegmentBar(segments: session.plan.segments, fraction: snap.fraction)
                    .frame(height: 28)
                    .padding(.vertical, Theme.Space.s)

                HStack {
                    Text("\(Format.clock(Int(snap.movingSec))) elapsed")
                    Spacer()
                    Text("\(Format.clock(Int(snap.remainingSec.rounded(.up)))) left")
                }
                .font(Theme.body)
                .monospacedDigit()
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            .card(padding: Theme.Space.l)

            Spacer(minLength: 0)
            controls
        }
        .foregroundStyle(Theme.text)
        .padding(Theme.padding)
        // The layout is fixed to fit one screen; the countdown already scales, so cap the chrome.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private var nextText: String {
        guard let next = snap.next else { return "Last stretch" }
        return "Next: \(next.kind.name) \(Format.clock(next.seconds))"
    }

    private var topBar: some View {
        HStack {
            Button {
                locked = true
            } label: {
                Image(systemName: "lock.fill")
                    .font(.title3.weight(.semibold))
                    .frame(width: Theme.minTarget, height: Theme.minTarget)
                    .background(Theme.card, in: Circle())
                    .contentShape(Circle())
            }
            .accessibilityLabel("Lock screen")
            .accessibilityHint("Stops pocket taps. Hold to unlock.")
            Spacer()
            Text(session.plan.workout?.title ?? "")
                .font(Theme.heading)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            #if DEBUG
                Button {
                    session.cycleSpeed()
                } label: {
                    Text("×\(Int(session.speed))")
                        .font(Theme.small.weight(.semibold).monospacedDigit())
                        .frame(width: Theme.minTarget + 12, height: Theme.minTarget)
                        .background(Theme.card, in: Capsule())
                        .contentShape(Capsule())
                }
                .accessibilityLabel("Dev speed \(Int(session.speed)) times")
            #else
                Color.clear.frame(width: Theme.minTarget, height: Theme.minTarget)
            #endif
        }
    }

    private var controls: some View {
        HStack(alignment: .lastTextBaseline) {
            RoundControl(systemImage: "forward.end.fill", title: "Skip", size: Theme.runControl) {
                session.skip()
            }
            .accessibilityLabel("Skip segment")
            Spacer()
            let paused = snap.phase == .paused
            RoundControl(
                systemImage: paused ? "play.fill" : "pause.fill", title: paused ? "Resume" : "Pause",
                size: Theme.runControl + 24, prominent: true
            ) {
                session.togglePause()
            }
            .accessibilityLabel(paused ? "Resume" : "Pause")
            Spacer()
            RoundControl(systemImage: "stop.fill", title: "End", size: Theme.runControl) {
                endPct = session.currentCompletionPct
                confirmEnd = true
            }
            .accessibilityLabel("End run")
        }
        .padding(.horizontal, Theme.Space.s)
    }

    // MARK: - Finished: the model swaps in the summary straight away

    private var finished: some View {
        ProgressView("Saving your run")
            .font(Theme.body)
            .foregroundStyle(Theme.text)
    }
}

/// A round icon button with its word underneath.
private struct RoundControl: View {
    let systemImage: String
    let title: String
    let size: CGFloat
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Space.s) {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.34, weight: .bold))
                    .frame(width: size, height: size)
                    .foregroundStyle(prominent ? Theme.background : Theme.text)
                    .background(Circle().fill(prominent ? Theme.text : Theme.card))
                    .overlay(Circle().strokeBorder(prominent ? .clear : Theme.hairline, lineWidth: 1))
                Text(title)
                    .font(Theme.small.weight(.semibold))
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
