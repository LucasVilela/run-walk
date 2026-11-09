import RunKit
import SwiftUI

/// Every badge: earned ones in colour, the rest quiet with a lock.
struct BadgesGrid: View {
    let earned: [Badge: Date]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text("Badges").font(Theme.heading)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 104), spacing: Theme.Space.m)], spacing: Theme.Space.m
            ) {
                ForEach(Badge.allCases) { badge in tile(badge) }
            }
        }
    }

    private func tile(_ badge: Badge) -> some View {
        let date = earned[badge]
        return VStack(spacing: Theme.Space.s) {
            Image(systemName: date == nil ? "lock.fill" : "medal.fill")
                .font(.title)
                .foregroundStyle(date == nil ? Theme.secondaryText : Theme.run)
            Text(badge.title)
                .font(Theme.small.weight(.semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Space.m)
        .frame(maxWidth: .infinity, minHeight: 104)
        .background(date == nil ? Theme.quietFill : Theme.card, in: Theme.shape(Theme.smallCorner))
        .overlay(Theme.shape(Theme.smallCorner).strokeBorder(Theme.hairline, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityValue(
            date.map { "earned \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "not yet")
    }
}
