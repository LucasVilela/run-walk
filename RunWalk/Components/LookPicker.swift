import SwiftUI

/// A tile per look, each drawn in its own colours, type and corners. Tapping one switches the app.
struct LookPicker: View {
    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 150), spacing: Theme.Space.m)], spacing: Theme.Space.m
        ) {
            ForEach(Look.allCases) { look in
                Button {
                    Theme.apply(look)
                } label: {
                    LookTile(look: look, selected: look == Theme.look)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(look.name) look")
                .accessibilityHint(look.blurb)
                .accessibilityAddTraits(look == Theme.look ? .isSelected : [])
            }
        }
    }
}

private struct LookTile: View {
    let look: Look
    let selected: Bool

    var body: some View {
        let style = look.style
        let shape = RoundedRectangle(cornerRadius: style.smallCorner + 4, style: .continuous)
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            HStack {
                Text(look.name)
                    .font(
                        Font.system(.headline, design: style.design, weight: style.titleWeight).width(
                            style.width))
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color(hex: style.onColor), Color(hex: style.walk))
                }
            }
            HStack(spacing: 3) {
                ForEach(
                    Array(
                        [style.easy, style.run, style.walk, style.run, style.walk, style.easy].enumerated()),
                    id: \.offset
                ) {
                    RoundedRectangle(cornerRadius: style.barCorner, style: .continuous)
                        .fill(Color(hex: $0.element))
                }
            }
            .frame(height: 14)
            Text(look.blurb)
                .font(Font.system(.footnote, design: style.design).width(style.width))
                .opacity(style.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color(style.text))
        .padding(Theme.Space.m)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .background(Color(style.background), in: shape)
        .overlay(shape.strokeBorder(selected ? Theme.text : Theme.hairline, lineWidth: selected ? 3 : 1))
        .contentShape(shape)
    }
}
