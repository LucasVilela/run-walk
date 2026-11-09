import SwiftUI

// Shared look for cards, chips, fields and buttons, so every screen uses the same shapes.

extension View {
    /// White (light) or charcoal (dark) rounded card with a hairline edge.
    func card(padding: CGFloat = Theme.padding) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: Theme.shape())
            .overlay(Theme.shape().strokeBorder(Theme.hairline, lineWidth: 1))
    }

    /// Rounded text field look: card fill, hairline, at least one touch target tall.
    func fieldStyle() -> some View {
        self
            .font(Theme.body)
            .padding(.horizontal, Theme.Space.l)
            .padding(.vertical, Theme.Space.m)
            .frame(minHeight: Theme.minTarget)
            .background(Theme.card, in: Theme.shape(Theme.smallCorner))
            .overlay(Theme.shape(Theme.smallCorner).strokeBorder(Theme.hairline, lineWidth: 1))
    }

    /// Pins a button to the bottom on the screen's background, fading content out above it.
    func bottomBar(@ViewBuilder _ content: () -> some View) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            content()
                .padding(.horizontal, Theme.padding)
                .padding(.top, Theme.Space.m)
                .padding(.bottom, Theme.Space.s)
                .background {
                    LinearGradient(
                        stops: [
                            .init(color: Theme.background.opacity(0), location: 0),
                            .init(color: Theme.background, location: 0.3),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }
        }
    }
}

/// A selectable chip label: dark fill when on, quiet fill when off. Used for day and feeling choices.
struct ChoiceChip: View {
    let title: String
    let selected: Bool

    var body: some View {
        Text(title)
            .font(Theme.body.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, Theme.Space.xs)
            .frame(maxWidth: .infinity, minHeight: Theme.minTarget)
            .foregroundStyle(selected ? Theme.background : Theme.text)
            .background(selected ? Theme.text : Theme.card, in: Theme.shape(Theme.smallCorner))
            .overlay(
                Theme.shape(Theme.smallCorner).strokeBorder(selected ? .clear : Theme.hairline, lineWidth: 1)
            )
            .contentShape(Theme.shape(Theme.smallCorner))
    }
}

/// Full-width primary button: dark on light, light on dark, so contrast holds in both modes.
struct BigButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(.title2, weight: .bold))
            .multilineTextAlignment(.center)
            .padding(.horizontal, Theme.padding)
            .padding(.vertical, Theme.Space.m)
            .frame(maxWidth: .infinity, minHeight: Theme.runControl)
            .foregroundStyle(Theme.onAccent)
            .background(Theme.accent, in: Theme.shape())
            .contentShape(Theme.shape())
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.35)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Full-width secondary button: outlined, for "Run anyway" and other quieter actions.
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(.title3, weight: .semibold))
            .multilineTextAlignment(.center)
            .padding(.horizontal, Theme.padding)
            .padding(.vertical, Theme.Space.m)
            .frame(maxWidth: .infinity, minHeight: Theme.minTarget + 8)
            .foregroundStyle(Theme.text)
            .background(Theme.card, in: Theme.shape())
            .overlay(Theme.shape().strokeBorder(Theme.text, lineWidth: 2))
            .contentShape(Theme.shape())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
