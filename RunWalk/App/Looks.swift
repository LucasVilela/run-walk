import SwiftUI

/// The app's visual designs. Each changes colours, type, corner shape and light/dark behaviour;
/// layout and behaviour stay the same. Run, walk and warm-up keep distinct colours in every look,
/// and the words are always shown too.
enum Look: String, CaseIterable, Identifiable, Sendable {
    case calm, futuristic, bold, optimized, sunrise

    var id: String { rawValue }

    var name: String {
        switch self {
        case .calm: "Calm"
        case .futuristic: "Futuristic"
        case .bold: "Bold"
        case .optimized: "Optimized"
        case .sunrise: "Sunrise"
        }
    }

    var blurb: String {
        switch self {
        case .calm: "Soft and friendly. The original."
        case .futuristic: "Neon on deep night, mono type."
        case .bold: "Black, volt and heavy condensed type."
        case .optimized: "Pure black for battery, maximum contrast."
        case .sunrise: "Warm pastels, rounded and gentle."
        }
    }

    var style: LookStyle {
        switch self {
        case .calm:
            LookStyle(
                run: 0xFF6B4A, walk: 0x2BB3A3, easy: 0x6B7A90,
                background: .init(light: 0xFAFAF7, dark: 0x111315),
                text: .init(light: 0x1A1C1E, dark: 0xF2F2F0),
                card: .init(light: 0xFFFFFF, dark: 0x1C1F22), onColor: 0x1A1C1E,
                corner: 20, smallCorner: 14, barCorner: 4, design: .default, countdownDesign: .rounded)
        case .futuristic:
            LookStyle(
                run: 0xFF2E88, walk: 0x00E5FF, easy: 0x7C83FF,
                background: .init(both: 0x05070D), text: .init(both: 0xE6F1FF), card: .init(both: 0x0D1422),
                onColor: 0x05070D, corner: 6, smallCorner: 4, barCorner: 1, design: .monospaced,
                countdownDesign: .monospaced, titleWeight: .medium, hairline: 0.18, forcedScheme: .dark,
                accent: 0x00E5FF)
        case .bold:
            LookStyle(
                run: 0xD4FF00, walk: 0x2F80ED, easy: 0x8A8A8E,
                background: .init(both: 0x000000), text: .init(both: 0xFFFFFF), card: .init(both: 0x151515),
                onColor: 0x000000, corner: 8, smallCorner: 6, barCorner: 2, design: .default,
                countdownDesign: .default, width: .condensed, titleWeight: .black, labelWeight: .black,
                hairline: 0.14, forcedScheme: .dark, accent: 0xD4FF00)
        case .optimized:
            LookStyle(
                run: 0xFFB000, walk: 0x4CD964, easy: 0xA0A0A0,
                background: .init(both: 0x000000), text: .init(both: 0xFFFFFF), card: .init(both: 0x111111),
                onColor: 0x000000, corner: 12, smallCorner: 10, barCorner: 2, design: .default,
                countdownDesign: .default, titleWeight: .bold, secondary: 0.85, hairline: 0.28,
                forcedScheme: .dark)
        case .sunrise:
            LookStyle(
                run: 0xFF7A59, walk: 0x6CC49B, easy: 0xB39CD0,
                background: .init(light: 0xFFF6EE, dark: 0x1E1714),
                text: .init(light: 0x2B1D16, dark: 0xFBEDE3),
                card: .init(light: 0xFFFFFF, dark: 0x2A201B), onColor: 0x2B1D16,
                corner: 26, smallCorner: 18, barCorner: 6, design: .rounded, countdownDesign: .rounded,
                titleWeight: .bold)
        }
    }
}

struct LookStyle: Sendable {
    struct Pair: Sendable {
        let light: UInt32
        let dark: UInt32
        init(light: UInt32, dark: UInt32) {
            self.light = light
            self.dark = dark
        }
        init(both: UInt32) { self.init(light: both, dark: both) }
    }

    var run: UInt32
    var walk: UInt32
    var easy: UInt32
    var background: Pair
    var text: Pair
    var card: Pair
    /// Text and icons placed on the run, walk and warm-up colours.
    var onColor: UInt32
    var corner: CGFloat
    var smallCorner: CGFloat
    var barCorner: CGFloat
    var design: Font.Design
    var countdownDesign: Font.Design
    var width: Font.Width = .standard
    var titleWeight: Font.Weight = .semibold
    var labelWeight: Font.Weight = .heavy
    /// Opacity of secondary text over the background.
    var secondary: Double = 0.7
    var hairline: Double = 0.08
    /// Dark-only looks force dark mode so system controls match.
    var forcedScheme: ColorScheme?
    /// Fill for primary buttons and the selected tab; nil uses the text colour.
    var accent: UInt32?
}
