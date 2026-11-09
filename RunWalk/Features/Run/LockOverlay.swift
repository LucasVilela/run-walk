import SwiftUI

/// Swallows every touch so pocket taps do nothing. Hold the pill for a second to unlock.
struct LockOverlay: View {
    let unlock: () -> Void
    @State private var holding = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {}
            HStack(spacing: Theme.Space.m) {
                Image(systemName: holding ? "lock.open.fill" : "lock.fill")
                    .contentTransition(.symbolEffect(.replace))
                Text("Locked · hold to unlock")
                    .multilineTextAlignment(.center)
            }
            .font(Theme.body.weight(.semibold))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, Theme.Space.xl)
            .padding(.vertical, Theme.Space.m)
            .frame(minHeight: Theme.runControl)
            .background(Theme.card, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.text.opacity(holding ? 0.6 : 0.12), lineWidth: 2))
            .scaleEffect(holding && !reduceMotion ? 1.06 : 1)
            .animation(.easeOut(duration: 0.2), value: holding)
            .onLongPressGesture(minimumDuration: 1, perform: unlock) { holding = $0 }
            .padding(.horizontal, Theme.padding)
            .padding(.bottom, Theme.Space.xxl + Theme.Space.l)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Screen locked")
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(named: "Unlock", unlock)
    }
}
