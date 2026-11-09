import RunKit
import SwiftUI
import UIKit

/// Design tokens. Use these, never raw colors or sizes, in views.
/// Every token follows the current `Look` (Settings → Look); the root view is rebuilt when it changes.
@MainActor
enum Theme {
    static let lookKey = "look"

    /// The current look, read once from user defaults and changed only through `apply`.
    private(set) static var look: Look =
        Look(rawValue: UserDefaults.standard.string(forKey: lookKey) ?? "") ?? .calm

    /// Switches the look. The root view watches the same defaults key and rebuilds.
    static func apply(_ newLook: Look) {
        look = newLook
        UserDefaults.standard.set(newLook.rawValue, forKey: lookKey)
    }

    private static var style: LookStyle { look.style }

    // MARK: Colors (light / dark)
    static var run: Color { Color(hex: style.run) }
    static var walk: Color { Color(hex: style.walk) }
    /// Warm-up and cool-down.
    static var easy: Color { Color(hex: style.easy) }
    static var background: Color { Color(style.background) }
    static var text: Color { Color(style.text) }
    static var secondaryText: Color { text.opacity(style.secondary) }
    static var card: Color { Color(style.card) }
    /// Hairline around cards and fields, so cards still read on the background.
    static var hairline: Color { text.opacity(style.hairline) }
    /// Quiet fill for unselected chips and the inactive parts of controls.
    static var quietFill: Color { text.opacity(0.06) }
    /// Text and icons placed on the run, walk or warm-up colour. Dark in every look: contrast holds.
    static var onColor: Color { Color(hex: style.onColor) }
    /// Primary buttons and the selected tab. Text-coloured unless the look has an accent.
    static var accent: Color { style.accent.map { Color(hex: $0) } ?? text }
    /// Text on `accent`.
    static var onAccent: Color { style.accent == nil ? background : onColor }

    static func color(for kind: SegmentKind) -> Color {
        switch kind {
        case .run: run
        case .walk: walk
        case .warmup, .cooldown: easy
        }
    }

    // MARK: Type (system font in the look's design, scales with Dynamic Type)
    /// Countdown digits. Views scale this with `@ScaledMetric(relativeTo: .largeTitle)`.
    static let countdownSize: CGFloat = 96

    static func font(_ textStyle: Font.TextStyle, weight: Font.Weight? = nil) -> Font {
        Font.system(textStyle, design: style.design, weight: weight).width(style.width)
    }

    static var title: Font { font(.title, weight: style.titleWeight) }  // 28 pt at default size
    static var body: Font { font(.body) }  // 17 pt
    static var small: Font { font(.subheadline) }  // 15 pt, the minimum
    /// Section labels inside a screen ("Pick 3 run days", "Splits").
    static var heading: Font { font(.body, weight: .semibold) }
    /// Screen titles drawn in content (onboarding steps, Today).
    static var screenTitle: Font { font(.largeTitle, weight: .bold) }
    /// The big segment word on the Run screen ("RUN", "WALK").
    static var segmentLabel: Font { font(.largeTitle, weight: style.labelWeight) }

    static func countdown(size: CGFloat) -> Font {
        Font.system(size: size, weight: .bold, design: style.countdownDesign).width(style.width)
    }

    // MARK: Touch targets
    static let minTarget: CGFloat = 48
    static let runControl: CGFloat = 72

    // MARK: Shape and spacing
    /// Cards, big buttons, maps and sheets.
    static var corner: CGFloat { style.corner }
    /// Chips and fields inside cards.
    static var smallCorner: CGFloat { style.smallCorner }
    /// Blocks in the segment bar and chart.
    static var barCorner: CGFloat { style.barCorner }
    static let padding: CGFloat = 20

    /// One spacing scale for every stack: 4, 8, 12, 16, 24, 32.
    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    static func shape(_ radius: CGFloat? = nil) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius ?? corner, style: .continuous)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }

    /// A color that follows light and dark mode.
    init(light: UInt32, dark: UInt32) {
        self.init(
            uiColor: UIColor { traits in
                UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
            })
    }

    init(_ pair: LookStyle.Pair) {
        self.init(light: pair.light, dark: pair.dark)
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
