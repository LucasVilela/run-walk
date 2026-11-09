import RunKit
import SwiftUI

/// The one coach suggestion on Today. Nothing changes until the user taps the accept button.
struct CoachCard: View {
    @Environment(AppModel.self) private var model
    let suggestion: Suggestion

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Label {
                Text(suggestion.title)
            } icon: {
                Image(systemName: icon).foregroundStyle(suggestion.rule == .pain ? Theme.run : Theme.walk)
            }
            .font(Theme.heading)
            Text(suggestion.body)
                .font(Theme.body)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Theme.Space.m) { buttons }
                VStack(spacing: Theme.Space.s) { buttons }
            }
        }
        .card()
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var buttons: some View {
        if let accept = suggestion.acceptLabel {
            Button(accept) { model.accept(suggestion) }
                .font(Theme.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: Theme.minTarget)
                .foregroundStyle(Theme.background)
                .background(Theme.text, in: Theme.shape(Theme.smallCorner))
        }
        Button(suggestion.dismissLabel) { model.dismiss(suggestion) }
            .font(Theme.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: Theme.minTarget)
            .background(Theme.quietFill, in: Theme.shape(Theme.smallCorner))
    }

    private var icon: String {
        switch suggestion.rule {
        case .pain: "heart.fill"
        case .gapRedo, .gapBack: "hand.wave.fill"
        case .hardRepeat: "arrow.counterclockwise"
        case .bigJump: "flag.fill"
        case .easyStreak: "star.fill"
        }
    }
}
