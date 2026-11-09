import RunKit
import SwiftUI

/// An other run in progress: one big clock counting up, Pause and End.
struct FreeRunView: View {
    let session: FreeRunSession
    @State private var locked = false
    @State private var confirmEnd = false
    @ScaledMetric(relativeTo: .largeTitle) private var clockSize = Theme.countdownSize

    private var seconds: Int { Int(session.elapsed) }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            Theme.run.opacity(session.isPaused ? 0.08 : 0.18).ignoresSafeArea()
            content
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
            Button("End & save") { session.end() }
            Button("Discard run", role: .destructive) { session.discard() }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("You've been out for \(Format.clock(seconds)).")
        }
    }

    private var content: some View {
        VStack(spacing: Theme.Space.l) {
            topBar
            Spacer(minLength: 0)
            VStack(spacing: Theme.Space.s) {
                Text(session.isPaused ? "Paused" : "Running")
                    .font(Theme.segmentLabel)
                    .tracking(2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(Theme.onColor)
                    .padding(.horizontal, Theme.Space.xl)
                    .padding(.vertical, Theme.Space.s)
                    .background(session.isPaused ? Theme.easy : Theme.run, in: Capsule())
                Text(Format.clock(seconds))
                    .font(Theme.countdown(size: min(clockSize, 132)))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "\(session.isPaused ? "Paused" : "Running"), \(Format.clock(seconds)) so far")
            Text("Your own pace. A time check every 5 minutes.")
                .font(Theme.body)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            controls
        }
        .foregroundStyle(Theme.text)
        .padding(Theme.padding)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
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
            Text("Other run").font(Theme.heading)
            Spacer()
            Color.clear.frame(width: Theme.minTarget, height: Theme.minTarget)
        }
    }

    private var controls: some View {
        HStack(alignment: .lastTextBaseline, spacing: Theme.Space.xl * 2) {
            RoundControl(
                systemImage: session.isPaused ? "play.fill" : "pause.fill",
                title: session.isPaused ? "Resume" : "Pause", size: Theme.runControl + 24, prominent: true
            ) {
                session.togglePause()
            }
            .accessibilityLabel(session.isPaused ? "Resume" : "Pause")
            RoundControl(systemImage: "stop.fill", title: "End", size: Theme.runControl) {
                confirmEnd = true
            }
            .accessibilityLabel("End run")
        }
    }
}
