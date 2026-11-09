import SwiftUI

/// Calm empty state used for lists with nothing in them yet, and for tabs still being built.
struct EmptyState: View {
    let title: String
    let message: String
    var systemImage = "figure.run"
    @ScaledMetric(relativeTo: .largeTitle) private var badge: CGFloat = 88

    var body: some View {
        // Centred when it fits; scrolls at the largest text sizes.
        ViewThatFits(in: .vertical) {
            content.frame(maxHeight: .infinity)
            ScrollView { content }
        }
        .background(Theme.background)
    }

    private var content: some View {
        VStack(spacing: Theme.Space.l) {
            Image(systemName: systemImage)
                .font(.system(size: badge * 0.42, weight: .medium))
                .foregroundStyle(Theme.text)
                .frame(width: badge, height: badge)
                .background(Theme.card, in: Circle())
                .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                .padding(.bottom, Theme.Space.xs)
                .accessibilityHidden(true)
            Text(title)
                .font(Theme.title)
                .foregroundStyle(Theme.text)
            Text(message)
                .font(Theme.body)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .padding(Theme.padding)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
