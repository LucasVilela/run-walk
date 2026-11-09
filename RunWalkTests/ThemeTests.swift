import RunKit
import SwiftUI
import Testing
import UIKit

@testable import RunWalk

@MainActor
@Suite struct ThemeTests {
    @Test func segmentColorsMatchTokens() {
        #expect(Theme.color(for: .run) == Theme.run)
        #expect(Theme.color(for: .walk) == Theme.walk)
        #expect(Theme.color(for: .warmup) == Theme.easy)
        #expect(Theme.color(for: .cooldown) == Theme.easy)
    }

    @Test func backgroundFollowsLightAndDark() {
        let previous = Theme.look
        Theme.apply(.calm)
        defer { Theme.apply(previous) }
        let ui = UIColor(Theme.background)
        let light = ui.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let dark = ui.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        #expect(light == UIColor(hex: 0xFAFAF7))
        #expect(dark == UIColor(hex: 0x111315))
    }

    @Test func runControlsAreBigEnough() {
        #expect(Theme.minTarget >= 48)
        #expect(Theme.runControl >= 72)
    }
}

/// Every look keeps the app readable: text on backgrounds and cards, and words on the segment colours.
@MainActor
@Suite struct LookTests {
    static func luminance(_ hex: UInt32) -> Double {
        func channel(_ v: UInt32) -> Double {
            let c = Double(v) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(hex >> 16 & 0xFF) + 0.7152 * channel(hex >> 8 & 0xFF) + 0.0722
            * channel(hex & 0xFF)
    }

    static func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let (l1, l2) = (luminance(a), luminance(b))
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    @Test(arguments: Look.allCases)
    func textIsReadable(look: Look) {
        let s = look.style
        for (text, bg, card) in [
            (s.text.light, s.background.light, s.card.light), (s.text.dark, s.background.dark, s.card.dark),
        ] {
            #expect(Self.contrast(text, bg) >= 7, "\(look.name): text on background")
            #expect(Self.contrast(text, card) >= 7, "\(look.name): text on cards")
        }
    }

    @Test(arguments: Look.allCases)
    func wordsOnSegmentColoursAreReadable(look: Look) {
        let s = look.style
        // The RUN / WALK / WARM-UP pill is large bold text: WCAG large-text minimum is 3:1.
        for colour in [s.run, s.walk, s.easy] {
            #expect(Self.contrast(s.onColor, colour) >= 3, "\(look.name): \(String(colour, radix: 16))")
        }
        #expect(Set([s.run, s.walk, s.easy]).count == 3, "\(look.name): run, walk and warm-up differ")
        if let accent = s.accent {
            #expect(Self.contrast(s.onColor, accent) >= 4.5, "\(look.name): button text on accent")
        }
    }

    @Test func applyingALookSwitchesTokensAndPersists() {
        let previous = Theme.look
        defer { Theme.apply(previous) }
        Theme.apply(.futuristic)
        #expect(Theme.look == .futuristic)
        #expect(UserDefaults.standard.string(forKey: Theme.lookKey) == "futuristic")
        #expect(Theme.corner == 6)
        #expect(UIColor(Theme.run) == UIColor(hex: 0xFF2E88))
    }
}
